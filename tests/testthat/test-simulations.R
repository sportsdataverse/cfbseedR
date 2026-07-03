sim_input <- function() {
  games <- load_toy_games()
  games$result[games$week >= 3] <- NA
  games
}

test_that("simulation smoke: 50 sims, valid probabilities, deterministic", {
  run <- function() {
    set.seed(37)
    suppressMessages(cfb_simulations(
      sim_input(), load_toy_teams(),
      simulations = 50, playoff_seeds = 4, tiebreaker_depth = "SOS"
    ))
  }
  sim <- run()

  expect_s3_class(sim, "cfbseedR_simulation")
  expect_named(
    sim,
    c("standings", "games", "overall", "team_wins", "game_summary", "sim_params")
  )

  overall <- sim$overall
  expect_equal(nrow(overall), 9L)
  for (col in c("conf_champ", "playoff", "seed1", "won_natty")) {
    expect_true(all(overall[[col]] >= 0 & overall[[col]] <= 1), info = col)
  }
  # Exactly one national champion per simulation
  expect_equal(sum(overall$won_natty), 1)
  # Exactly one champ per conference per sim (2 conferences)
  expect_equal(sum(overall$conf_champ), 2)
  # Independents can make the playoff but never win a conference
  expect_equal(overall$conf_champ[overall$team == "I1"], 0)

  # 17 scheduled games + 3 playoff games (4-team bracket) per simulation
  expect_equal(nrow(sim$games), 50 * 20L)
  expect_false(anyNA(sim$games$result))
  # No postseason ties
  post <- sim$games[sim$games$game_type != "REG", ]
  expect_true(all(post$result != 0))

  # standings bookkeeping
  st <- sim$standings
  expect_equal(nrow(st), 50 * 9L)
  expect_true(all(st$exit[is.na(st$seed)] == 0L))
  expect_equal(sum(st$exit == 3L), 50L) # one champion (exit 3) per sim
  expect_true(all(st$seed %in% c(NA, 1:4)))

  # team_wins probabilities are monotone in the threshold
  tw <- sim$team_wins[sim$team_wins$team == "B1", ]
  tw <- tw[order(tw$wins), ]
  expect_true(all(diff(tw$over_prob) <= 1e-12))
  expect_true(all(tw$over_prob >= 0 & tw$over_prob <= 1))

  # Deterministic under the same seed
  sim2 <- run()
  expect_equal(sim$overall, sim2$overall)
  expect_equal(sim$standings, sim2$standings)
})

test_that("sim_include = 'REG' skips the playoff simulation", {
  set.seed(1)
  sim <- suppressMessages(cfb_simulations(
    sim_input(), load_toy_teams(),
    simulations = 5, playoff_seeds = 4, sim_include = "REG"
  ))
  expect_false("POST" %in% sim$games$game_type)
  expect_false("exit" %in% names(sim$standings))
  expect_true(all(is.na(sim$overall$won_natty)))
  expect_true("seed" %in% names(sim$standings))
})

test_that("static rankings drive the CFP seeding inside simulations", {
  rankings <- data.frame(
    team = c("B1", "A1", "I1", "A3", "A2", "B2", "B3", "A4", "B4"),
    rank = 1:9
  )
  set.seed(7)
  sim <- suppressMessages(cfb_simulations(
    sim_input(), load_toy_teams(),
    simulations = 10, playoff_seeds = 4, rankings = rankings
  ))
  # A4/B4 are ranked last and are never conference champions -> never seeded
  expect_equal(sim$overall$playoff[sim$overall$team %in% c("A4", "B4")], c(0, 0))
})

test_that("cfb_simulations validates its input", {
  games <- load_toy_games()
  teams <- load_toy_teams()
  # nothing to simulate
  expect_error(
    suppressMessages(cfb_simulations(games, teams, simulations = 2)),
    regexp = "no games left"
  )
  # POST games are not accepted
  g <- sim_input()
  g$game_type[1] <- "POST"
  expect_error(
    suppressMessages(cfb_simulations(g, teams, simulations = 2)),
    regexp = "POST"
  )
  # compute_results must be a function
  expect_error(
    suppressMessages(cfb_simulations(sim_input(), teams, compute_results = 1)),
    regexp = "function"
  )
})

test_that("simulations_verify_fct accepts the default and rejects broken functions", {
  expect_true(simulations_verify_fct(cfbseedR_compute_results))

  # fills every week at once -> must fail
  fills_everything <- function(teams, games, week_num, ...) {
    games$result[is.na(games$result)] <- 3
    list(teams = teams, games = games)
  }
  expect_error(
    simulations_verify_fct(fills_everything),
    regexp = "outside of week"
  )

  # wrong return shape -> must fail
  wrong_shape <- function(teams, games, week_num, ...) games
  expect_error(
    simulations_verify_fct(wrong_shape),
    regexp = "list"
  )

  # missing required argument -> must fail
  expect_error(
    simulations_verify_fct(function(teams, games) list(teams, games)),
    regexp = "week_num"
  )
})

test_that("cfbseedR_compute_results honors the elo argument and week gating", {
  games <- sim_input()
  games$sim <- 1
  teams <- load_toy_teams()
  teams$sim <- 1
  elo <- setNames(rep(1500, 9), teams$team)
  elo[["B1"]] <- 3000 # overwhelming favorite

  set.seed(11)
  out <- cfbseedR_compute_results(teams, games, week_num = 3, elo = elo)
  # only week 3 results were filled
  expect_false(anyNA(out$games$result[out$games$week == 3]))
  expect_true(all(is.na(out$games$result[out$games$week > 3])))
  # weeks 1-2 untouched
  expect_identical(
    out$games$result[out$games$week <= 2],
    games$result[games$week <= 2]
  )
  # elo was carried into teams and updated
  expect_true("elo" %in% names(out$teams))
})
