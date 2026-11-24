# Fit the CFB home-field advantage and margin noise used as the defaults of
# cfbseedR_compute_results() (`home_field`, `margin_sd`).
#
# Run from the package root (needs network; cfbfastR >= 2.0):
#   Rscript data-raw/cfb_elo_constants.R
# Writes data-raw/cfb_elo_constants_by_season.csv and prints the pooled fit,
# recorded in data-raw/cfb_elo_constants.md.
#
# Data: cfbfastR::load_cfb_schedules() (cfbfastR-data release assets),
# completed FBS-vs-FBS games, regular season and postseason, 2014-2025
# (the CFP era). 2020 is fitted and reported but left out of the pooled
# defaults: most of its games had no crowd or a capped one.
#
# The generator's model of a game is
#   margin = (elo_home - elo_away + home_field * home) / 25 + N(0, margin_sd)
# (home = 0 at a neutral site; 25 ELO points per point of margin, the
# nflseedR scale). Two quantities are fitted:
#
# 1. home_field. Per season, a Massey-style least-squares fit
#      margin_g = hfa_s * home_g + r_{s,home} - r_{s,away} + e_g
#    with one rating per team-season, so team strength (and who gets to
#    schedule home games) is absorbed by the ratings. The per-season hfa_s
#    are pooled by inverse-variance weighting; SE from the weighting, and the
#    between-season SD shows the year-to-year spread. home_field (ELO) =
#    25 * hfa, because the generator turns ELO into points by dividing by 25.
#
# 2. margin_sd. The spread of real margins around exactly the estimate the
#    generator computes, using CFBD's pregame ELO (a 538-style dynamic ELO,
#    the same family as cfbseedR's) as the rating:
#      resid_g = margin_g - (elo_diff_g + 25 * hfa * home_g) / 25
#    with the generator's x1.2 on the whole ELO difference for non-REG games
#    (postseason, and conference championship games - picked out as
#    cfb_games_from_schedule() does, by "championship" in the notes).
#    margin_sd = sqrt(mean(resid^2)), SE ~ margin_sd / sqrt(2 n). This is
#    the predictive noise a simulator needs: it includes the error of a
#    pregame rating, not just game-to-game noise around a season-long
#    rating. The in-sample Massey residual SD (the pure game-noise floor)
#    is printed for reference, and so is a free regression of margin on
#    home + elo_diff, whose slope checks the 25 ELO-per-point scale.

seasons <- 2014:2025
pool_exclude <- 2020L

sched <- cfbfastR::load_cfb_schedules(seasons)
g <- sched[
  sched$completed %in% TRUE &
    sched$home_division %in% "fbs" & sched$away_division %in% "fbs" &
    !is.na(sched$home_points) & !is.na(sched$away_points),
]
g$margin <- g$home_points - g$away_points
g$home <- as.numeric(!(g$neutral_site %in% TRUE))
# The generator's postseason multiplier applies to every non-REG game.
g$post_mult <- ifelse(
  g$season_type != "regular" | grepl("championship", g$notes, ignore.case = TRUE),
  1.2, 1
)

fit_season <- function(d) {
  teams <- sort(unique(c(d$home_team, d$away_team)))
  x <- matrix(0, nrow(d), length(teams), dimnames = list(NULL, teams))
  x[cbind(seq_len(nrow(d)), match(d$home_team, teams))] <- 1
  x[cbind(seq_len(nrow(d)), match(d$away_team, teams))] <- -1
  m <- stats::lm(d$margin ~ 0 + d$home + x)
  s <- summary(m)
  data.frame(
    season = d$season[1],
    games = nrow(d),
    home_games = sum(d$home),
    teams = length(teams),
    hfa = unname(stats::coef(m)[1]),
    hfa_se = s$coefficients[1, "Std. Error"],
    massey_sigma = s$sigma,
    df = m$df.residual,
    rss = sum(stats::residuals(m)^2)
  )
}

by_season <- do.call(rbind, lapply(split(g, g$season), fit_season))
rownames(by_season) <- NULL

pool <- by_season[by_season$season != pool_exclude, ]
w <- 1 / pool$hfa_se^2
hfa <- sum(w * pool$hfa) / sum(w)
hfa_se <- sqrt(1 / sum(w))
hfa_between_sd <- stats::sd(pool$hfa)
massey_sigma <- sqrt(sum(pool$rss) / sum(pool$df))

# margin_sd around the generator's own estimate on CFBD pregame ELO.
ge <- g[!(g$season %in% pool_exclude) &
  !is.na(g$home_pregame_elo) & !is.na(g$away_pregame_elo), ]
ge$elo_diff <- ge$home_pregame_elo - ge$away_pregame_elo
resid <- ge$margin - ge$post_mult * (ge$elo_diff + 25 * hfa * ge$home) / 25
margin_sd <- sqrt(mean(resid^2))
margin_sd_se <- margin_sd / sqrt(2 * length(resid))
conf <- ge$conference_game %in% TRUE
margin_sd_conf <- sqrt(mean(resid[conf]^2))
free <- summary(stats::lm(margin ~ 0 + home + elo_diff, data = ge))

by_season$pregame_elo_sd <- vapply(by_season$season, function(s) {
  d <- g[g$season == s & !is.na(g$home_pregame_elo) & !is.na(g$away_pregame_elo), ]
  r <- d$margin -
    d$post_mult * (d$home_pregame_elo - d$away_pregame_elo + 25 * hfa * d$home) / 25
  sqrt(mean(r^2))
}, numeric(1))

utils::write.csv(
  by_season[, c("season", "games", "home_games", "teams", "hfa", "hfa_se",
                "massey_sigma", "df", "pregame_elo_sd")],
  "data-raw/cfb_elo_constants_by_season.csv", row.names = FALSE
)

cat(sprintf("seasons %d-%d, pooled excludes %d\n",
            min(seasons), max(seasons), pool_exclude))
cat(sprintf("FBS-vs-FBS games: %d fitted, %d pooled (%d true-home)\n",
            nrow(g), sum(pool$games), sum(pool$home_games)))
cat(sprintf("hfa        = %.3f pts (SE %.3f; between-season SD %.3f)\n",
            hfa, hfa_se, hfa_between_sd))
cat(sprintf("home_field = 25 * hfa = %.1f ELO\n", 25 * hfa))
cat(sprintf("margin_sd  = %.3f pts (SE %.3f; n %d games with pregame ELO)\n",
            margin_sd, margin_sd_se, length(resid)))
cat(sprintf("  conference games only: %.3f (n %d)\n",
            margin_sd_conf, sum(conf)))
cat(sprintf("  in-sample Massey residual SD (game-noise floor): %.3f (df %d)\n",
            massey_sigma, sum(pool$df)))
cat(sprintf(
  "  free fit margin ~ home + elo_diff: home %.3f (SE %.3f), pts per ELO %.4f (SE %.4f; 1/25 = 0.0400)\n",
  free$coefficients["home", 1], free$coefficients["home", 2],
  free$coefficients["elo_diff", 1], free$coefficients["elo_diff", 2]
))
print(by_season[, c("season", "games", "home_games", "hfa", "hfa_se",
                    "massey_sigma", "pregame_elo_sd")],
      digits = 3, row.names = FALSE)
