#' Example Games of a Toy College Football Season
#'
#' @description A nine-team, two-conference toy season (plus one independent)
#'   used throughout the examples, the vignettes, and as the default input of
#'   [simulations_verify_fct()]. It is the same data shipped in
#'   `inst/extdata/toy_games.csv`, so it needs no network access.
#'
#' @format A data frame with the columns [cfb_standings()] requires:
#'
#' | Column | Type | Description |
#' |---|---|---|
#' | `season` | integer | Season identifier. |
#' | `game_type` | character | `"REG"` or `"CONF_CHAMP"`. |
#' | `week` | integer | Week number of the game. |
#' | `home_team`, `away_team` | character | Team names matching `cfb_teams_example$team`. |
#' | `home_points`, `away_points` | integer | Final scores (feed the SEC capped-margin rung). |
#' | `result` | integer | Home margin, i.e. home score minus away score. |
#'
#' @seealso [cfb_teams_example], [cfb_standings()], [cfb_simulations()]
#' @examples
#' \donttest{
#' head(cfb_games_example)
#' }
"cfb_games_example"

#' Example Teams of a Toy College Football Season
#'
#' @description The team table that pairs with [cfb_games_example]: nine teams
#'   across two conferences plus one independent. Same data as
#'   `inst/extdata/toy_teams.csv`.
#'
#' @format A data frame with the columns [cfb_standings()] requires:
#'
#' | Column | Type | Description |
#' |---|---|---|
#' | `team` | character | Team name, matching the game table. |
#' | `conference` | character | Conference name; `"FBS Independents"` marks an independent. |
#'
#' @seealso [cfb_games_example], [cfb_standings()]
#' @examples
#' \donttest{
#' cfb_teams_example
#' }
"cfb_teams_example"
