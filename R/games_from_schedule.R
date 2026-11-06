#' Build an Engine Games Table from a cfbfastR Schedule
#'
#' @description
#' Maps the schedule shape returned by `cfbfastR::load_cfb_schedules()` to
#' the games schema used by [cfb_standings()] and [cfb_simulations()].
#' cfbfastR is not required - any data frame with the expected columns works.
#'
#' @param schedule A data frame with at least `season`, `week`,
#'   `season_type`, `home_team`, `away_team`. Optional columns used when
#'   present: `home_points`/`away_points` (to compute `result`),
#'   `neutral_site`, and `notes` (games whose notes mention "championship"
#'   are classified as `"CONF_CHAMP"`).
#'
#' @details
#' Game type mapping: `season_type == "postseason"` becomes `"POST"`, games
#' whose `notes` contain "championship" (case-insensitive) become
#' `"CONF_CHAMP"`, everything else `"REG"`. This is a documented heuristic -
#' CFBD marks conference championship games as regular-season games with a
#' championship note.
#'
#' @return A tibble in the engine games schema, ready for
#'   [cfb_standings()] / [cfb_simulations()]:
#'
#' | Column | Type | Description |
#' |---|---|---|
#' | `season` | integer | Season taken from the schedule. |
#' | `week` | integer | Week number of the game. |
#' | `game_type` | character | `"REG"`, `"CONF_CHAMP"` (notes mention "championship"), or `"POST"` (`season_type == "postseason"`). |
#' | `home_team` | character | Home team name. |
#' | `away_team` | character | Away team name. |
#' | `result` | numeric | Home margin (home minus away points); `NA` for unplayed games. |
#' | `neutral` | integer | Neutral-site flag (0/1). |
#'
#' @examples
#' schedule <- data.frame(
#'   season = 2024, week = c(1, 1, 15, 16),
#'   season_type = c("regular", "regular", "regular", "postseason"),
#'   home_team = c("A1", "B1", "A1", "A1"),
#'   away_team = c("A2", "B2", "A2", "B1"),
#'   home_points = c(21, 24, 17, NA), away_points = c(14, 20, 14, NA),
#'   neutral_site = c(FALSE, FALSE, TRUE, TRUE),
#'   notes = c(NA, NA, "Alpha Championship Game", NA)
#' )
#' cfb_games_from_schedule(schedule)
#'
#' @seealso [cfb_standings()], [cfb_simulations()],
#'   `cfbfastR::load_cfb_schedules()` from
#'   [cfbfastR](https://cfbfastR.sportsdataverse.org),
#'   the nflseedR original: <https://nflseedr.com>
#' @export
cfb_games_from_schedule <- function(schedule) {
  schedule <- tibble::as_tibble(schedule)
  required <- c("season", "week", "season_type", "home_team", "away_team")
  missing <- setdiff(required, names(schedule))
  if (length(missing) > 0) {
    cli::cli_abort("{.arg schedule} is missing the column{?s} {.val {missing}}.")
  }
  n <- nrow(schedule)
  home_points <- schedule[["home_points"]] %||% rep(NA_real_, n)
  away_points <- schedule[["away_points"]] %||% rep(NA_real_, n)
  neutral_site <- schedule[["neutral_site"]] %||% rep(FALSE, n)
  notes <- as.character(schedule[["notes"]] %||% rep(NA_character_, n))

  tibble::tibble(
    season = schedule$season,
    week = schedule$week,
    game_type = dplyr::case_when(
      schedule$season_type == "postseason" ~ "POST",
      !is.na(notes) & grepl("championship", notes, ignore.case = TRUE) ~ "CONF_CHAMP",
      .default = "REG"
    ),
    home_team = schedule$home_team,
    away_team = schedule$away_team,
    result = home_points - away_points,
    neutral = as.integer(dplyr::coalesce(as.logical(neutral_site), FALSE))
  )
}
