# Internal standings helpers. Mirrors nflseedR's standings_utils.R /
# standings_init.R architecture, adapted to CFB (conferences, independents,
# CONF_CHAMP games), plus the official per-conference tiebreaker registry
# in `R/tiebreakers.R` (ported from sdv-py `cfb_standings.py`).

is_independent <- function(conference) {
  is.na(conference) | conference == "FBS Independents"
}

# Validate the games input. Mirrors nflseedR::standings_validate_games():
# accepts `sim` or `season` as the grouping id (warns if both), requires the
# engine columns, and (outside of simulations) errors on NA results.
standings_validate_games <- function(games, allow_na_results = FALSE,
                                     call = rlang::caller_env()) {
  games <- tibble::as_tibble(games)
  required_vars <- c("game_type", "week", "away_team", "home_team", "result")
  if (all(c("sim", "season") %in% names(games))) {
    cli::cli_warn(
      "The {.arg games} argument includes both {.val sim} and {.val season}.
       Will group by {.val sim}.",
      call = call
    )
    games$season <- NULL
  }
  uses_season <- all(c("season", required_vars) %in% names(games))
  uses_sim <- all(c("sim", required_vars) %in% names(games))
  if (!any(uses_sim, uses_season)) {
    cli::cli_abort(
      "The {.arg games} argument has to be a table including one of the
       identifiers {.val sim} or {.val season} as well as all of the
       following variables: {.val {required_vars}}!",
      call = call
    )
  }
  if (uses_season && !uses_sim) {
    games <- dplyr::rename(games, sim = "season")
  }
  if (!allow_na_results && anyNA(games$result)) {
    cli::cli_abort(
      "The {.arg games} table includes {.val NA} results! Please fix and rerun.",
      call = call
    )
  }
  attr(games, "uses_season") <- uses_season && !uses_sim
  games
}

# Validate the teams input. Unlike a prior revision of this function, teams
# are NOT required to exhaustively list every team that appears in `games`:
# an opponent absent from `teams` (e.g. an FCS-or-lower team an FBS
# conference member scheduled) simply gets no standings row of its own -
# its games still count toward the listed team's own record and toward the
# Big 12 `total_wins` FCS cap (an unknown opponent counts as FCS-or-lower;
# see `standings_add_capped_wins()`). This mirrors sdv-py's `cfb_standings.py`
# `_validate_teams`, which never cross-checks `teams` against `games` at all,
# and is exercised by the `cfb_toy_tiebreakers` parity fixture (Big 12 teams
# there play unlisted `FCS1`/`FCS2`/`FCS3` opponents on purpose).
standings_validate_teams <- function(teams, call = rlang::caller_env()) {
  teams <- tibble::as_tibble(teams)
  if (!all(c("team", "conference") %in% names(teams))) {
    cli::cli_abort(
      "The {.arg teams} argument must include the variables {.val team} and
       {.val conference}.",
      call = call
    )
  }
  dplyr::distinct(teams, .data$team, .keep_all = TRUE)
}

# Long format: one row per (game, team perspective). Adapted from
# nflseedR::standings_double_games(). Carries `pf`/`pa` (points for/against)
# when `games` has `home_points`/`away_points` - feeds the SEC
# `capped_scoring_margin` official tiebreaker rung; NA otherwise (that rung
# is then skipped, see `standings_add_capped_margin()`).
standings_double_games <- function(games, teams) {
  conf_vec <- setNames(teams$conference, teams$team)
  if (!all(c("home_points", "away_points") %in% names(games))) {
    games$home_points <- NA_real_
    games$away_points <- NA_real_
  }
  dg <- dplyr::bind_rows(
    dplyr::transmute(
      games, .data$sim, .data$game_type, .data$week,
      team = .data$away_team, opp = .data$home_team, result = -.data$result,
      pf = .data$away_points, pa = .data$home_points
    ),
    dplyr::transmute(
      games, .data$sim, .data$game_type, .data$week,
      team = .data$home_team, opp = .data$away_team, result = .data$result,
      pf = .data$home_points, pa = .data$away_points
    )
  )
  dg |>
    dplyr::mutate(
      outcome = dplyr::case_when(
        is.na(.data$result) ~ NA_real_,
        .data$result > 0 ~ 1,
        .data$result < 0 ~ 0,
        .default = 0.5
      ),
      team_conf = unname(conf_vec[.data$team]),
      opp_conf = unname(conf_vec[.data$opp]),
      # Conference games: REG games between two members of the same
      # (non-independent) conference. CONF_CHAMP explicitly excluded.
      conf_game = .data$game_type == "REG" &
        !is_independent(.data$team_conf) &
        .data$team_conf == .data$opp_conf
    )
}

# Initial standings: overall record over ALL games (REG + CONF_CHAMP + POST),
# conference record over conference REG games only, and conference-scoped
# SOV/SOS (nflseedR formula applied to conference games with opponents'
# conference records). Adapted from nflseedR::standings_init().
#
# Unlike the pre-registry revision, standings are seeded from a (sim x
# `teams`) cross join rather than from whichever teams happen to appear in
# `dg` - this is what excludes unlisted opponents (see
# `standings_validate_teams()`) from getting their own standings row while
# their games still count for everyone else, matching sdv-py's
# `_standings_base` cross-join base.
standings_init <- function(dg, teams) {
  sims <- dplyr::distinct(dg, .data$sim)
  base <- tidyr::expand_grid(sims, team = teams$team) |>
    dplyr::left_join(dplyr::select(teams, "team", "conference"), by = "team")

  overall <- dg |>
    dplyr::summarise(
      games = dplyr::n(),
      wins = sum(.data$outcome == 1),
      losses = sum(.data$outcome == 0),
      ties = sum(.data$outcome == 0.5),
      win_pct = sum(.data$outcome) / dplyr::n(),
      pd = sum(.data$result),
      .by = c("sim", "team")
    )

  conf_rec <- dg |>
    dplyr::filter(.data$conf_game == TRUE) |>
    dplyr::summarise(
      conf_games = dplyr::n(),
      conf_wins = sum(.data$outcome == 1),
      conf_losses = sum(.data$outcome == 0),
      conf_ties = sum(.data$outcome == 0.5),
      conf_pct = sum(.data$outcome) / dplyr::n(),
      conf_pd = sum(.data$result),
      .by = c("sim", "team")
    )

  # Conference-scoped strength of victory / schedule:
  # sov = sum(conf wins of beaten conf opponents) / sum(their conf games)
  # sos = sum(conf wins of all conf opponents) / sum(their conf games)
  # (this `sos` formula is already the POOLED opponents' conference win pct
  # the registry's `opp_conf_win_pct` rung needs - see `R/tiebreakers.R`.)
  opp_rec <- conf_rec |>
    dplyr::transmute(
      .data$sim, opp = .data$team,
      opp_wins = .data$conf_wins + 0.5 * .data$conf_ties,
      opp_games = .data$conf_games
    )
  sov_sos <- dg |>
    dplyr::filter(.data$conf_game == TRUE) |>
    dplyr::inner_join(opp_rec, by = dplyr::join_by("sim", "opp")) |>
    dplyr::summarise(
      sov = dplyr::if_else(
        sum(.data$outcome == 1) == 0, 0,
        sum(.data$opp_wins * (.data$outcome == 1)) /
          sum(.data$opp_games * (.data$outcome == 1))
      ),
      sos = sum(.data$opp_wins) / sum(.data$opp_games),
      .by = c("sim", "team")
    )

  base |>
    dplyr::left_join(overall, by = dplyr::join_by("sim", "team")) |>
    dplyr::left_join(conf_rec, by = dplyr::join_by("sim", "team")) |>
    dplyr::left_join(sov_sos, by = dplyr::join_by("sim", "team")) |>
    dplyr::mutate(
      dplyr::across(c("games", "wins", "losses", "ties"), \(x) dplyr::coalesce(x, 0L)),
      dplyr::across(
        c("conf_games", "conf_wins", "conf_losses", "conf_ties",
          "conf_pct", "conf_pd", "sov", "sos"),
        \(x) dplyr::coalesce(x, 0)
      ),
      win_pct = dplyr::coalesce(.data$win_pct, 0),
      pd = dplyr::coalesce(.data$pd, 0)
    )
}

# SEC capped relative scoring margin over conference games (per game: points
# scored capped at 42, points allowed capped at 48). Returns NULL when
# `games` never carried `home_points`/`away_points` at all (the rung is then
# always skipped); a team whose conference games have any missing points
# gets `NA` (that team's comparison is skipped, matching sdv-py).
standings_add_capped_margin <- function(dg, has_pts) {
  if (!has_pts) return(NULL)
  dg |>
    dplyr::filter(.data$conf_game == TRUE) |>
    dplyr::summarise(
      pts_null = sum(is.na(.data$pf) | is.na(.data$pa)),
      cm_sum = sum(pmin(.data$pf, SEC_OFF_CAP) - pmin(.data$pa, SEC_DEF_CAP)),
      .by = c("sim", "team")
    ) |>
    dplyr::mutate(
      capped_margin = dplyr::if_else(.data$pts_null > 0, NA_real_, .data$cm_sum)
    ) |>
    dplyr::select("sim", "team", "capped_margin")
}

# Big 12 total wins with the FCS cap (max `fcs_cap` wins vs an FCS-or-lower
# opponent counted, over ALL games - not just conference games). An opponent
# counts as FCS-or-lower when it's absent from `teams` entirely, or carries
# a non-FBS `division`. Returns NULL when `teams` has no `division` column
# at all (the rung then falls back to uncapped win totals, noted).
standings_add_capped_wins <- function(dg, teams, fcs_cap) {
  if (!"division" %in% names(teams)) return(NULL)
  opp_info <- teams |>
    dplyr::transmute(opp = .data$team, opp_div = .data$division, opp_known = TRUE)
  dg |>
    dplyr::left_join(opp_info, by = "opp") |>
    dplyr::mutate(
      is_fcs = is.na(.data$opp_known) |
        (!is.na(.data$opp_div) & tolower(.data$opp_div) != "fbs")
    ) |>
    dplyr::summarise(
      fcs_w = sum(.data$outcome == 1 & .data$is_fcs),
      all_w = sum(.data$outcome == 1),
      .by = c("sim", "team")
    ) |>
    dplyr::mutate(capped_wins = .data$all_w - .data$fcs_w + pmin(.data$fcs_w, fcs_cap)) |>
    dplyr::select("sim", "team", "capped_wins")
}

# Attach the three registry-rung metric columns (`capped_margin`,
# `capped_wins`, `analytics_rating`) shared by `cfb_standings()` and
# `cfb_simulations()`. Each degrades deterministically (see the two helpers
# above + the `analytics_rating` branch here) when its optional input is
# absent; `standings_add_conf_ranks()` records the degradation once per
# conference in `tiebreak_notes`.
standings_add_tiebreak_metrics <- function(standings, dg, teams, tiebreaker_data = NULL) {
  has_pts <- all(c("pf", "pa") %in% names(dg))
  cm <- standings_add_capped_margin(dg, has_pts)
  standings <- if (is.null(cm)) {
    dplyr::mutate(standings, capped_margin = NA_real_)
  } else {
    dplyr::left_join(standings, cm, by = dplyr::join_by("sim", "team"))
  }

  cw <- standings_add_capped_wins(dg, teams, B12_FCS_CAP)
  standings <- if (is.null(cw)) {
    dplyr::mutate(standings, capped_wins = as.double(.data$wins))
  } else {
    dplyr::left_join(standings, cw, by = dplyr::join_by("sim", "team")) |>
      dplyr::mutate(capped_wins = dplyr::coalesce(.data$capped_wins, 0))
  }

  if (!is.null(tiebreaker_data) && !is.null(tiebreaker_data$analytics_ratings)) {
    ar <- tibble::as_tibble(tiebreaker_data$analytics_ratings) |>
      dplyr::transmute(
        team = as.character(.data$team),
        analytics_rating = as.double(.data$rating)
      )
    standings <- dplyr::left_join(standings, ar, by = "team")
  } else {
    standings <- dplyr::mutate(standings, analytics_rating = NA_real_)
  }
  standings
}

# Add conf_rank to standings. Independents get NA. Ties within a
# conference win-pct tier are broken by the conference's registered
# official procedure (`CONFERENCE_TIEBREAKERS`, `R/tiebreakers.R`), falling
# back to `.generic_cascade` for unregistered conferences (byte-identical
# to the pre-registry behavior, including `tiebreaker_depth` gating).
#
# ponytail: one `dplyr::group_split()` per (sim, conference) with a rung
# walk inside - fine at toy/test scale and the existing simulation scale
# this package already exercises; vectorize the rung engine if 10k-sim
# tiebreaking of many-conference schedules ever becomes a hot path (mirrors
# the same ponytail note in sdv-py's `_build_rec_map`).
standings_add_conf_ranks <- function(standings, dg, depth, verbosity,
                                     notes_env, division_absent) {
  non_ind <- standings |> dplyr::filter(!is_independent(.data$conference))
  cg_all <- dg |> dplyr::filter(.data$conf_game == TRUE)

  ranked <- non_ind |>
    dplyr::group_split(.data$sim, .data$conference) |>
    purrr::map(function(grp) {
      sim_id <- grp$sim[1]
      conf_name <- grp$conference[1]
      rungs <- CONFERENCE_TIEBREAKERS[[conf_name]]
      if (is.null(rungs)) rungs <- .generic_cascade
      cg <- cg_all[cg_all$sim == sim_id & cg_all$team_conf == conf_name, ]

      conf_pct_by_team <- setNames(grp$conf_pct, grp$team)
      metrics <- setNames(
        purrr::map(seq_len(nrow(grp)), function(i) {
          list(
            sov = grp$sov[i],
            sos = grp$sos[i],
            conf_pd = grp$conf_pd[i],
            opp_wp_pooled = grp$sos[i],
            capped_margin = grp$capped_margin[i],
            capped_wins = grp$capped_wins[i],
            analytics_rating = grp$analytics_rating[i]
          )
        }),
        grp$team
      )
      ctx <- list(
        conf_name = conf_name,
        conf_pct_by_team = conf_pct_by_team,
        division_absent = division_absent
      )

      pct_rounded <- round(grp$conf_pct, 9)
      rank <- 1L
      rows <- list()
      for (p in sort(unique(pct_rounded), decreasing = TRUE)) {
        tier <- grp$team[pct_rounded == p]
        if (length(tier) > 1L) {
          if (verbosity >= 2L) {
            cli::cli_inform("Breaking tie of {.val {tier}} in {.val {conf_name}} (sim {sim_id}).")
          }
          tier <- .order_tied(tier, metrics, cg, rungs, depth, ctx, notes_env)
        }
        for (team in tier) {
          rows[[length(rows) + 1L]] <- tibble::tibble(sim = sim_id, team = team, conf_rank = rank)
          rank <- rank + 1L
        }
      }
      purrr::list_rbind(rows)
    }) |>
    purrr::list_rbind()

  standings |>
    dplyr::left_join(ranked, by = dplyr::join_by("sim", "team"))
}

# Conference champion: winner of the CONF_CHAMP game when one exists for the
# conference, else the conf_rank 1 team. Independents are never champions.
standings_add_conf_champ <- function(standings, dg) {
  champ_winners <- dg |>
    dplyr::filter(.data$game_type == "CONF_CHAMP", .data$outcome == 1) |>
    dplyr::distinct(.data$sim, .data$team) |>
    dplyr::mutate(ccg_winner = TRUE)
  # Conferences that HAVE a championship game (by participant conference)
  ccg_confs <- dg |>
    dplyr::filter(.data$game_type == "CONF_CHAMP", !is.na(.data$team_conf)) |>
    dplyr::distinct(.data$sim, conference = .data$team_conf) |>
    dplyr::mutate(has_ccg = TRUE)

  standings |>
    dplyr::left_join(champ_winners, by = dplyr::join_by("sim", "team")) |>
    dplyr::left_join(ccg_confs, by = dplyr::join_by("sim", "conference")) |>
    dplyr::mutate(
      conf_champ = dplyr::case_when(
        is_independent(.data$conference) ~ FALSE,
        !is.na(.data$has_ccg) ~ dplyr::coalesce(.data$ccg_winner, FALSE),
        .default = dplyr::coalesce(.data$conf_rank == 1L, FALSE)
      )
    ) |>
    dplyr::select(-dplyr::any_of(c("ccg_winner", "has_ccg")))
}
