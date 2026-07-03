#' Compute College Football Standings
#'
#' @description
#' Computes overall and conference standings from a table of game results,
#' including conference ranks (via a documented tiebreaker cascade),
#' conference champions, and - optionally - College Football Playoff seeds.
#'
#' Adapted from [nflseedR](https://nflseedr.com)'s `nfl_standings()` with
#' college football semantics: conferences instead of divisions, independents
#' excluded from conference ranks, and conference championship games counting
#' toward the overall record (and deciding the champion) but not the
#' conference record.
#'
#' @param games A data frame of games. Required columns:
#' \describe{
#'  \item{sim or season}{A season or simulation ID.}
#'  \item{game_type}{One of `"REG"`, `"CONF_CHAMP"`, `"POST"`.}
#'  \item{week}{Week number of the game.}
#'  \item{home_team, away_team}{Team names matching `teams$team`.}
#'  \item{result}{Home margin, i.e. home score minus away score. Must not
#'    be `NA` (play or simulate the games first).}
#' }
#' @param teams A data frame with columns `team` and `conference`. Teams with
#'   conference `"FBS Independents"` or `NA` are treated as independents:
#'   they appear in overall standings but receive no conference rank.
#' @param ... Currently unused.
#' @param tiebreaker_depth One of `"SOS"` (default), `"PRE-SOV"`, `"POINTS"`,
#'   or `"RANDOM"`. Controls how deep the tiebreaker cascade goes before
#'   falling back to a coin flip:
#'   - `"RANDOM"`: coin flip immediately.
#'   - `"PRE-SOV"`: head-to-head and common opponents only.
#'   - `"SOS"`: adds strength of victory, then strength of schedule.
#'   - `"POINTS"`: adds conference point differential.
#' @param playoff_seeds If not `NULL`, a `seed` column is added via
#'   [cfb_playoff_seeds()] with this number of playoff spots.
#' @param rankings Optional committee-style rankings data frame with columns
#'   `team` and `rank`, passed to [cfb_playoff_seeds()]. Ignored when
#'   `playoff_seeds` is `NULL`.
#' @param verbosity One of `"MIN"` (default), `"MAX"`, or `"NONE"`.
#'   `"MAX"` logs every tiebreaker step.
#'
#' @details
#' The tiebreaker cascade is a documented simplification - real CFB
#' tiebreakers are conference-specific. Conference ranks are seeded by
#' conference win percentage; ties are broken by head-to-head record among
#' the tied teams, record vs. common conference opponents (minimum one),
#' conference-scoped strength of victory, conference-scoped strength of
#' schedule, conference point differential, and finally a coin flip. All
#' cascade quantities are computed over regular-season conference games so
#' conference ranks depend only on conference play.
#'
#' @return A tibble of standings, one row per (`sim`, `team`) (the id column
#'   is named `season` if the input used `season`), sorted by sim,
#'   conference, conference rank, and team. Columns: `sim`/`season`, `team`,
#'   `conference`, `games`, `wins`, `losses`, `ties`, `win_pct`, `pd`,
#'   `conf_games`, `conf_wins`, `conf_losses`, `conf_ties`, `conf_pct`,
#'   `conf_pd`, `sov`, `sos`, `conf_rank`, `conf_champ` (+ `seed` if
#'   `playoff_seeds` was supplied). `wins`/`losses` are true win/loss counts;
#'   `win_pct` counts ties as half a win. `sov`/`sos` are conference-scoped.
#'
#' @examples
#' games <- read.csv(system.file("extdata", "toy_games.csv", package = "cfbseedR"))
#' teams <- read.csv(system.file("extdata", "toy_teams.csv", package = "cfbseedR"))
#' standings <- cfb_standings(games, teams, tiebreaker_depth = "POINTS",
#'                            verbosity = "NONE")
#' standings[, c("team", "conference", "conf_rank", "conf_champ")]
#'
#' @seealso [cfb_playoff_seeds()], [cfb_simulations()],
#'   the nflseedR original: <https://nflseedr.com>
#' @export
cfb_standings <- function(games,
                          teams,
                          ...,
                          tiebreaker_depth = c("SOS", "PRE-SOV", "POINTS", "RANDOM"),
                          playoff_seeds = NULL,
                          rankings = NULL,
                          verbosity = c("MIN", "MAX", "NONE")) {
  tiebreaker_depth <- rlang::arg_match(tiebreaker_depth)
  depth <- switch(tiebreaker_depth,
    "RANDOM" = 0L, "PRE-SOV" = 1L, "SOS" = 2L, "POINTS" = 3L
  )
  verbosity <- rlang::arg_match(verbosity)
  verbosity <- switch(verbosity, "NONE" = 0L, "MIN" = 1L, "MAX" = 2L)

  games <- standings_validate_games(games)
  uses_season <- isTRUE(attr(games, "uses_season"))
  teams <- standings_validate_teams(teams, games)

  if (verbosity > 0L) cli::cli_inform("Initiate standings & tiebreaking data")
  dg <- standings_double_games(games, teams)
  standings <- standings_init(dg)

  if (verbosity > 0L) cli::cli_inform("Compute conference ranks")
  standings <- standings_add_conf_ranks(standings, dg, depth, verbosity)
  standings <- standings_add_conf_champ(standings, dg)

  if (!is.null(playoff_seeds)) {
    if (verbosity > 0L) cli::cli_inform("Compute playoff seeds")
    standings <- cfb_playoff_seeds(
      standings, rankings = rankings, playoff_seeds = playoff_seeds
    )
  }

  standings <- standings |>
    dplyr::arrange(.data$sim, .data$conference, .data$conf_rank, .data$team)
  if (uses_season) standings <- dplyr::rename(standings, season = "sim")
  standings
}

#' Compute College Football Playoff Seeds
#'
#' @description
#' Implements 12-team CFP **straight seeding** (2025 rule): the field is the
#' `playoff_seeds` best-ranked teams with the 5 highest-ranked conference
#' champions guaranteed inclusion, and seeds are assigned strictly in ranking
#' order (champions are not bumped up).
#'
#' @param standings A standings table as returned by [cfb_standings()]
#'   (requires at least `team`, `conference`, `conf_champ`, `win_pct`,
#'   `sov`, `sos`, `pd`, and a `sim` or `season` id column).
#' @param rankings Optional data frame with columns `team` and `rank`
#'   (1 = best), e.g. the CFP committee rankings. Teams missing from
#'   `rankings` are treated as unranked and ordered behind all ranked teams.
#'   When `NULL`, a documented fallback ordering is used instead: teams are
#'   ordered by win percentage, then strength of victory, strength of
#'   schedule, point differential, and team name.
#' @param playoff_seeds Number of playoff spots (default 12).
#'
#' @details
#' If there are fewer than 5 conference champions, all champions are
#' guaranteed (capped at `playoff_seeds`). A guaranteed champion ranked
#' outside the top `playoff_seeds` displaces the lowest-ranked at-large team
#' and is seeded by its rank order within the field (i.e. it takes the last
#' seed).
#'
#' @return The `standings` input with a `seed` column added (`NA` for teams
#'   outside the playoff field).
#'
#' @examples
#' games <- read.csv(system.file("extdata", "toy_games.csv", package = "cfbseedR"))
#' teams <- read.csv(system.file("extdata", "toy_teams.csv", package = "cfbseedR"))
#' standings <- cfb_standings(games, teams, tiebreaker_depth = "POINTS",
#'                            verbosity = "NONE")
#' rankings <- data.frame(team = c("B1", "I1", "A1", "A3"), rank = 1:4)
#' seeded <- cfb_playoff_seeds(standings, rankings = rankings, playoff_seeds = 4)
#' seeded[!is.na(seeded$seed), c("team", "seed")]
#'
#' @seealso [cfb_standings()]
#' @export
cfb_playoff_seeds <- function(standings, rankings = NULL, playoff_seeds = 12L) {
  standings <- tibble::as_tibble(standings)
  id_col <- if ("sim" %in% names(standings)) "sim" else "season"
  if (!id_col %in% names(standings)) {
    cli::cli_abort("{.arg standings} must include a {.val sim} or {.val season} column.")
  }
  required <- c("team", "conference", "conf_champ", "win_pct", "sov", "sos", "pd")
  missing <- setdiff(required, names(standings))
  if (length(missing) > 0) {
    cli::cli_abort("{.arg standings} is missing the column{?s} {.val {missing}}.")
  }
  if (!is.null(rankings) && !all(c("team", "rank") %in% names(rankings))) {
    cli::cli_abort("{.arg rankings} must include the columns {.val team} and {.val rank}.")
  }
  playoff_seeds <- as.integer(playoff_seeds)

  seed_one_sim <- function(st) {
    if (playoff_seeds > nrow(st)) {
      cli::cli_abort(
        "{.arg playoff_seeds} ({playoff_seeds}) exceeds the number of teams ({nrow(st)})."
      )
    }
    rank_vec <- if (is.null(rankings)) {
      rep(NA_real_, nrow(st))
    } else {
      rankings$rank[match(st$team, rankings$team)]
    }
    # Order key: committee rank first (unranked last), then the fallback
    # cascade (win pct, sov, sos, pd, team name)
    ord <- order(
      dplyr::coalesce(as.numeric(rank_vec), Inf),
      -st$win_pct, -st$sov, -st$sos, -st$pd, st$team
    )
    teams_ordered <- st$team[ord]
    champs_ordered <- teams_ordered[teams_ordered %in% st$team[st$conf_champ == TRUE]]
    auto <- head(champs_ordered, min(5L, playoff_seeds))
    at_large <- setdiff(teams_ordered, auto)
    field <- c(auto, head(at_large, playoff_seeds - length(auto)))
    # Straight seeding: seed in overall order among the field
    field_ordered <- teams_ordered[teams_ordered %in% field]
    st$seed <- match(st$team, field_ordered)
    st
  }

  standings |>
    dplyr::group_split(.data[[id_col]]) |>
    purrr::map(seed_one_sim) |>
    purrr::list_rbind()
}
