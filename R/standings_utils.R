# Internal standings helpers. Mirrors nflseedR's standings_utils.R /
# standings_init.R architecture, adapted to CFB (conferences, independents,
# CONF_CHAMP games).

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

standings_validate_teams <- function(teams, games, call = rlang::caller_env()) {
  teams <- tibble::as_tibble(teams)
  if (!all(c("team", "conference") %in% names(teams))) {
    cli::cli_abort(
      "The {.arg teams} argument must include the variables {.val team} and
       {.val conference}.",
      call = call
    )
  }
  game_teams <- unique(c(games$home_team, games$away_team))
  missing <- setdiff(game_teams, teams$team)
  if (length(missing) > 0) {
    cli::cli_abort(
      "The following teams appear in {.arg games} but not in {.arg teams}:
       {.val {missing}}",
      call = call
    )
  }
  dplyr::distinct(teams, .data$team, .keep_all = TRUE)
}

# Long format: one row per (game, team perspective). Adapted from
# nflseedR::standings_double_games().
standings_double_games <- function(games, teams) {
  conf_vec <- setNames(teams$conference, teams$team)
  dg <- dplyr::bind_rows(
    dplyr::transmute(
      games, .data$sim, .data$game_type, .data$week,
      team = .data$away_team, opp = .data$home_team, result = -.data$result
    ),
    dplyr::transmute(
      games, .data$sim, .data$game_type, .data$week,
      team = .data$home_team, opp = .data$away_team, result = .data$result
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
standings_init <- function(dg) {
  overall <- dg |>
    dplyr::summarise(
      games = dplyr::n(),
      wins = sum(.data$outcome == 1),
      losses = sum(.data$outcome == 0),
      ties = sum(.data$outcome == 0.5),
      win_pct = sum(.data$outcome) / dplyr::n(),
      pd = sum(.data$result),
      conference = .data$team_conf[1],
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

  overall |>
    dplyr::left_join(conf_rec, by = dplyr::join_by("sim", "team")) |>
    dplyr::left_join(sov_sos, by = dplyr::join_by("sim", "team")) |>
    dplyr::mutate(dplyr::across(
      c("conf_games", "conf_wins", "conf_losses", "conf_ties",
        "conf_pct", "conf_pd", "sov", "sos"),
      \(x) dplyr::coalesce(x, 0)
    )) |>
    dplyr::relocate("conference", .after = "team")
}

# Head-to-head record over conference REG games. Adapted from
# nflseedR::standings_h2h().
standings_h2h <- function(dg) {
  dg |>
    dplyr::filter(.data$conf_game == TRUE) |>
    dplyr::summarise(
      h2h_games = dplyr::n(),
      h2h_wins = sum(.data$outcome),
      .by = c("sim", "team", "opp")
    )
}

# Break a tie among `tied` teams (character vector, length >= 2) within one
# (sim, conference) group. Returns the single winning team.
#
# Cascade (each step keeps the argmax subset; if the subset shrinks, the
# cascade restarts from the first step with the survivors - NFL-style):
#   depth >= 1: head-to-head win pct among tied teams (skipped unless every
#               tied team played at least one other tied team)
#   depth >= 1: record vs common conference opponents (min 1 common)
#   depth >= 2: conference-scoped SOV, then SOS
#   depth >= 3: conference point differential (POINTS)
#   fallback  : coin flip
break_tie <- function(tied, st, h2h, cg, depth, verbosity) {
  tol <- 1e-12
  keep_max <- function(teams, values) {
    teams[values >= max(values) - tol]
  }
  log_step <- function(step, survivors) {
    if (verbosity >= 2L) {
      cli::cli_inform(
        "Tie of {.val {tied}} reduced to {.val {survivors}} via {step}."
      )
    }
  }

  repeat {
    if (length(tied) == 1L) return(tied)

    if (depth >= 1L) {
      # Head-to-head among the tied teams
      hh <- h2h[h2h$team %in% tied & h2h$opp %in% tied, ]
      if (nrow(hh) > 0 && all(tied %in% hh$team)) {
        pct <- hh |>
          dplyr::summarise(
            v = sum(.data$h2h_wins) / sum(.data$h2h_games), .by = "team"
          )
        survivors <- keep_max(pct$team, pct$v)
        if (length(survivors) < length(tied)) {
          log_step("head-to-head", survivors)
          tied <- survivors
          next
        }
      }

      # Record vs common conference opponents (min 1 common)
      opp_sets <- lapply(tied, \(t) unique(cg$opp[cg$team == t]))
      common <- setdiff(Reduce(intersect, opp_sets), tied)
      if (length(common) >= 1L) {
        vs <- cg[cg$team %in% tied & cg$opp %in% common, ] |>
          dplyr::summarise(v = sum(.data$outcome) / dplyr::n(), .by = "team")
        survivors <- keep_max(vs$team, vs$v)
        if (length(survivors) < length(tied)) {
          log_step("common opponents", survivors)
          tied <- survivors
          next
        }
      }
    }

    if (depth >= 2L) {
      shrunk <- FALSE
      for (metric in c("sov", "sos")) {
        vals <- st[[metric]][match(tied, st$team)]
        survivors <- keep_max(tied, vals)
        if (length(survivors) < length(tied)) {
          log_step(metric, survivors)
          tied <- survivors
          shrunk <- TRUE
          break
        }
      }
      if (shrunk) next
    }

    if (depth >= 3L) {
      vals <- st$conf_pd[match(tied, st$team)]
      survivors <- keep_max(tied, vals)
      if (length(survivors) < length(tied)) {
        log_step("point differential", survivors)
        tied <- survivors
        next
      }
    }

    # Coin flip
    winner <- sample(tied, 1L)
    if (verbosity >= 2L) {
      cli::cli_inform("Tie of {.val {tied}} broken via coin flip: {.val {winner}}.")
    }
    return(winner)
  }
}

# Assign conference ranks within one (sim, conference) group.
# Iteratively picks the best remaining team: primary key is conference win
# pct, ties resolved via break_tie().
rank_conference <- function(st, h2h, cg, depth, verbosity) {
  remaining <- st$team
  out <- setNames(integer(length(remaining)), remaining)
  r <- 1L
  tol <- 1e-12
  while (length(remaining) > 0L) {
    pct <- st$conf_pct[match(remaining, st$team)]
    best <- remaining[pct >= max(pct) - tol]
    winner <- if (length(best) == 1L) {
      best
    } else {
      break_tie(best, st, h2h, cg, depth, verbosity)
    }
    out[[winner]] <- r
    r <- r + 1L
    remaining <- setdiff(remaining, winner)
  }
  out
}

# Add conf_rank to standings. Independents get NA.
standings_add_conf_ranks <- function(standings, dg, depth, verbosity) {
  h2h_all <- standings_h2h(dg)
  cg_all <- dg |> dplyr::filter(.data$conf_game == TRUE)

  ranked <- standings |>
    dplyr::filter(!is_independent(.data$conference)) |>
    dplyr::group_split(.data$sim, .data$conference) |>
    purrr::map(\(st) {
      h2h <- h2h_all[h2h_all$sim == st$sim[1], ]
      cg <- cg_all[cg_all$sim == st$sim[1] & cg_all$team_conf == st$conference[1], ]
      ranks <- rank_conference(st, h2h, cg, depth, verbosity)
      tibble::tibble(
        sim = st$sim[1], team = names(ranks), conf_rank = unname(ranks)
      )
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
