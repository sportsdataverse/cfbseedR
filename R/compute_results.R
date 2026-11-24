#' Compute CFB Game Results in Season Simulations
#'
#' @description
#' The default `compute_results` function used by [cfb_simulations()]. It is
#' a faithful adaptation of nflseedR's `nflseedR_compute_results()` (a
#' variant of 538's ELO model, originally coded by Lee Sharpe and rewritten
#' by Sebastian Carl): a simple dynamic ELO carried through the `teams`
#' table, updated each week from (real or simulated) results. The home-field
#' bonus and the margin noise are fitted to FBS results (see `home_field` and
#' `margin_sd`); the rest of the ELO machinery keeps nflseedR's constants.
#'
#' @param teams A data frame of teams by simulation with at least the
#'   columns `sim` and `team`. May carry an `elo` column between weeks.
#' @param games A data frame of games with at least `sim`, `game_type`,
#'   `week`, `home_team`, `away_team`, `result`, and optionally `neutral`
#'   (0/1; the `home_field` ELO bonus applies when not neutral).
#' @param week_num The (numeric) week to simulate. Only games with
#'   `week == week_num & is.na(result)` receive a simulated result.
#' @param ... Optionally pass `elo`, a named vector of initial ELO ratings
#'   (names = team names). If absent, teams start at random ratings drawn
#'   from `rnorm(1500, 150)`.
#' @param home_field Home-field advantage in ELO points, added to the home
#'   team's rating difference for games that are not neutral. The default,
#'   59.4, is 2.38 points of margin (the generator divides ELO by 25), fitted
#'   on 8,551 FBS-vs-FBS games from 2014-2025 (2020 excluded). Before
#'   cfbseedR 0.3.0 this was nflseedR's NFL value, 20 (0.8 points).
#' @param margin_sd Standard deviation, in points, of a simulated margin
#'   around its ELO estimate. The default, 16.7, is the spread of real FBS
#'   margins around a pregame-ELO estimate over the same games. Before
#'   cfbseedR 0.3.0 this was nflseedR's NFL value, 13.
#'
#' @details
#' Mechanics: ELO difference is `home - away` plus `home_field` for true
#' home games, multiplied by 1.2 in the postseason (`game_type != "REG"`).
#' Win probability is `1 / (10^(-elo_diff / 400) + 1)`, the margin estimate
#' is `elo_diff / 25`, and simulated margins are drawn from
#' `rnorm(mean = estimate, sd = margin_sd)` and rounded away from zero.
#' The 400 logistic scale, the 25 ELO points per point of margin, the 1.2
#' postseason multiplier and the K = 20 update are nflseedR's; the data
#' support the 25 ELO-per-point scale for FBS (a free fit gives 23.6).
#' Pass `home_field` and `margin_sd` through [cfb_simulations()]'s `...` to
#' override them, e.g. `home_field = 20, margin_sd = 13` reproduces the
#' pre-0.3.0 (NFL) behaviour. Ties are possible in the regular season only;
#' a simulated postseason tie is re-decided by the win probability with a
#' 3-point margin. nflseedR's rest-day adjustment is dropped (no rest data
#' in the CFB schema).
#'
#' @return A list with two elements, as required by the `compute_results`
#'   contract (see [simulations_verify_fct()]):
#'
#' | Element | Type | Description |
#' |---|---|---|
#' | `teams` | data.frame | The input `teams` table with the `elo` column added/updated from this week's results. |
#' | `games` | data.frame | The input `games` table with `result` filled for this week's previously missing results (home margin, integer). |
#'
#' @examples
#' games <- read.csv(system.file("extdata", "toy_games.csv", package = "cfbseedR"))
#' teams <- read.csv(system.file("extdata", "toy_teams.csv", package = "cfbseedR"))
#' games$result[games$week >= 3] <- NA
#' teams$sim <- 1
#' games$sim <- 1
#' out <- cfbseedR_compute_results(teams, games, week_num = 3)
#' out$games[out$games$week == 3, ]
#'
#' @seealso [cfb_simulations()], [simulations_verify_fct()]
#' @export
cfbseedR_compute_results <- function(teams, games, week_num, ...,
                                     home_field = 59.4, margin_sd = 16.7) {
  # CFB defaults fitted by data-raw/cfb_elo_constants.R on completed
  # FBS-vs-FBS games 2014-2025 (2020 left out; 8,551 games), recorded in
  # data-raw/cfb_elo_constants.md:
  #   home_field = 25 * 2.376 pts (Massey within-season home edge, SE 0.168)
  #   margin_sd  = 16.724 pts (SD of margins around the pregame-ELO
  #                estimate this function computes, SE 0.128)
  # They replace nflseedR's NFL values (20 ELO = 0.8 pt, sd 13).
  # round away from zero (nflseedR round_out)
  round_out <- function(x) {
    as.integer(ifelse(x < 0, floor(x), ceiling(x)))
  }

  # Initialize ELO ratings if the teams table doesn't carry them yet
  if (!"elo" %in% names(teams)) {
    args <- list(...)
    if ("elo" %in% names(args)) {
      teams$elo <- unname(args$elo[teams$team])
    } else {
      team_names <- unique(teams$team)
      init <- setNames(rnorm(length(team_names), 1500, 150), team_names)
      teams$elo <- unname(init[teams$team])
    }
  }

  ratings <- setNames(teams$elo, paste(teams$sim, teams$team, sep = "-"))

  idx <- which(games$week == week_num)
  if (length(idx) == 0L) {
    return(list("teams" = teams, "games" = games))
  }

  home_elo <- ratings[paste(games$sim[idx], games$home_team[idx], sep = "-")]
  away_elo <- ratings[paste(games$sim[idx], games$away_team[idx], sep = "-")]
  neutral <- if ("neutral" %in% names(games)) {
    dplyr::coalesce(as.numeric(games$neutral[idx]), 0)
  } else {
    rep(0, length(idx))
  }
  postseason <- games$game_type[idx] != "REG"

  elo_diff <- home_elo - away_elo + ifelse(neutral == 1, 0, home_field)
  elo_diff <- ifelse(postseason, elo_diff * 1.2, elo_diff)
  wp <- 1 / (10^(-elo_diff / 400) + 1)
  estimate <- elo_diff / 25

  # Fill only missing results of the current week
  res <- games$result[idx]
  fill <- is.na(res)
  if (any(fill)) {
    res[fill] <- round_out(rnorm(sum(fill), estimate[fill], margin_sd))
    # No ties in the postseason: re-decide via win probability
    post_tie <- fill & postseason & res == 0
    if (any(post_tie)) {
      res[post_tie] <- ifelse(runif(sum(post_tie)) < wp[post_tie], 3L, -3L)
    }
    games$result[idx] <- res
  }

  # ELO shift from all of this week's results (nflseedR constants)
  outcome <- dplyr::case_when(
    is.na(res) ~ NA_real_, res > 0 ~ 1, res < 0 ~ 0, .default = 0.5
  )
  elo_input <- dplyr::case_when(
    is.na(res) ~ NA_real_,
    res > 0 ~ elo_diff * 0.001 + 2.2,
    res < 0 ~ -elo_diff * 0.001 + 2.2,
    .default = 1.0
  )
  elo_mult <- log(pmax(abs(res), 1) + 1.0) * 2.2 / elo_input
  elo_shift <- 20 * elo_mult * (outcome - wp)

  elo_change <- c(
    setNames(-elo_shift, paste(games$sim[idx], games$away_team[idx], sep = "-")),
    setNames(elo_shift, paste(games$sim[idx], games$home_team[idx], sep = "-"))
  )
  shift <- elo_change[paste(teams$sim, teams$team, sep = "-")]
  teams$elo <- teams$elo + dplyr::coalesce(unname(shift), 0)

  list("teams" = teams, "games" = games)
}
