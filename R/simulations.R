#' Simulate a College Football Season
#'
#' @description
#' Simulates college football seasons based on a games/schedule table that
#' holds matchups with and without results. Missing results are computed
#' week by week using the pluggable `compute_results` function (default:
#' [cfbseedR_compute_results()], an ELO-based generator adapted from
#' nflseedR). After the scheduled games, standings, conference champions,
#' and CFP seeds are computed, and - with `sim_include = "POST"` - the
#' playoff bracket is simulated round by round.
#'
#' @inheritParams cfb_standings
#' @param games A data frame of games of a **single** season, in the schema
#'   of [cfb_standings()] plus an optional `neutral` column (0/1). Games
#'   with `result = NA` are simulated. Must not contain
#'   `game_type == "POST"` rows - the playoff bracket is generated from the
#'   computed seeds.
#' @param compute_results A function computing results of games, with
#'   the required arguments `teams`, `games`, and `week_num`. See
#'   [simulations_verify_fct()] for the contract and
#'   [cfbseedR_compute_results()] for the default.
#' @param ... Additional parameters passed on to `compute_results`.
#' @param simulations The number of times the season shall be simulated.
#' @param playoff_seeds Number of CFP spots (default 12), passed to
#'   [cfb_playoff_seeds()].
#' @param sim_include One of `"POST"` (default) or `"REG"`:
#'   - `"REG"`: simulate the remaining schedule and compute standings,
#'     conference champions, and playoff seeds.
#'   - `"POST"`: `"REG"` + simulate the playoff bracket.
#' @param rankings Optional committee rankings (`team`, `rank`) used for CFP
#'   seeding, held static across simulations. When `NULL`, seeding falls
#'   back to the per-simulation standings ordering (see
#'   [cfb_playoff_seeds()]).
#'
#' @details
#' The playoff bracket is a standard single-elimination bracket of size
#' `2^ceiling(log2(playoff_seeds))` with byes for the top seeds - for 12
#' seeds this reproduces the CFP bracket (quarterfinals 1 vs 8/9 winner,
#' 4 vs 5/12, 3 vs 6/11, 2 vs 7/10). First-round games are hosted by the
#' higher seed; later rounds are neutral-site. There is no reseeding
#' (fixed bracket, per the CFP format). Conference championship matchups
#' are simulated as scheduled, not re-derived from simulated standings.
#'
#' Simulations run sequentially (no chunk/parallel support). Set a seed
#' with `set.seed()` for reproducibility.
#'
#' @return A list of class `cfbseedR_simulation` with the elements
#' \describe{
#'  \item{standings}{Per-simulation standings incl. `seed` and (with
#'    `sim_include = "POST"`) `exit` (0 = missed playoff, r = eliminated in
#'    round r, max + 1 = national champion).}
#'  \item{games}{All simulated games of all simulations.}
#'  \item{overall}{Per-team probabilities across simulations: mean `wins`,
#'    `conf_champ`, `playoff`, `seed1`, `won_natty`.}
#'  \item{team_wins}{Probabilities of clearing each half-win threshold.}
#'  \item{game_summary}{Per-matchup aggregate results.}
#'  \item{sim_params}{The simulation parameters.}
#' }
#'
#' @examples
#' games <- read.csv(system.file("extdata", "toy_games.csv", package = "cfbseedR"))
#' teams <- read.csv(system.file("extdata", "toy_teams.csv", package = "cfbseedR"))
#' games$result[games$week >= 3] <- NA
#' set.seed(4)
#' sim <- cfb_simulations(games, teams, simulations = 4, playoff_seeds = 4)
#' sim$overall
#'
#' @seealso [cfb_standings()], [cfb_playoff_seeds()],
#'   [cfbseedR_compute_results()], [simulations_verify_fct()],
#'   the nflseedR original: <https://nflseedr.com>
#' @export
cfb_simulations <- function(games,
                            teams,
                            compute_results = cfbseedR_compute_results,
                            ...,
                            simulations = 10000L,
                            playoff_seeds = 12L,
                            tiebreaker_depth = c("SOS", "PRE-SOV", "POINTS", "RANDOM"),
                            sim_include = c("POST", "REG"),
                            rankings = NULL) {
  tiebreaker_depth <- rlang::arg_match(tiebreaker_depth)
  sim_include <- rlang::arg_match(sim_include)
  if (!is.function(compute_results)) {
    cli::cli_abort("The {.arg compute_results} argument must be a function!")
  }
  simulations <- as.integer(simulations)
  playoff_seeds <- as.integer(playoff_seeds)

  games <- standings_validate_games(games, allow_na_results = TRUE)
  season <- unique(games$sim)
  if (length(season) > 1) {
    cli::cli_abort(
      "{.fun cfb_simulations} can only handle one season, got {.val {season}}."
    )
  }
  if ("POST" %in% games$game_type) {
    cli::cli_abort(
      "{.arg games} must not contain {.val POST} games - the playoff bracket
       is generated from the computed seeds."
    )
  }
  if (!anyNA(games$result)) {
    cli::cli_abort(
      "There are no games left to simulate because there are no {.val NA}
       values in the result column of {.arg games}. If you want standings,
       please see {.fun cfb_standings}."
    )
  }
  teams <- standings_validate_teams(teams, games)
  if (!"neutral" %in% names(games)) games$neutral <- 0L

  # Replicate games and teams across simulations
  n_games <- nrow(games)
  n_teams <- nrow(teams)
  sim_games <- games[rep(seq_len(n_games), times = simulations), ] |>
    dplyr::mutate(sim = rep(seq_len(simulations), each = n_games))
  sim_teams <- teams[rep(seq_len(n_teams), times = simulations), ] |>
    dplyr::mutate(sim = rep(seq_len(simulations), each = n_teams))

  # SIMULATE SCHEDULED GAMES WEEK BY WEEK ------------------------------------
  weeks_to_simulate <- sort(unique(games$week[is.na(games$result)]))
  cli::cli_inform(
    "Start simulation of {simulations} season{?s} ({length(weeks_to_simulate)}
     week{?s} to simulate)."
  )
  for (week_num in weeks_to_simulate) {
    out <- compute_results(
      teams = sim_teams, games = sim_games, week_num = week_num, ...
    )
    sim_teams <- out$teams
    sim_games <- out$games
  }

  # STANDINGS, CHAMPIONS, SEEDS ----------------------------------------------
  dg <- standings_double_games(sim_games, teams)
  standings <- standings_init(dg)
  depth <- switch(tiebreaker_depth,
    "RANDOM" = 0L, "PRE-SOV" = 1L, "SOS" = 2L, "POINTS" = 3L
  )
  standings <- standings_add_conf_ranks(standings, dg, depth, verbosity = 0L)
  standings <- standings_add_conf_champ(standings, dg)
  standings <- cfb_playoff_seeds(
    standings, rankings = rankings, playoff_seeds = playoff_seeds
  )

  # PLAYOFF SIMULATION --------------------------------------------------------
  if (sim_include == "POST") {
    post <- sims_simulate_playoffs(
      sim_games = sim_games, sim_teams = sim_teams, standings = standings,
      compute_results = compute_results, ..., playoff_seeds = playoff_seeds
    )
    sim_games <- post$games
    standings <- standings |>
      dplyr::left_join(post$exits, by = dplyr::join_by("sim", "team")) |>
      dplyr::mutate(exit = dplyr::coalesce(.data$exit, 0L))
    champ_exit <- post$champ_exit
  }

  standings <- standings |>
    dplyr::arrange(.data$sim, .data$conference, .data$conf_rank, .data$team)

  # AGGREGATE ACROSS SIMULATIONS ----------------------------------------------
  overall <- standings |>
    dplyr::summarise(
      wins = mean(.data$wins),
      conf_champ = mean(.data$conf_champ),
      playoff = mean(!is.na(.data$seed)),
      seed1 = mean(!is.na(.data$seed) & .data$seed == 1L),
      won_natty = if (sim_include == "POST") {
        mean(.data$exit == champ_exit)
      } else {
        NA_real_
      },
      .by = c("conference", "team")
    ) |>
    dplyr::arrange(.data$conference, .data$team)

  max_g <- max(standings$games)
  team_wins <- tidyr::expand_grid(
    team = sort(unique(standings$team)),
    wins = seq(0, max_g, 0.5)
  ) |>
    dplyr::left_join(
      dplyr::select(standings, "sim", "team", true_wins = "wins"),
      by = dplyr::join_by("team"),
      relationship = "many-to-many"
    ) |>
    dplyr::summarise(
      over_prob = mean(.data$true_wins > .data$wins),
      under_prob = mean(.data$true_wins < .data$wins),
      .by = c("team", "wins")
    )

  game_summary <- sim_games |>
    dplyr::summarise(
      away_wins = sum(.data$result < 0),
      home_wins = sum(.data$result > 0),
      ties = sum(.data$result == 0),
      result = mean(.data$result),
      .by = c("game_type", "week", "away_team", "home_team")
    ) |>
    dplyr::mutate(
      games_played = .data$away_wins + .data$home_wins + .data$ties,
      away_percentage = (.data$away_wins + 0.5 * .data$ties) / .data$games_played,
      home_percentage = (.data$home_wins + 0.5 * .data$ties) / .data$games_played
    ) |>
    dplyr::arrange(.data$week, .data$away_team)

  out <- structure(
    list(
      "standings" = standings,
      "games" = sim_games,
      "overall" = overall,
      "team_wins" = team_wins,
      "game_summary" = game_summary,
      "sim_params" = list(
        "cfb_season" = season,
        "playoff_seeds" = playoff_seeds,
        "simulations" = simulations,
        "tiebreaker_depth" = tiebreaker_depth,
        "sim_include" = sim_include,
        "cfbseedR_version" = utils::packageVersion("cfbseedR"),
        "finished_at" = Sys.time()
      )
    ),
    class = "cfbseedR_simulation"
  )
  cli::cli_inform("DONE!")
  out
}

# Standard bracket seed order for a bracket of size m (power of 2), e.g.
# m = 16 gives c(1,16,8,9,4,13,5,12,2,15,7,10,3,14,6,11): adjacent pairs are
# the first-round matchups, adjacent pair-winners meet next round.
bracket_seed_order <- function(m) {
  cur <- 1L
  while (length(cur) < m) {
    n2 <- 2L * length(cur)
    cur <- as.integer(as.vector(rbind(cur, n2 + 1L - cur)))
  }
  cur
}

# Simulate the playoff bracket for all sims at once, round by round.
# Returns list(games = updated sim_games, exits = tibble(sim, team, exit),
# champ_exit = exit code of the national champion).
sims_simulate_playoffs <- function(sim_games, sim_teams, standings,
                                   compute_results, ..., playoff_seeds) {
  bracket_size <- 2L^as.integer(ceiling(log2(playoff_seeds)))
  n_rounds <- as.integer(log2(bracket_size))
  order_vec <- bracket_seed_order(bracket_size)
  max_week <- max(sim_games$week)

  seeds_tbl <- standings |>
    dplyr::filter(!is.na(.data$seed)) |>
    dplyr::select("sim", "team", "seed")

  alive <- tidyr::expand_grid(
    sim = unique(standings$sim), pos = seq_len(bracket_size)
  ) |>
    dplyr::mutate(seed = order_vec[.data$pos]) |>
    dplyr::left_join(seeds_tbl, by = dplyr::join_by("sim", "seed"))

  exits <- vector("list", n_rounds + 1L)

  for (r in seq_len(n_rounds)) {
    wk <- max_week + r
    pairs <- alive |>
      dplyr::filter(!is.na(.data$team)) |>
      dplyr::mutate(pair = ceiling(.data$pos / 2L)) |>
      dplyr::arrange(.data$sim, .data$pair, .data$seed) |>
      dplyr::summarise(
        home_team = .data$team[1],
        home_seed = .data$seed[1],
        away_team = dplyr::if_else(dplyr::n() > 1L, .data$team[2], NA),
        away_seed = dplyr::if_else(dplyr::n() > 1L, .data$seed[2], NA),
        .by = c("sim", "pair")
      )

    round_games <- pairs |>
      dplyr::filter(!is.na(.data$away_team)) |>
      dplyr::transmute(
        .data$sim,
        game_type = "POST",
        week = wk,
        home_team = .data$home_team,
        away_team = .data$away_team,
        result = NA_real_,
        # First round on campus (higher seed hosts), later rounds neutral
        neutral = dplyr::if_else(r == 1L, 0L, 1L)
      )

    if (nrow(round_games) > 0L) {
      sim_games <- dplyr::bind_rows(sim_games, round_games)
      out <- compute_results(
        teams = sim_teams, games = sim_games, week_num = wk, ...
      )
      sim_teams <- out$teams
      sim_games <- out$games
    }

    results_wk <- sim_games |>
      dplyr::filter(.data$week == wk, .data$game_type == "POST") |>
      dplyr::select("sim", "home_team", "away_team", "result")

    decided <- pairs |>
      dplyr::filter(!is.na(.data$away_team)) |>
      dplyr::left_join(
        results_wk, by = dplyr::join_by("sim", "home_team", "away_team")
      ) |>
      dplyr::mutate(
        home_won = .data$result > 0,
        winner = dplyr::if_else(.data$home_won, .data$home_team, .data$away_team),
        winner_seed = dplyr::if_else(.data$home_won, .data$home_seed, .data$away_seed),
        loser = dplyr::if_else(.data$home_won, .data$away_team, .data$home_team)
      )

    exits[[r]] <- dplyr::transmute(decided, .data$sim, team = .data$loser, exit = r)

    byes <- pairs |>
      dplyr::filter(is.na(.data$away_team)) |>
      dplyr::transmute(
        .data$sim, pos = .data$pair,
        seed = .data$home_seed, team = .data$home_team
      )
    alive <- dplyr::bind_rows(
      byes,
      dplyr::transmute(
        decided, .data$sim, pos = .data$pair,
        seed = .data$winner_seed, team = .data$winner
      )
    )
  }

  champ_exit <- n_rounds + 1L
  exits[[champ_exit]] <- dplyr::transmute(
    alive, .data$sim, .data$team, exit = champ_exit
  )

  list(
    games = sim_games,
    exits = purrr::list_rbind(exits),
    champ_exit = champ_exit
  )
}
