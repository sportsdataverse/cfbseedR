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
#'   totals (noted, see `tiebreak_notes` below). An optional `conf_division`
#'   column (e.g. `"East"`/`"West"`) turns on division-format ranking for a
#'   conference: each division is ranked separately (with that conference's
#'   registered procedure) and the division champions take `conf_rank` 1-2.
#'   Supplying divisions for a conference IS the opt-in - correct for the
#'   2026 Sun Belt and equally for historical divisional seasons of any
#'   conference. An optional logical `postseason_eligible` column (explicit
#'   `FALSE` = ineligible) keeps a team out of the championship-game ranks
#'   while its games still count in every comparison (the ACC policy makes
#'   this explicit); with fewer than two eligible teams in a conference the
#'   remaining `conf_rank` 1-2 slots are necessarily filled by ineligible
#'   teams. `teams` need not
#'   list every team that appears in `games` - an unlisted opponent (e.g. an
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
#'   unregistered conferences; the registered official procedures below
#'   always run in full.
#' @param playoff_seeds If not `NULL`, a `seed` column is added via
#'   [cfb_playoff_seeds()] with this number of playoff spots.
#' @param rankings Optional committee-style rankings data frame with columns
#'   `team` and `rank`, passed to [cfb_playoff_seeds()]. Ignored when
#'   `playoff_seeds` is `NULL`.
#' @param tiebreaker_data Optional named list of external inputs for the
#'   official registry rungs. Supported: `analytics_ratings`, a data frame
#'   with columns `team` and `rating` (feeds the SportSource-style rating /
#'   metric-composite rungs used by the Big Ten, Big 12, ACC, MAC,
#'   American, CUSA, Mountain West, and Sun Belt - supply your own
#'   composite of the conference's published metrics), and `cfp_rankings`,
#'   a data frame with columns `team` and `rank` (feeds the
#'   `cfp_ranked_final_week` clause used by the American, CUSA, and Sun
#'   Belt), and `apr`, a data frame with columns `team` and `apr`
#'   (multi-year Academic Progress Rate, the CUSA policy's late fallback).
#'   A missing input -> that rung is skipped (noted).
#' @param verbosity One of `"MIN"` (default), `"MAX"`, or `"NONE"`.
#'   `"MAX"` logs every tied group as it's broken.
#'
#' @details
#' Conference ranks are seeded by conference win percentage; ties within a
#' tier are broken by a documented cascade. **Registered conferences** (SEC,
#' Big Ten, Big 12, ACC, MAC, American, Conference USA, Mountain West, Sun
#' Belt) use their **official procedures** (see "Official per-conference
#' tiebreakers" below); every other conference - including the re-formed
#' Pac-12, which has not published a procedure - uses the **generic
#' fallback**: head-to-head record among the tied teams, record vs. common
#' conference opponents (minimum one), conference-scoped strength of
#' victory, conference-scoped strength of schedule, conference point
#' differential, and finally a coin flip, gated by `tiebreaker_depth`.
#' All cascade quantities are computed over regular-season conference games
#' so conference ranks depend only on conference play.
#'
#' ## Official per-conference tiebreakers
#'
#' `CONFERENCE_TIEBREAKERS` (internal) registers each conference's official
#' procedure as a list of season-scoped **epochs**, so a policy change
#' applies from its first season: with a `season` id column, the ACC's
#' all-new 2026 policy (head-to-head, then SportSource Team Success
#' Ranking, then a draw, with the alternate-game-count candidate-pool rule)
#' applies from 2026 while earlier seasons keep the 2024 cascade; plain
#' `sim` ids resolve to the current rules. The SEC/Big Ten/Big 12 2024
#' procedures are ported verbatim from sdv-py's `cfb_standings.py` so both
#' engines produce identical output on the shared cross-language parity
#' fixture. Rung primitives: `h2h` (multi-team combined
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
#' `tiebreaker_data$analytics_ratings` - stands in for each conference's
#' published metric composite, e.g. Connelly SP+ / ESPN SOR / KPI /
#' SportSource for the American, CUSA, and Mountain West),
#' `cfp_ranked_final_week` (American/CUSA/Sun Belt: the best-ranked tied
#' team advances if it won its final conference game, else the clause falls
#' through; needs `tiebreaker_data$cfp_rankings`), `div_pct` (Sun Belt:
#' win pct vs same-division opponents; needs `teams$conf_division`), and
#' `coin_toss`. After each team is
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
#' \donttest{
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
#' }
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
  # When the input identified rows by `season`, the sim ids ARE seasons -
  # used to resolve season-scoped registry epochs (e.g. the 2026 ACC
  # policy). Plain `sim` ids resolve to the current rules.
  seasons_by_sim <- if (uses_season) {
    ids <- unique(games$sim)
    setNames(suppressWarnings(as.numeric(ids)), as.character(ids))
  } else {
    NULL
  }
  standings <- standings_add_conf_ranks(
    standings, dg, depth, verbosity, notes_env, division_absent,
    teams = teams, seasons_by_sim = seasons_by_sim
  )
  standings <- standings_add_conf_champ(standings, dg)

  if (!is.null(playoff_seeds)) {
    if (verbosity > 0L) cli::cli_inform("Compute playoff seeds")
    standings <- cfb_playoff_seeds(
      standings, rankings = rankings, playoff_seeds = playoff_seeds
    )
  }

  standings <- standings |>
    dplyr::select(-dplyr::any_of(c(
      "capped_margin", "capped_wins", "analytics_rating", "cfp_rank", "div_pct", "apr"
    ))) |>
    dplyr::arrange(.data$sim, .data$conference, .data$conf_rank, .data$team)
  if (uses_season) standings <- dplyr::rename(standings, season = "sim")
  attr(standings, "tiebreak_notes") <- notes_env$notes
  standings
}

#' Compute College Football Playoff Seeds
#'
#' @description
#' Implements 12-team CFP **straight seeding** with a season-keyed
#' automatic-qualifier policy:
#'
#' * `autobid = "2026"` (default, current rule): the ACC, Big 12, Big Ten
#'   and SEC champions are in **regardless of ranking**; the highest-ranked
#'   team from the Group of 6 (American, Conference USA, MAC, Mountain
#'   West, Pac-12, Sun Belt) is in whether or not it won its conference;
#'   and Notre Dame is in if ranked inside the top `playoff_seeds`.
#' * `autobid = "2025"`: the 5 highest-ranked conference champions are
#'   guaranteed inclusion (the 2024-2025 rule).
#'
#' Under both policies seeds are assigned strictly in ranking order
#' (champions are not bumped up; straight seeding, 2025+).
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
#' @param autobid Automatic-qualifier policy, `"2026"` (default) or
#'   `"2025"` - see Description.
#'
#' @details
#' Under `autobid = "2025"`, if there are fewer than 5 conference champions
#' all champions are guaranteed (capped at `playoff_seeds`). Under either
#' policy a guaranteed team ranked outside the top `playoff_seeds`
#' displaces the lowest-ranked at-large team and is seeded by its rank
#' order within the field. Conference names are matched against both cfbd
#' and short spellings (e.g. `"American Athletic"` / `"American"`).
#'
#' @return The `standings` input (all its columns unchanged; see
#'   [cfb_standings()] for the column table) with one column added:
#'
#' | Column | Type | Description |
#' |---|---|---|
#' | `seed` | integer | CFP seed in straight-seeding order; `NA` for teams outside the playoff field. |
#'
#' @examples
#' \donttest{
#' games <- read.csv(system.file("extdata", "toy_games.csv", package = "cfbseedR"))
#' teams <- read.csv(system.file("extdata", "toy_teams.csv", package = "cfbseedR"))
#' standings <- cfb_standings(games, teams, tiebreaker_depth = "POINTS",
#'                            verbosity = "NONE")
#' rankings <- data.frame(team = c("B1", "I1", "A1", "A3"), rank = 1:4)
#' seeded <- cfb_playoff_seeds(standings, rankings = rankings, playoff_seeds = 4)
#' seeded[!is.na(seeded$seed), c("team", "seed")]
#'
#' }
#' @seealso [cfb_standings()], [cfb_simulations()],
#'   the nflseedR original: <https://nflseedr.com>
#' @export
cfb_playoff_seeds <- function(standings, rankings = NULL, playoff_seeds = 12L,
                              autobid = c("2026", "2025")) {
  autobid <- rlang::arg_match(autobid)
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
    champs <- st$team[st$conf_champ == TRUE]
    if (autobid == "2025") {
      # 2024-2025 rule: the 5 highest-ranked conference champions.
      champs_ordered <- teams_ordered[teams_ordered %in% champs]
      auto <- head(champs_ordered, min(5L, playoff_seeds))
    } else {
      # 2026 rule: P4 champions regardless of ranking + the highest-ranked
      # Group-of-6 team (champion or not) + Notre Dame if ranked inside
      # the field size.
      p4 <- c(
        "SEC", "Southeastern Conference",
        "Big Ten", "Big Ten Conference",
        "ACC", "Atlantic Coast Conference",
        "Big 12", "Big 12 Conference"
      )
      g6 <- c(
        "American Athletic", "American", "American Athletic Conference",
        "American Conference", "Conference USA", "CUSA",
        "MAC", "Mid-American", "Mid-American Conference",
        "Mountain West", "Mountain West Conference",
        "Pac-12", "Pac-12 Conference", "Sun Belt", "Sun Belt Conference"
      )
      conf_of <- setNames(st$conference, st$team)
      auto <- teams_ordered[teams_ordered %in% champs & conf_of[teams_ordered] %in% p4]
      g6_teams <- teams_ordered[conf_of[teams_ordered] %in% g6]
      if (length(g6_teams) > 0L) auto <- union(auto, g6_teams[1])
      nd_rank <- rank_vec[match("Notre Dame", st$team)]
      if (!is.na(nd_rank) && nd_rank <= playoff_seeds) {
        auto <- union(auto, "Notre Dame")
      }
      auto <- head(teams_ordered[teams_ordered %in% auto], playoff_seeds)
    }
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
