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
#' Optional `home_points`/`away_points` columns (per-game scores) feed the
#' official SEC `capped_scoring_margin` tiebreaker rung (see "Official
#' per-conference tiebreakers" below); [cfb_games_from_schedule()] emits
#' both. Absent -> that rung is skipped, not an error.
#' @param teams A data frame with columns `team` and `conference`. Teams with
#'   conference `"FBS Independents"` or `NA` are treated as independents:
#'   they appear in overall standings but receive no conference rank. An
#'   optional `division` column (e.g. `"FBS"`/`"FCS"`) feeds the Big 12
#'   `total_wins` FCS cap; absent -> that cap degrades to uncapped win
#'   totals (noted, see `tiebreak_notes` below). `teams` need not list every
#'   team that appears in `games` - an unlisted opponent (e.g. an
#'   FCS-or-lower team) gets no standings row of its own, but its games
#'   still count toward its opponents' records and toward the Big 12
#'   `total_wins` FCS cap (an unknown opponent counts as FCS-or-lower).
#' @param ... Currently unused.
#' @param tiebreaker_depth One of `"SOS"` (default), `"PRE-SOV"`, `"POINTS"`,
#'   or `"RANDOM"`. Controls how deep the tiebreaker cascade goes before
#'   falling back to a coin flip:
#'   - `"RANDOM"`: coin flip immediately.
#'   - `"PRE-SOV"`: head-to-head and common opponents only.
#'   - `"SOS"`: adds strength of victory, then strength of schedule.
#'   - `"POINTS"`: adds conference point differential.
#'
#'   This depth ladder gates ONLY the generic fallback cascade used by
#'   unregistered conferences; the SEC/Big Ten/Big 12/ACC/MAC official
#'   procedures below always run in full.
#' @param playoff_seeds If not `NULL`, a `seed` column is added via
#'   [cfb_playoff_seeds()] with this number of playoff spots.
#' @param rankings Optional committee-style rankings data frame with columns
#'   `team` and `rank`, passed to [cfb_playoff_seeds()]. Ignored when
#'   `playoff_seeds` is `NULL`.
#' @param tiebreaker_data Optional named list of external inputs for the
#'   official registry rungs. Currently supported: `analytics_ratings`, a
#'   data frame with columns `team` and `rating` (feeds the SportSource
#'   Analytics-style rating rung used by Big Ten/Big 12/ACC/MAC). Missing
#'   -> that rung is skipped for those conferences (noted).
#' @param verbosity One of `"MIN"` (default), `"MAX"`, or `"NONE"`.
#'   `"MAX"` logs every tied group as it's broken.
#'
#' @details
#' Conference ranks are seeded by conference win percentage; ties within a
#' tier are broken by a documented cascade. **Registered conferences** (SEC,
#' Big Ten, Big 12, ACC, MAC) use their **official 2024+ procedures** (see
#' "Official per-conference tiebreakers" below); every other conference uses
#' the **generic fallback**: head-to-head record among the tied teams,
#' record vs. common conference opponents (minimum one), conference-scoped
#' strength of victory, conference-scoped strength of schedule, conference
#' point differential, and finally a coin flip, gated by `tiebreaker_depth`.
#' All cascade quantities are computed over regular-season conference games
#' so conference ranks depend only on conference play.
#'
#' ## Official per-conference tiebreakers
#'
#' `CONFERENCE_TIEBREAKERS` (internal) registers the SEC, Big Ten, Big 12,
#' ACC, and MAC 2024+ procedures as rung lists, ported verbatim from sdv-py's
#' `cfb_standings.py` so both engines produce identical output on the shared
#' cross-language parity fixture. Rung primitives: `h2h` (multi-team combined
#' head-to-head, applied only when every tied pair played; otherwise only
#' "defeated-all" elimination - the symmetric "lost-to-all" elimination is
#' intentionally not modeled, a documented simplification, see
#' `R/tiebreakers.R`), `record_vs_common`, `record_vs_common_desc` (descend
#' the standings from best to worst, comparing a tied GROUP of common
#' opponents collectively - the Big 12 rule, adopted for every registry
#' descent rung), `opp_conf_win_pct` (pooled opponents' conference win pct -
#' this reuses the existing `sos` column, which already computes the pooled
#' sum-of-wins/sum-of-games formula), `capped_scoring_margin` (SEC: points
#' scored capped at 42 / allowed capped at 48, per game, summed over
#' conference games; needs `home_points`/`away_points`), `total_wins` (Big
#' 12: overall wins with at most one win vs an FCS-or-lower opponent
#' counted; needs `teams$division`), `analytics_rating` (external, via
#' `tiebreaker_data$analytics_ratings`), and `coin_toss`. After each team is
#' seeded/eliminated the procedure restarts from the first rung with the
#' remaining tied set; when a rung's required input is unavailable it is
#' skipped deterministically and the skip is recorded once (per conference)
#' in `attr(result, "tiebreak_notes")`. Under registry conferences,
#' `conf_rank` 1-2 are the two teams that reach the conference championship
#' game (the cascade only orders them - see the design brief).
#'
#' @return A tibble of standings, one row per (`sim`, `team`) (the id column
#'   is named `season` if the input used `season`), sorted by sim,
#'   conference, conference rank, and team. Note that `sov` and `sos` are
#'   **conference-REG-scoped**: they are computed over regular-season
#'   conference games only, `sov` over conference victories and `sos` over
#'   conference opponents; independents get `0.0` for both. The result also
#'   carries a character vector `attr(result, "tiebreak_notes")` recording
#'   any registry rungs skipped for lack of their optional input (see
#'   "Official per-conference tiebreakers" above); empty when nothing was
#'   skipped.
#'
#' | Column | Type | Description |
#' |---|---|---|
#' | `sim` / `season` | integer | Season or simulation ID (name follows the input). |
#' | `team` | character | Team name. |
#' | `conference` | character | Conference name (`"FBS Independents"` / `NA` = independent). |
#' | `games` | integer | Games played (`REG` + `CONF_CHAMP`). |
#' | `wins` | integer | True win count (ties not counted). |
#' | `losses` | integer | True loss count. |
#' | `ties` | integer | Tie count. |
#' | `win_pct` | numeric | Overall win percentage; a tie counts as half a win. |
#' | `pd` | integer | Overall point differential. |
#' | `conf_games` | numeric | Regular-season conference games played (0 for independents). |
#' | `conf_wins` | numeric | Wins over regular-season conference games. |
#' | `conf_losses` | numeric | Losses over regular-season conference games. |
#' | `conf_ties` | numeric | Ties over regular-season conference games. |
#' | `conf_pct` | numeric | Conference win percentage (`CONF_CHAMP` games excluded). |
#' | `conf_pd` | numeric | Point differential over regular-season conference games. |
#' | `sov` | numeric | Strength of victory, conference-REG-scoped: beaten conference opponents' conference wins divided by their conference games. Independents: `0.0`. |
#' | `sos` | numeric | Strength of schedule, conference-REG-scoped: all conference opponents' conference wins divided by their conference games. Independents: `0.0`. |
#' | `conf_rank` | integer | Rank within the conference via the tiebreaker cascade (`NA` for independents). |
#' | `conf_champ` | logical | Conference champion flag (decided by the `CONF_CHAMP` game). |
#' | `seed` | integer | CFP seed, only when `playoff_seeds` is not `NULL` (`NA` outside the field). |
#'
#' @examples
#' games <- read.csv(system.file("extdata", "toy_games.csv", package = "cfbseedR"))
#' teams <- read.csv(system.file("extdata", "toy_teams.csv", package = "cfbseedR"))
#' standings <- cfb_standings(games, teams, tiebreaker_depth = "POINTS",
#'                            verbosity = "NONE")
#' standings[, c("team", "conference", "conf_rank", "conf_champ")]
#'
#' # An official-registry analytics rating input (used by Big Ten/Big
#' # 12/ACC/MAC when their cascade reaches the `analytics_rating` rung)
#' ratings <- data.frame(team = teams$team, rating = seq(90, 70, length.out = nrow(teams)))
#' standings2 <- cfb_standings(games, teams,
#'                             tiebreaker_data = list(analytics_ratings = ratings),
#'                             verbosity = "NONE")
#' attr(standings2, "tiebreak_notes")
#'
#' @seealso [cfb_playoff_seeds()], [cfb_simulations()],
#'   [cfb_games_from_schedule()],
#'   the nflseedR original: <https://nflseedr.com>,
#'   and [cfbfastR](https://cfbfastR.sportsdataverse.org) for real schedules
#' @export
cfb_standings <- function(games,
                          teams,
                          ...,
                          tiebreaker_depth = c("SOS", "PRE-SOV", "POINTS", "RANDOM"),
                          playoff_seeds = NULL,
                          rankings = NULL,
                          tiebreaker_data = NULL,
                          verbosity = c("MIN", "MAX", "NONE")) {
  tiebreaker_depth <- rlang::arg_match(tiebreaker_depth)
  depth <- switch(tiebreaker_depth,
    "RANDOM" = 0L, "PRE-SOV" = 1L, "SOS" = 2L, "POINTS" = 3L
  )
  verbosity <- rlang::arg_match(verbosity)
  verbosity <- switch(verbosity, "NONE" = 0L, "MIN" = 1L, "MAX" = 2L)

  games <- standings_validate_games(games)
  uses_season <- isTRUE(attr(games, "uses_season"))
  teams <- standings_validate_teams(teams)

  if (verbosity > 0L) cli::cli_inform("Initiate standings & tiebreaking data")
  dg <- standings_double_games(games, teams)
  standings <- standings_init(dg, teams)
  standings <- standings_add_tiebreak_metrics(standings, dg, teams, tiebreaker_data)
  division_absent <- !("division" %in% names(teams))
  notes_env <- new.env(parent = emptyenv())
  notes_env$notes <- character(0)

  if (verbosity > 0L) cli::cli_inform("Compute conference ranks")
  standings <- standings_add_conf_ranks(
    standings, dg, depth, verbosity, notes_env, division_absent
  )
  standings <- standings_add_conf_champ(standings, dg)

  if (!is.null(playoff_seeds)) {
    if (verbosity > 0L) cli::cli_inform("Compute playoff seeds")
    standings <- cfb_playoff_seeds(
      standings, rankings = rankings, playoff_seeds = playoff_seeds
    )
  }

  standings <- standings |>
    dplyr::select(-dplyr::any_of(c("capped_margin", "capped_wins", "analytics_rating"))) |>
    dplyr::arrange(.data$sim, .data$conference, .data$conf_rank, .data$team)
  if (uses_season) standings <- dplyr::rename(standings, season = "sim")
  attr(standings, "tiebreak_notes") <- notes_env$notes
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
#' @return The `standings` input (all its columns unchanged; see
#'   [cfb_standings()] for the column table) with one column added:
#'
#' | Column | Type | Description |
#' |---|---|---|
#' | `seed` | integer | CFP seed in straight-seeding order; `NA` for teams outside the playoff field. |
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
#' @seealso [cfb_standings()], [cfb_simulations()],
#'   the nflseedR original: <https://nflseedr.com>
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
