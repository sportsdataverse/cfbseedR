#' Verify a Custom CFB Result Simulation Function
#'
#' @description
#' cfbseedR supports custom functions to compute results in season
#' simulations through the `compute_results` argument of
#' [cfb_simulations()]. This function verifies that a custom function
#' behaves as the simulator expects, mirroring nflseedR's
#' `simulations_verify_fct()`. It checks the output structure and whether
#' game results are changed as expected, and errors with a hint at the
#' first problem found.
#'
#' @param compute_results A function to compute results of games. Required
#'   arguments: `teams`, `games`, `week_num`. It must return
#'   `list(teams = teams, games = games)` without removing rows or columns
#'   from `games`, must fill `result` for exactly the games with
#'   `week == week_num & is.na(result)`, must not modify any other result,
#'   and must not produce ties (`result == 0`) outside the regular season.
#' @param ... Further arguments passed on to `compute_results`.
#' @param games A schedule where some results are missing. Defaults to the
#'   bundled toy season with all results from week 3 onwards blanked.
#' @param teams A teams table (`team`, `conference`, optionally `sim`).
#'   Defaults to the bundled toy teams.
#'
#' @return Returns `TRUE` invisibly if no problems are found.
#'
#' @examples
#' simulations_verify_fct(cfbseedR_compute_results)
#'
#' @seealso [cfb_simulations()], [cfbseedR_compute_results()]
#' @export
simulations_verify_fct <- function(compute_results, ..., games = NULL, teams = NULL) {
  if (!is.function(compute_results)) {
    cli::cli_abort("The {.arg compute_results} argument must be a function!")
  }
  fn_args <- names(formals(args(compute_results)))
  required_args <- c("teams", "games", "week_num")
  missing_args <- setdiff(required_args, fn_args)
  if (length(missing_args) > 0) {
    cli::cli_abort(
      "The function in argument {.arg compute_results} needs the following
       argument{?s}: {.arg {missing_args}}"
    )
  }

  if (is.null(games)) {
    games <- read.csv(system.file("extdata", "toy_games.csv", package = "cfbseedR"))
    games$result[games$week >= 3] <- NA
  }
  if (is.null(teams)) {
    teams <- read.csv(system.file("extdata", "toy_teams.csv", package = "cfbseedR"))
  }
  games <- standings_validate_games(games, allow_na_results = TRUE)
  teams <- tibble::as_tibble(teams)
  if (!"sim" %in% names(teams)) teams$sim <- games$sim[1]

  weeks_to_simulate <- sort(unique(games$week[is.na(games$result)]))
  problem <- function(...) {
    cli::cli_abort(c("x" = paste0(...)))
  }

  for (week_num in weeks_to_simulate) {
    old_games <- games
    out <- compute_results(teams = teams, games = games, week_num = week_num, ...)

    if (!is.list(out) || !all(c("teams", "games") %in% names(out))) {
      problem("{.arg compute_results} must return a list with the elements
              {.val teams} and {.val games}.")
    }
    new_games <- tibble::as_tibble(out$games)
    if (nrow(new_games) != nrow(old_games)) {
      problem("{.arg compute_results} changed the number of rows in games
              in week {week_num}.")
    }
    if (!all(names(old_games) %in% names(new_games))) {
      problem("{.arg compute_results} removed columns from games in week
              {week_num}.")
    }
    this_week <- new_games$week == week_num
    if (anyNA(new_games$result[this_week])) {
      problem("{.arg compute_results} did not compute all results of week
              {week_num}.")
    }
    if (!is.numeric(new_games$result)) {
      problem("{.arg compute_results} returned non-numeric results in week
              {week_num}.")
    }
    post_ties <- this_week & new_games$game_type != "REG" &
      !is.na(new_games$result) & new_games$result == 0
    if (any(post_ties)) {
      problem("{.arg compute_results} simulated a tie in a postseason game
              in week {week_num}. Postseason games must not end in a tie.")
    }
    # Results outside the current week must be untouched (incl. remaining NA)
    other <- which(new_games$week != week_num)
    new_r <- new_games$result[other]
    old_r <- old_games$result[other]
    changed <- xor(is.na(new_r), is.na(old_r)) |
      (!is.na(new_r) & !is.na(old_r) & new_r != old_r)
    if (any(changed)) {
      problem("{.arg compute_results} modified results outside of week
              {week_num}.")
    }
    # Pre-existing results of the current week must be untouched
    had_result <- this_week & !is.na(old_games$result)
    if (!all(new_games$result[had_result] == old_games$result[had_result])) {
      problem("{.arg compute_results} overwrote existing results in week
              {week_num}.")
    }

    teams <- out$teams
    games <- new_games
  }

  invisible(TRUE)
}
