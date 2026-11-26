# Fit the defaults of cfbseedR_ratings_compute_results() and compare every
# results generator against the default ELO generator, walk-forward, on real
# FBS seasons.
#
# Run from the package root (needs network; cfbfastR >= 2.0):
#   Rscript data-raw/cfb_generator_constants.R
# Writes data-raw/cfb_generator_constants_by_season.csv,
# data-raw/cfb_generator_comparison.csv, the 2025 parity fixture under
# tests/testthat/fixtures/cfb_2025_ratings/ (ratings.csv, games.csv), and
# prints the record kept in data-raw/cfb_generator_constants.md.
#
# Data: cfbfastR::load_cfb_schedules() and cfbfastR::load_cfb_pbp()
# (cfbfastR-data release assets), completed FBS-vs-FBS games, regular season
# and postseason, 2014-2025. 2020 is left out of every fit and score, as in
# data-raw/cfb_elo_constants.R.
#
# Walk-forward ratings. For every week w of a season, three team ratings are
# built from the FBS-vs-FBS games played BEFORE week w only (postseason games
# all use the ratings through the end of the regular season):
#   points   least-squares margin rating: margin = hfa * home + r_home - r_away,
#            ridge penalty `lambda_pts` (in games) toward 0, centred.
#   raw_epa  offensive EPA/play minus defensive EPA/play allowed, pass and
#            rush plays, kneel-downs and garbage time dropped.
#   adj_epa  the same plays, opponent adjusted: per team-game EPA/play =
#            mu + hfa * home + off_team + def_opponent, weighted by plays,
#            ridge penalty `lambda_adj` (in plays) on the team terms;
#            rating = off - def.
# Garbage time is the score-margin rule by quarter (margin above 43, 37, 27,
# 21 in quarters 1-4; the quarter-4 value also covers overtime), the rule
# sportsdataverse-py's adjusted EPA uses.
#
# Scored games: week >= 4 and the postseason, both teams with >= 2 prior
# FBS-vs-FBS games, both with a CFBD pregame ELO.
#
# Generators compared, each giving a predicted home margin and a margin SD:
#   elo      cfbseedR_compute_results() as shipped: (elo_diff + 59.4 * home)
#            / 25, x1.2 outside the regular season, SD 16.7, on CFBD pregame
#            ELO (a dynamic ELO of the same family).
#   points / raw_epa / adj_epa
#            cfbseedR_ratings_compute_results(): margin = scale_b * diff +
#            home_field * home, with the scale and the SD fitted per
#            games-played bucket b of the less-observed team (0-3, 4-5, 6-7,
#            8+ games), and home_field shared across buckets.
# Each test season is scored with coefficients fitted on the other seasons
# (leave one season out), so no generator is scored in-sample. The ELO
# constants were fitted on all of these seasons, which favours ELO slightly.
# Metrics: MAE of the margin; Brier score of the home win, P = pnorm(pred /
# SD), the probability the simulator's normal draw implies. Intervals: paired
# differences against ELO, bootstrapped over (season, week) clusters, which
# keeps every game, and the games sharing a week, together.
#
# The shipped defaults are the fit on all pooled seasons.

seasons <- as.integer(strsplit(
  Sys.getenv("CFB_GEN_SEASONS", "2014:2025"), ":", fixed = TRUE
)[[1]])
seasons <- seq(seasons[1], seasons[length(seasons)])
pool_exclude <- 2020L
min_week <- 4L
min_games <- 2L
# ridge penalties: the middle value is used; the others are a sensitivity
lambda_pts_grid <- c(0.5, 2, 8)
lambda_adj_grid <- c(30, 100, 300)
lambda_pts <- lambda_pts_grid[2]
lambda_adj <- lambda_adj_grid[2]
# Home edge in points shared by every generator: the within-season estimate
# of data-raw/cfb_elo_constants.R (2.376, SE 0.168). A home term fitted on
# walk-forward ratings is larger because early-season ratings under-explain
# team strength and home teams are, on average, the stronger team; that
# would bias a simulation run on full-season ratings toward the home side.
hfa <- 2.376
garbage_margin <- c(43, 37, 27, 21)
bucket_names <- c("0-3", "4-5", "6-7", "8-20")
n_boot <- 2000L
set.seed(20261126)

bucket_of <- function(g) {
  as.character(cut(g, c(-Inf, 3, 5, 7, Inf), labels = bucket_names))
}

# ---- data ------------------------------------------------------------------

load_season <- function(s) {
  sch <- cfbfastR::load_cfb_schedules(s)
  sch <- as.data.frame(sch[
    sch$completed %in% TRUE &
      sch$home_division %in% "fbs" & sch$away_division %in% "fbs" &
      !is.na(sch$home_points) & !is.na(sch$away_points),
  ])
  sch$margin <- sch$home_points - sch$away_points
  sch$home <- as.numeric(!(sch$neutral_site %in% TRUE))
  sch$order <- ifelse(sch$season_type == "regular", sch$week, 100L)
  sch$post <- sch$season_type != "regular" |
    grepl("championship", sch$notes, ignore.case = TRUE)

  pbp <- as.data.frame(cfbfastR::load_cfb_pbp(s))
  pbp <- pbp[
    pbp$game_id %in% sch$game_id &
      (pbp$pass %in% 1 | pbp$rush %in% 1) & !is.na(pbp$EPA) &
      !grepl("kneel", pbp$play_text, ignore.case = TRUE),
    c("game_id", "pos_team", "def_pos_team", "period",
      "pos_score_diff_start", "EPA")
  ]
  thr <- garbage_margin[pmin(pmax(pbp$period, 1), 4)]
  pbp <- pbp[!(abs(pbp$pos_score_diff_start) > thr) %in% TRUE, ]
  pbp$one <- 1

  tg <- stats::aggregate(
    cbind(epa = EPA, plays = one) ~ game_id + pos_team + def_pos_team,
    data = pbp, FUN = sum
  )
  m <- match(tg$game_id, sch$game_id)
  tg$order <- sch$order[m]
  tg$off_home <- sch$home[m] *
    ifelse(tg$pos_team == sch$home_team[m], 1,
           ifelse(tg$pos_team == sch$away_team[m], -1, NA))
  matched <- mean(!is.na(tg$off_home))
  if (matched < 0.99) stop(sprintf("season %d: pbp/schedule team match %.3f", s, matched))
  tg <- tg[!is.na(tg$off_home), ]
  rm(pbp)
  invisible(gc())
  list(sch = sch, tg = tg)
}

# ---- walk-forward ratings ----------------------------------------------------

ridge <- function(x, y, w, penalty) {
  xw <- x * w
  drop(solve(crossprod(xw, x) + diag(penalty), crossprod(xw, y)))
}

rate_asof <- function(sch, tg, o) {
  gp <- sch[sch$order < o, ]
  tp <- tg[tg$order < o, ]
  teams <- sort(unique(c(gp$home_team, gp$away_team)))
  nt <- length(teams)
  games <- tabulate(match(c(gp$home_team, gp$away_team), teams), nt)

  # points: ridge least-squares margin rating
  x <- matrix(0, nrow(gp), nt + 1L)
  x[, 1] <- gp$home
  x[cbind(seq_len(nrow(gp)), 1L + match(gp$home_team, teams))] <- 1
  x[cbind(seq_len(nrow(gp)), 1L + match(gp$away_team, teams))] <- -1
  points <- sapply(lambda_pts_grid, function(l) {
    b <- ridge(x, gp$margin, rep(1, nrow(gp)), c(0, rep(l, nt)))
    b[-1] - mean(b[-1])
  })

  # raw EPA/play net
  off_epa <- tapply(tp$epa, factor(tp$pos_team, teams), sum)
  off_n <- tapply(tp$plays, factor(tp$pos_team, teams), sum)
  def_epa <- tapply(tp$epa, factor(tp$def_pos_team, teams), sum)
  def_n <- tapply(tp$plays, factor(tp$def_pos_team, teams), sum)
  raw <- as.numeric(off_epa / off_n - def_epa / def_n)

  # opponent-adjusted EPA/play net
  x <- matrix(0, nrow(tp), 2L * nt + 2L)
  x[, 1] <- 1
  x[, 2] <- tp$off_home
  x[cbind(seq_len(nrow(tp)), 2L + match(tp$pos_team, teams))] <- 1
  x[cbind(seq_len(nrow(tp)), 2L + nt + match(tp$def_pos_team, teams))] <- 1
  adj <- sapply(lambda_adj_grid, function(l) {
    b <- ridge(x, tp$epa / tp$plays, tp$plays, c(0, 0, rep(l, 2L * nt)))
    b[2L + seq_len(nt)] - b[2L + nt + seq_len(nt)]
  })

  out <- data.frame(team = teams, games = games,
                    points = points[, 2], raw_epa = raw, adj_epa = adj[, 2])
  out[paste0("points_l", lambda_pts_grid)] <- points
  out[paste0("adj_epa_l", lambda_adj_grid)] <- adj
  out
}

season_rows <- function(s) {
  cat("season", s, "\n")
  d <- load_season(s)
  sch <- d$sch
  targets <- sort(unique(sch$order[sch$order >= min_week]))
  out <- lapply(targets, function(o) {
    r <- rate_asof(sch, d$tg, o)
    g <- sch[sch$order == o, ]
    h <- match(g$home_team, r$team)
    a <- match(g$away_team, r$team)
    rc <- setdiff(names(r), c("team", "games"))
    cbind(
      data.frame(
        season = s, order = o, game_id = g$game_id,
        home_team = g$home_team, away_team = g$away_team,
        margin = g$margin, home = g$home, post = g$post,
        elo_diff = g$home_pregame_elo - g$away_pregame_elo,
        gmin = pmin(r$games[h], r$games[a])
      ),
      r[h, rc] - r[a, rc]
    )
  })
  # end-of-regular-season ratings (what a postseason simulation would use)
  list(rows = do.call(rbind, out), final = rate_asof(sch, d$tg, 100L),
       sch = sch)
}

per_season <- lapply(seasons, season_rows)
names(per_season) <- seasons
all_rows <- do.call(rbind, lapply(per_season, `[[`, "rows"))
scored <- all_rows[
  !is.na(all_rows$gmin) & all_rows$gmin >= min_games &
    !is.na(all_rows$elo_diff) & all_rows$margin != 0 &
    !(all_rows$season %in% pool_exclude),
]
scored$bucket <- factor(bucket_of(scored$gmin), bucket_names)
scored$win <- as.numeric(scored$margin > 0)
types <- c("points", "raw_epa", "adj_epa")

# ---- fit / predict -----------------------------------------------------------

fit_type <- function(d, type) {
  xb <- stats::model.matrix(~ 0 + bucket, d) * d[[type]]
  colnames(xb) <- bucket_names
  m <- stats::lm.fit(xb, d$margin - hfa * d$home)
  res <- m$residuals
  list(
    home_field = hfa,
    free_home_field = unname(stats::lm.fit(cbind(d$home, xb), d$margin)$coefficients[1]),
    scale = m$coefficients[bucket_names],
    margin_sd = vapply(bucket_names, function(b) {
      sqrt(mean(res[d$bucket == b]^2))
    }, numeric(1)),
    flat = unname(stats::lm.fit(cbind(d[[type]]), d$margin - hfa * d$home)$coefficients[1])
  )
}

predict_type <- function(d, f, type) {
  b <- as.character(d$bucket)
  list(mean = f$scale[b] * d[[type]] + f$home_field * d$home,
       sd = f$margin_sd[b])
}

elo_pred <- list(
  mean = ifelse(scored$post, 1.2, 1) * (scored$elo_diff + 59.4 * scored$home) / 25,
  sd = rep(16.7, nrow(scored))
)

pool <- setdiff(seasons, pool_exclude)
loso <- lapply(types, function(type) {
  mu <- sd <- numeric(nrow(scored))
  for (s in pool) {
    test <- scored$season == s
    f <- fit_type(scored[!test & scored$season %in% pool, ], type)
    p <- predict_type(scored[test, ], f, type)
    mu[test] <- p$mean
    sd[test] <- p$sd
  }
  list(mean = mu, sd = sd)
})
names(loso) <- types
preds <- c(list(elo = elo_pred), loso)

abs_err <- sapply(preds, function(p) abs(scored$margin - p$mean))
brier <- sapply(preds, function(p) (stats::pnorm(p$mean / p$sd) - scored$win)^2)

# ---- cluster bootstrap of paired differences vs ELO -------------------------

cluster <- factor(paste(scored$season, scored$order))
cl_n <- tabulate(cluster)
ae_cl <- rowsum(abs_err, cluster)
br_cl <- rowsum(brier, cluster)
nc <- nlevels(cluster)
boot_idx <- matrix(sample.int(nc, nc * n_boot, replace = TRUE), nc)
boot_delta <- function(cl) {
  vapply(seq_len(n_boot), function(i) {
    k <- boot_idx[, i]
    colSums(cl[k, , drop = FALSE]) / sum(cl_n[k])
  }, numeric(ncol(cl)))
}
ae_b <- boot_delta(ae_cl)
br_b <- boot_delta(br_cl)
ci <- function(b, j) {
  stats::quantile(b[j, ] - b["elo", ], c(0.025, 0.975), names = FALSE)
}

comparison <- do.call(rbind, lapply(names(preds), function(j) {
  data.frame(
    generator = j, games = nrow(scored),
    mae = mean(abs_err[, j]),
    mae_delta = mean(abs_err[, j]) - mean(abs_err[, "elo"]),
    mae_lo = ci(ae_b, j)[1], mae_hi = ci(ae_b, j)[2],
    brier = mean(brier[, j]),
    brier_delta = mean(brier[, j]) - mean(brier[, "elo"]),
    brier_lo = ci(br_b, j)[1], brier_hi = ci(br_b, j)[2]
  )
}))
by_bucket <- do.call(rbind, lapply(bucket_names, function(b) {
  k <- scored$bucket == b
  data.frame(bucket = b, games = sum(k),
             t(colMeans(abs_err[k, , drop = FALSE])),
             brier = t(colMeans(brier[k, , drop = FALSE])))
}))
by_season <- do.call(rbind, lapply(pool, function(s) {
  k <- scored$season == s
  data.frame(season = s, games = sum(k),
             t(colMeans(abs_err[k, , drop = FALSE])),
             brier = t(colMeans(brier[k, , drop = FALSE])))
}))

# ---- shipped defaults: fit on all pooled seasons ------------------------------

final_fit <- lapply(types, function(type) fit_type(scored, type))
names(final_fit) <- types

# What the games-played buckets buy: LOSO MAE with one flat scale instead.
loso_mae <- function(type, flat = FALSE) {
  mu <- numeric(nrow(scored))
  for (s in pool) {
    test <- scored$season == s
    f <- fit_type(scored[!test, ], type)
    if (flat) {
      mu[test] <- f$flat * scored[[type]][test] + hfa * scored$home[test]
    } else {
      mu[test] <- predict_type(scored[test, ], f, type)$mean
    }
  }
  mean(abs(scored$margin - mu))
}
flat_mae <- vapply(types, loso_mae, numeric(1), flat = TRUE)
lambda_cols <- c(paste0("points_l", lambda_pts_grid),
                 paste0("adj_epa_l", lambda_adj_grid))
lambda_mae <- vapply(lambda_cols, loso_mae, numeric(1))

utils::write.csv(by_season, "data-raw/cfb_generator_constants_by_season.csv",
                 row.names = FALSE)
utils::write.csv(comparison, "data-raw/cfb_generator_comparison.csv",
                 row.names = FALSE)

# ---- 2025 parity fixture: end-of-regular-season ratings + postseason games ---

if ("2025" %in% names(per_season)) {
  fx <- "tests/testthat/fixtures/cfb_2025_ratings"
  dir.create(fx, recursive = TRUE, showWarnings = FALSE)
  fr <- per_season[["2025"]]$final
  fr <- fr[order(fr$team), ]
  fmt <- function(x) sprintf("%.6f", x)
  utils::write.csv(
    data.frame(team = fr$team, games = fr$games, points = fmt(fr$points),
               raw_epa = fmt(fr$raw_epa), adj_epa = fmt(fr$adj_epa)),
    file.path(fx, "ratings.csv"), row.names = FALSE, quote = FALSE
  )
  sch <- per_season[["2025"]]$sch
  # the last regular-season week (conference championships) and the bowls/CFP
  pg <- sch[sch$order >= max(sch$order[sch$order < 100]), ]
  pg <- pg[order(pg$order, pg$home_team, pg$away_team), ]
  utils::write.csv(
    data.frame(sim = 1L, week = pg$order,
               game_type = ifelse(pg$season_type == "regular",
                                  ifelse(pg$post, "CONF_CHAMP", "REG"), "POST"),
               home_team = pg$home_team, away_team = pg$away_team,
               result = NA, neutral = 1L - pg$home),
    file.path(fx, "games.csv"), row.names = FALSE, quote = FALSE, na = ""
  )
}

# ---- report --------------------------------------------------------------------

cat(sprintf("seasons %d-%d, %d excluded; scored games %d in %d (season, week) clusters\n",
            min(seasons), max(seasons), pool_exclude, nrow(scored), nc))
cat(sprintf("lambda_pts %g games, lambda_adj %g plays, min_week %d, min_games %d\n",
            lambda_pts, lambda_adj, min_week, min_games))
cat("\nComparison vs elo (leave-one-season-out; 95% CI over (season, week) clusters)\n")
print(comparison, digits = 4, row.names = FALSE)
cat("\nMAE / Brier by games-played bucket of the less-observed team\n")
print(by_bucket, digits = 4, row.names = FALSE)
cat("\nMAE / Brier by season\n")
print(by_season, digits = 4, row.names = FALSE)
cat("\nFlat-scale LOSO MAE (no games-played buckets)\n")
print(round(flat_mae, 4))
cat("\nRidge-penalty sensitivity (LOSO MAE, bucketed)\n")
print(round(lambda_mae, 4))
cat("\nShipped defaults (fit on all pooled seasons)\n")
for (type in types) {
  f <- final_fit[[type]]
  cat(sprintf("%-8s home_field %.3f (free fit %.3f) | flat scale %.4f\n",
              type, f$home_field, f$free_home_field, f$flat))
  print(rbind(scale = round(f$scale, 4), margin_sd = round(f$margin_sd, 4)))
}
