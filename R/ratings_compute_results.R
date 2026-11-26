#' Compute CFB Game Results from Fixed Team Ratings
#'
#' @description
#' An alternative `compute_results` function for [cfb_simulations()]: it
#' draws each unplayed game's margin from fixed team ratings instead of the
#' dynamic ELO of the default [cfbseedR_compute_results()]. Three kinds of
#' rating are supported, each with defaults fitted on FBS results:
#'
#' * `"points"`: a margin rating in points per game (for example SP+, FPI or
#'   a least-squares margin rating).
#' * `"adj_epa"`: opponent-adjusted net EPA per play (offensive EPA/play
#'   minus defensive EPA/play allowed, adjusted for opponents).
#' * `"raw_epa"`: the same net EPA per play without opponent adjustment.
#'
#' Use it through `...` of [cfb_simulations()]:
#' `cfb_simulations(games, teams, compute_results = cfbseedR_ratings_compute_results, ratings = tbl, rating_type = "points")`.
#'
#' @inheritParams cfbseedR_compute_results
#' @param ... Ignored. Present so the function accepts the arguments
#'   [cfb_simulations()] passes to every `compute_results` function.
#' @param ratings A data frame with one row per team: `team` (character,
#'   matching the team names in `games`), `rating` (numeric, on the scale of
#'   `rating_type`), and optionally `games` (games played behind each
#'   rating). Teams missing from `ratings` get a rating of 0 (league average).
#' @param rating_type One of `"points"` (default), `"adj_epa"` or
#'   `"raw_epa"`. Picks the default `scale`, `home_field` and `margin_sd`.
#' @param scale Points of margin per unit of rating difference. Either one
#'   number or a named vector keyed by games-played buckets written
#'   `"lo-hi"` (for example `c("0-3" = 41, "4-5" = 49, "6-7" = 60, "8-20" = 66)`).
#'   `NULL` uses the default for `rating_type`.
#' @param home_field Home-field advantage in points, added to the expected
#'   margin of games that are not neutral. `NULL` uses the default for
#'   `rating_type`.
#' @param margin_sd Standard deviation, in points, of a simulated margin
#'   around its expected value: one number or a named bucket vector, as for
#'   `scale`. `NULL` uses the default for `rating_type`.
#'
#' @details
#' The expected home margin of a game is
#' `scale * (rating_home - rating_away) + home_field` (no `home_field` on a
#' neutral site), and the simulated margin is drawn from
#' `rnorm(mean = expected, sd = margin_sd)` and rounded away from zero. A
#' simulated postseason tie is re-decided by the win probability
#' `pnorm(expected / margin_sd)` with a 1-point margin. Ratings stay fixed
#' through the season, so `teams` is returned unchanged.
#'
#' Bucketed `scale` and `margin_sd` take the bucket of the less-observed
#' team of a game: the smaller `games` value of the two (a team missing from
#' `ratings` does not count). A count above every bucket takes the top one,
#' below every bucket the bottom one. Without a `games` column every game
#' takes the top bucket, which treats the ratings as full-season ratings.
#'
#' Defaults by `rating_type` (buckets 0-3 / 4-5 / 6-7 / 8-20 games):
#'
#' | `rating_type` | `scale` | `margin_sd` | `home_field` |
#' |---|---|---|---|
#' | `"points"` | 1.093 / 0.923 / 1.031 / 1.063 | 16.97 / 16.64 / 16.23 / 16.45 | 2.376 |
#' | `"adj_epa"` | 41.23 / 49.15 / 60.18 / 65.58 | 17.24 | 2.683 |
#' | `"raw_epa"` | 28.58 / 34.32 / 45.10 / 52.02 | 17.93 / 17.24 / 16.98 / 17.39 | 2.376 |
#'
#' The `"points"` and `"raw_epa"` values are a walk-forward fit on FBS-vs-FBS
#' games 2014-2025 (2020 excluded), with `home_field` fixed at the ELO
#' generator's within-season estimate. The `"adj_epa"` values are the
#' modern-era pregame-prediction constants of sportsdataverse-py, so a rating
#' on that package's adjusted-EPA scale (`adj_net`) gives the same expected
#' margins in both packages. Fit record: `data-raw/cfb_generator_constants.md`.
#'
#' In a walk-forward comparison over the same seasons the default ELO
#' generator predicted margins best overall (MAE 12.94 against 13.10 for
#' points, 13.38 for adjusted EPA and 13.70 for raw EPA), because these
#' ratings carry no preseason prior. Once both teams have about six games
#' the points rating ties or beats ELO, which makes it a good choice for a
#' late-season or postseason simulation from current ratings.
#'
#' @return A list with two elements, as required by the `compute_results`
#'   contract (see [simulations_verify_fct()]):
#'
#' | Element | Type | Description |
#' |---|---|---|
#' | `teams` | data.frame | The input `teams` table, unchanged. |
#' | `games` | data.frame | The input `games` table with `result` filled for this week's previously missing results (home margin, integer). |
#'
#' @examples
#' games <- cfb_games_example
#' teams <- cfb_teams_example
#' games$result[games$week >= 3] <- NA
#' teams$sim <- 1
#' games$sim <- 1
#' ratings <- data.frame(
#'   team = teams$team,
#'   rating = seq(10, -10, length.out = nrow(teams))
#' )
#' out <- cfbseedR_ratings_compute_results(
#'   teams, games, week_num = 3, ratings = ratings, rating_type = "points"
#' )
#' out$games[out$games$week == 3, ]
#'
#' @seealso [cfbseedR_compute_results()] (the default ELO generator),
#'   [cfb_simulations()], [simulations_verify_fct()]
#' @export
cfbseedR_ratings_compute_results <- function(teams, games, week_num, ...,
                                             ratings,
                                             rating_type = c("points", "adj_epa", "raw_epa"),
                                             scale = NULL, home_field = NULL,
                                             margin_sd = NULL) {
  rating_type <- rlang::arg_match(rating_type)
  idx <- which(games$week == week_num & is.na(games$result))
  if (length(idx) == 0L) {
    return(list("teams" = teams, "games" = games))
  }

  neutral <- if ("neutral" %in% names(games)) {
    dplyr::coalesce(as.numeric(games$neutral[idx]), 0)
  } else {
    rep(0, length(idx))
  }
  m <- ratings_expected_margin(
    games$home_team[idx], games$away_team[idx], neutral,
    ratings = ratings, rating_type = rating_type,
    scale = scale, home_field = home_field, margin_sd = margin_sd
  )

  round_out <- function(x) as.integer(ifelse(x < 0, floor(x), ceiling(x)))
  res <- round_out(rnorm(length(idx), m$expected, m$margin_sd))
  post_tie <- games$game_type[idx] != "REG" & res == 0L
  if (any(post_tie)) {
    wp <- stats::pnorm(m$expected[post_tie] / m$margin_sd[post_tie])
    wp[is.na(wp)] <- 0.5 # margin_sd = 0 with an expected margin of 0
    res[post_tie] <- ifelse(runif(sum(post_tie)) < wp, 1L, -1L)
  }
  games$result[idx] <- res

  list("teams" = teams, "games" = games)
}

# Defaults of cfbseedR_ratings_compute_results(), by rating_type. points and
# raw_epa: data-raw/cfb_generator_constants.R (fit on all pooled seasons,
# record in data-raw/cfb_generator_constants.md). adj_epa: sportsdataverse-py
# cfb_prediction_constants, modern era (slope_by_games, margin_sd,
# hfa_points); keep the two equal.
ratings_generator_defaults <- list(
  points = list(
    scale = c("0-3" = 1.0929, "4-5" = 0.9234, "6-7" = 1.0305, "8-20" = 1.0628),
    margin_sd = c("0-3" = 16.9680, "4-5" = 16.6383, "6-7" = 16.2311, "8-20" = 16.4509),
    home_field = 2.376
  ),
  adj_epa = list(
    scale = c("0-3" = 41.2286, "4-5" = 49.1525, "6-7" = 60.1753, "8-20" = 65.5762),
    margin_sd = 17.2358,
    home_field = 2.6828
  ),
  raw_epa = list(
    scale = c("0-3" = 28.5848, "4-5" = 34.3212, "6-7" = 45.0972, "8-20" = 52.0247),
    margin_sd = c("0-3" = 17.9308, "4-5" = 17.2400, "6-7" = 16.9808, "8-20" = 17.3931),
    home_field = 2.376
  )
)

# Pick a value per game from a scalar or a "lo-hi" bucket vector. `n_games`
# is the games behind the weaker rating of each game (NA = unknown, top
# bucket).
ratings_bucket_value <- function(x, n_games, arg) {
  if (!is.numeric(x) || length(x) < 1L || anyNA(x)) {
    cli::cli_abort("{.arg {arg}} must be a number or a named numeric vector of buckets.")
  }
  if (length(x) == 1L && is.null(names(x))) {
    return(rep(unname(x), length(n_games)))
  }
  bounds <- strsplit(names(x) %||% rep("", length(x)), "-", fixed = TRUE)
  lo <- suppressWarnings(as.numeric(vapply(bounds, `[`, "", 1L)))
  hi <- suppressWarnings(as.numeric(vapply(bounds, `[`, "", 2L)))
  if (anyNA(lo) || anyNA(hi) || any(lengths(bounds) != 2L)) {
    cli::cli_abort("The names of {.arg {arg}} must be games-played buckets written {.val lo-hi}, e.g. {.val 0-3}.")
  }
  ord <- order(lo)
  x <- unname(x)[ord]
  lo <- lo[ord]
  hi <- hi[ord]
  pick <- vapply(n_games, function(g) {
    if (is.na(g) || g > max(hi)) return(length(x))
    if (g < min(lo)) return(1L)
    hit <- which(lo <= g & g <= hi)
    if (length(hit) == 0L) length(x) else hit[1L]
  }, integer(1))
  x[pick]
}

# Expected home margin and margin SD of each game (vectorized). Shared by
# cfbseedR_ratings_compute_results() and the parity fixture
# (tests/testthat/fixtures/cfb_2025_ratings/capture.R).
ratings_expected_margin <- function(home_team, away_team, neutral, ratings,
                                    rating_type = "points", scale = NULL,
                                    home_field = NULL, margin_sd = NULL) {
  if (!is.data.frame(ratings) || !all(c("team", "rating") %in% names(ratings))) {
    cli::cli_abort("{.arg ratings} must be a data frame with columns {.field team} and {.field rating}.")
  }
  if (!is.numeric(ratings$rating)) {
    cli::cli_abort("{.field rating} in {.arg ratings} must be numeric.")
  }
  if (anyDuplicated(ratings$team)) {
    cli::cli_abort("{.arg ratings} has more than one row for a team.")
  }
  d <- ratings_generator_defaults[[rating_type]]
  scale <- scale %||% d$scale
  home_field <- home_field %||% d$home_field
  margin_sd <- margin_sd %||% d$margin_sd
  if (!is.numeric(home_field) || length(home_field) != 1L || is.na(home_field)) {
    cli::cli_abort("{.arg home_field} must be a single number.")
  }

  r <- stats::setNames(as.numeric(ratings$rating), as.character(ratings$team))
  r_home <- dplyr::coalesce(unname(r[as.character(home_team)]), 0)
  r_away <- dplyr::coalesce(unname(r[as.character(away_team)]), 0)

  n_games <- rep(NA_real_, length(home_team))
  if ("games" %in% names(ratings)) {
    g <- stats::setNames(as.numeric(ratings$games), as.character(ratings$team))
    g_home <- unname(g[as.character(home_team)])
    g_away <- unname(g[as.character(away_team)])
    n_games <- suppressWarnings(pmin(g_home, g_away, na.rm = TRUE))
  }

  s <- ratings_bucket_value(scale, n_games, "scale")
  sd <- ratings_bucket_value(margin_sd, n_games, "margin_sd")
  expected <- s * (r_home - r_away) + ifelse(neutral == 1, 0, home_field)
  list(expected = expected, margin_sd = sd)
}
