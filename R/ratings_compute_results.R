#' Compute CFB Game Results from Fixed Team Ratings
#'
#' @description
#' An alternative `compute_results` function for [cfb_simulations()]: it
#' draws each unplayed game's margin from fixed team ratings instead of the
#' dynamic ELO of the default [cfbseedR_compute_results()]. Three kinds of
#' rating are supported, each with defaults fitted on FBS results:
#'
#' * `"points"`: a margin rating in points per game against an average team
#'   (for example a least-squares margin rating, SP+ or FPI).
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
#'   matching the team names in `games`), `rating` (numeric, no `NA`, on the
#'   scale of `rating_type`), and optionally `games` (non-negative number of
#'   games behind each rating; `NA` = unknown). Teams missing from `ratings`
#'   get a rating of 0 (league average).
#' @param rating_type One of `"points"` (default), `"adj_epa"` or
#'   `"raw_epa"`. Picks the default `scale`, `home_field` and `margin_sd`.
#' @param scale Points of margin per unit of rating difference. Either one
#'   number or a named vector keyed by games-played buckets written
#'   `"lo-hi"` (for example `c("0-3" = 32, "4-5" = 38, "6-7" = 45, "8-20" = 50)`).
#'   `NULL` uses the default for `rating_type`.
#' @param home_field Home-field advantage in points, added to the expected
#'   margin of games that are not neutral. `NULL` uses the default for
#'   `rating_type`.
#' @param margin_sd Standard deviation, in points, of a simulated margin
#'   around its expected value (at least 0): one number or a named bucket
#'   vector, as for `scale`. `NULL` uses the default for `rating_type`.
#'
#' @details
#' The expected home margin of a game is
#' `scale * (rating_home - rating_away) + home_field` (no `home_field` on a
#' neutral site). The simulated margin is a draw from
#' `rnorm(mean = expected, sd = margin_sd)` rounded away from zero: up to the
#' next whole number when positive, down when negative. A draw of exactly 0
#' in a postseason game (in practice only with `margin_sd = 0`) is re-decided
#' by the win probability `pnorm(expected / margin_sd)` with a 1-point margin.
#' Ratings stay fixed through the season, so `teams` is returned unchanged.
#'
#' Bucketed `scale` and `margin_sd` take the bucket of the less-observed
#' team of a game: the smaller `games` value of the two (a team missing from
#' `ratings`, or with `NA` games, does not count). A count takes the bucket
#' with the largest lower bound at or below it, so a count between buckets
#' takes the lower one, a count above every bucket the top one and a count
#' below every bucket the bottom one. When neither team has a count (no
#' `games` column, say) the game takes the top bucket, which treats the
#' ratings as full-season ratings; early in a season that overstates how
#' much the ratings are worth, so pass `games`.
#'
#' Defaults by `rating_type` (buckets 0-3 / 4-5 / 6-7 / 8-20 games):
#'
#' | `rating_type` | `scale` | `margin_sd` | `home_field` |
#' |---|---|---|---|
#' | `"points"` | 1.093 / 0.923 / 1.031 / 1.063 | 16.97 / 16.64 / 16.23 / 16.45 | 2.376 |
#' | `"adj_epa"` | 31.88 / 37.89 / 45.18 / 49.61 | 17.04 | 2.763 |
#' | `"raw_epa"` | 28.58 / 34.32 / 45.10 / 52.02 | 17.93 / 17.24 / 16.98 / 17.39 | 2.376 |
#'
#' The `"points"` and `"raw_epa"` values are a walk-forward fit on FBS-vs-FBS
#' games 2014-2025 (2020 excluded) of a current-season least-squares margin
#' rating and of net EPA per play, with `home_field` fixed at the ELO
#' generator's within-season estimate. The `"adj_epa"` values are
#' sportsdataverse-py's modern-era pregame-prediction constants, fitted to
#' that package's `adj_net` rating; a rating from another opponent adjustment
#' may need its own `scale` and `margin_sd`. Fit record:
#' <https://github.com/sportsdataverse/cfbseedR/blob/main/data-raw/cfb_generator_constants.md>.
#'
#' In a walk-forward test over the same seasons, scoring each week from
#' ratings built on earlier weeks, the ELO margin formula fed with
#' CollegeFootballData's pregame ELO (carried over between seasons) had the
#' smallest error overall: MAE 12.94 points, against 13.10 for the
#' least-squares points rating and 13.38 / 13.70 for the fitting script's
#' adjusted / raw EPA ratings. Its edge is early in the season, where the
#' current-season ratings have little to go on. From about six games on the
#' points rating is level with it (MAE 12.93 against 13.04 with 8 or more
#' games), so a points rating is a reasonable input for a late-season or
#' postseason simulation. To get ELO's early-season advantage from
#' [cfbseedR_compute_results()], pass carried-over starting ratings as `elo`;
#' without them every team starts from a random rating.
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
  post_tie <- (games$game_type[idx] != "REG" & res == 0L) %in% TRUE
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
# hfa_points) as refit in sportsdataverse-py #1300 (main bcce2e681ee); keep
# the two equal.
ratings_generator_defaults <- list(
  points = list(
    scale = c("0-3" = 1.0929, "4-5" = 0.9234, "6-7" = 1.0305, "8-20" = 1.0628),
    margin_sd = c("0-3" = 16.9680, "4-5" = 16.6383, "6-7" = 16.2311, "8-20" = 16.4509),
    home_field = 2.376
  ),
  adj_epa = list(
    scale = c("0-3" = 31.8829, "4-5" = 37.8903, "6-7" = 45.1766, "8-20" = 49.6115),
    margin_sd = 17.0386,
    home_field = 2.7625
  ),
  raw_epa = list(
    scale = c("0-3" = 28.5848, "4-5" = 34.3212, "6-7" = 45.0972, "8-20" = 52.0247),
    margin_sd = c("0-3" = 17.9308, "4-5" = 17.2400, "6-7" = 16.9808, "8-20" = 17.3931),
    home_field = 2.376
  )
)

# Pick a value per game from a scalar or a "lo-hi" bucket vector. `n_games`
# is the games behind the weaker rating of each game (NA = unknown, top
# bucket). A count takes the bucket with the largest lower bound at or below
# it (below every bucket: the bottom one).
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
  if (anyNA(lo) || anyNA(hi) || any(lengths(bounds) != 2L) || anyDuplicated(lo)) {
    cli::cli_abort("The names of {.arg {arg}} must be distinct games-played buckets written {.val lo-hi}, e.g. {.val 0-3}.")
  }
  ord <- order(lo)
  x <- unname(x)[ord]
  pick <- pmax(findInterval(n_games, lo[ord]), 1L)
  pick[is.na(n_games)] <- length(x)
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
  if (!is.numeric(ratings$rating) || anyNA(ratings$rating)) {
    cli::cli_abort("{.field rating} in {.arg ratings} must be numeric with no {.val NA}.")
  }
  if ("games" %in% names(ratings) &&
      (!is.numeric(ratings$games) || any(ratings$games < 0, na.rm = TRUE))) {
    cli::cli_abort("{.field games} in {.arg ratings} must be a non-negative number.")
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
    n_games <- pmin(g_home, g_away, na.rm = TRUE)
  }

  s <- ratings_bucket_value(scale, n_games, "scale")
  sd <- ratings_bucket_value(margin_sd, n_games, "margin_sd")
  if (any(sd < 0)) {
    cli::cli_abort("{.arg margin_sd} must be at least 0.")
  }
  expected <- s * (r_home - r_away) + ifelse(neutral == 1, 0, home_field)
  list(expected = expected, margin_sd = sd)
}
