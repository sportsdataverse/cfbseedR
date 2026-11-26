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

test_that("cfb_simulations() rejects an unlisted team in an unplayed game", {
  games <- cfb_games_example
  teams <- cfb_teams_example

  # An opponent that never appears in `teams` -- the FBS-vs-FCS shape. Without
  # the guard this silently fills every simulated week with NA results, and
  # then fails much later with an unrelated complaint about playoff_seeds.
  ghost <- games[1, ]
  ghost$week <- 4L
  ghost$away_team <- "Ghost FCS"
  ghost$result <- NA_real_
  games <- rbind(games, ghost)
  games$result[games$week >= 3] <- NA_real_

  expect_error(
    cfb_simulations(games, teams,
      simulations = 2, playoff_seeds = 4, chunks = 1, verbosity = "NONE"
    ),
    regexp = "Ghost FCS"
  )
})

test_that("a PLAYED game against an unlisted team is still allowed", {
  # cfb_standings() supports unlisted opponents on purpose, and the guard must
  # not take that away: only games still awaiting a result need both sides
  # rated. A played FCS game keeps counting toward the listed team's record.
  games <- cfb_games_example
  teams <- cfb_teams_example

  ghost <- games[1, ]
  ghost$week <- 1L
  ghost$away_team <- "Ghost FCS"
  ghost$result <- 21
  games <- rbind(games, ghost)
  games$result[games$week >= 3] <- NA_real_

  set.seed(4)
  expect_no_error(
    sim <- cfb_simulations(games, teams,
      simulations = 2, playoff_seeds = 4, chunks = 1, verbosity = "NONE"
    )
  )
  # And the simulation actually produced results rather than a season of NAs.
  # (Not `all(wins > 0)`: A4, B4 and I1 have no win in the played weeks, so a
  # team can legitimately go winless across 2 sims and that check was flaky.)
  expect_false(anyNA(sim$games$result))
  expect_true(sum(sim$overall$wins) > 0)
})

test_that("cfb_simulations() rejects an NA team name in an unplayed game", {
  # `standings_validate_games()` checks that the team columns exist and that
  # results are not NA, but never that the team names themselves are named. An
  # NA team has no rating, so it propagates NAs exactly like an unlisted one.
  games <- cfb_games_example
  teams <- cfb_teams_example

  nameless <- games[1, ]
  nameless$week <- 4L
  nameless$away_team <- NA_character_
  nameless$result <- NA_real_
  games <- rbind(games, nameless)
  games$result[games$week >= 3] <- NA_real_

  expect_error(
    cfb_simulations(games, teams,
      simulations = 2, playoff_seeds = 4, chunks = 1, verbosity = "NONE"
    ),
    regexp = "must name both teams"
  )
})

test_that("cfbseedR_compute_results uses the fitted CFB home field and margin noise", {
  # Defaults fitted by data-raw/cfb_elo_constants.R (not nflseedR's 20 / 13).
  defaults <- formals(cfbseedR_compute_results)
  expect_identical(defaults$home_field, 59.4)
  expect_identical(defaults$margin_sd, 16.7)

  games <- sim_input()
  games$sim <- 1
  teams <- load_toy_teams()
  teams$sim <- 1
  elo <- setNames(rep(1500, nrow(teams)), teams$team)
  wk3 <- games$week == 3
  expect_true(all(games$game_type[wk3] == "REG"))

  # Equal ratings and (almost) no noise: every home margin is the home edge,
  # 59.4 / 25 = 2.376 points, rounded away from zero.
  set.seed(1)
  out <- cfbseedR_compute_results(teams, games, 3, elo = elo, margin_sd = 1e-9)
  expect_true(all(out$games$result[wk3] == 3L))

  # Both stay overridable; the NFL value 20 is a 0.8-point edge.
  set.seed(1)
  nfl <- cfbseedR_compute_results(teams, games, 3,
    elo = elo, home_field = 20, margin_sd = 1e-9
  )
  expect_true(all(nfl$games$result[wk3] == 1L))
})

test_that("cfbseedR_compute_results re-decides a postseason tie by one point", {
  # Equal ratings, a neutral site and no noise: the estimate is exactly 0, so
  # every draw is a tie and goes to the win-probability re-break (+-1, as in
  # sdv-py; +-3 before 0.3.0).
  teams <- data.frame(sim = 1, team = c("A", "B"), conference = "X")
  games <- data.frame(
    sim = 1, week = 1, game_type = "POST", home_team = "A", away_team = "B",
    result = NA_integer_, neutral = 1
  )
  elo <- c(A = 1500, B = 1500)
  set.seed(1)
  res <- replicate(20, cfbseedR_compute_results(
    teams, games, 1, elo = elo, margin_sd = 0
  )$games$result)
  expect_true(all(res %in% c(-1L, 1L)))
  expect_true(all(c(-1L, 1L) %in% res))
})

test_that("simulations_verify_fct names each broken part of the compute_results contract", {
  # Generators that break one rule each, built from a correct fill of the week.
  fill_week <- function(games, week_num, value = 3) {
    todo <- games$week == week_num & is.na(games$result)
    games$result[todo] <- value
    games
  }
  breaks <- function(fn) {
    function(teams, games, week_num, ...) list(teams = teams, games = fn(games, week_num))
  }

  expect_error(simulations_verify_fct("not a function"), "must be a function")
  expect_error(
    simulations_verify_fct(breaks(function(g, w) fill_week(g, w)[-1, ])),
    "number of rows"
  )
  expect_error(
    simulations_verify_fct(breaks(function(g, w) fill_week(g, w)[, setdiff(names(g), "neutral")])),
    "removed columns"
  )
  expect_error(
    simulations_verify_fct(breaks(function(g, w) g)),
    "did not compute all results"
  )
  expect_error(
    simulations_verify_fct(breaks(function(g, w) {
      g <- fill_week(g, w)
      g$result <- as.character(g$result)
      g
    })),
    "non-numeric"
  )
  # A tie is fine in the regular season but not in the week-15 CONF_CHAMP game.
  expect_error(
    simulations_verify_fct(breaks(function(g, w) fill_week(g, w, value = 0))),
    "tie in a postseason game"
  )
  # Week 3 keeps one played result; a generator that rewrites it is caught.
  games <- cfb_games_example
  games$result[games$week >= 3] <- NA
  games$result[which(games$week == 3)[1]] <- 10
  expect_error(
    simulations_verify_fct(
      breaks(function(g, w) {
        g$result[g$week == w] <- 1
        g
      }),
      games = games
    ),
    "overwrote existing results"
  )
})

test_that("a conf_game FALSE game stays out of simulated conference standings", {
  games <- sim_input()
  games$conf_game <- NA
  games$conf_game[games$home_team == "A1" & games$away_team == "A2" & games$week == 1] <- FALSE
  run <- function(g) {
    set.seed(11)
    suppressMessages(cfb_simulations(
      g, load_toy_teams(), simulations = 3, playoff_seeds = 4, tiebreaker_depth = "SOS"
    ))$standings
  }
  flagged <- run(games)
  plain <- run(games[setdiff(names(games), "conf_game")])
  a1 <- function(st) st$conf_games[st$team == "A1"]
  expect_equal(a1(flagged), a1(plain) - 1)
  # still an A1 win in the overall record
  expect_equal(flagged$games[flagged$team == "A1"], plain$games[plain$team == "A1"])
})
