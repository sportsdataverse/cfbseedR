# Surface parity with nflseedR: chunked simulation, verbosity, the summary
# S3 method, fmt_pct_special, exported example data, and ranks = "NONE".

sim_inputs <- function() {
  games <- cfb_games_example
  games$result[games$week >= 3] <- NA
  list(games = games, teams = cfb_teams_example)
}

test_that("exported example data matches the bundled fixtures", {
  testthat::skip_on_cran()
  csv_games <- utils::read.csv(
    system.file("extdata", "toy_games.csv", package = "cfbseedR"),
    stringsAsFactors = FALSE
  )
  csv_teams <- utils::read.csv(
    system.file("extdata", "toy_teams.csv", package = "cfbseedR"),
    stringsAsFactors = FALSE
  )
  expect_equal(as.data.frame(cfb_games_example), csv_games)
  expect_equal(as.data.frame(cfb_teams_example), csv_teams)
})

test_that("chunking splits every simulation exactly once", {
  testthat::skip_on_cran()
  i <- sim_inputs()
  set.seed(4)
  s <- cfb_simulations(i$games, i$teams, simulations = 8, playoff_seeds = 4,
                       chunks = 4, verbosity = "NONE")
  expect_equal(sort(unique(s$standings$sim)), 1:8)
  expect_equal(s$sim_params$chunks, 4L)
  # one standings row per (sim, team), no chunk duplicated or dropped
  expect_equal(nrow(s$standings), 8L * nrow(i$teams))
})

test_that("an uneven split still yields exactly the requested chunk count", {
  testthat::skip_on_cran()
  i <- sim_inputs()
  # 10 simulations over 6 chunks: slicing by a rounded-up chunk size would
  # quietly produce 5 chunks of 2. Sizes must differ by at most one.
  set.seed(4)
  s <- cfb_simulations(i$games, i$teams, simulations = 10, playoff_seeds = 4,
                       chunks = 6, verbosity = "NONE")
  expect_equal(s$sim_params$chunks, 6L)
  expect_equal(sort(unique(s$standings$sim)), 1:10)
  expect_equal(nrow(s$standings), 10L * nrow(i$teams))
})

test_that("chunks are capped at the simulation count", {
  testthat::skip_on_cran()
  i <- sim_inputs()
  set.seed(4)
  s <- cfb_simulations(i$games, i$teams, simulations = 3, playoff_seeds = 4,
                       chunks = 16, verbosity = "NONE")
  expect_equal(s$sim_params$chunks, 3L)
  expect_equal(sort(unique(s$standings$sim)), 1:3)
})

test_that("a seed reproduces the same simulation for fixed chunks", {
  testthat::skip_on_cran()
  i <- sim_inputs()
  set.seed(11)
  a <- cfb_simulations(i$games, i$teams, simulations = 6, playoff_seeds = 4,
                       chunks = 3, verbosity = "NONE")
  set.seed(11)
  b <- cfb_simulations(i$games, i$teams, simulations = 6, playoff_seeds = 4,
                       chunks = 3, verbosity = "NONE")
  expect_equal(a$overall, b$overall)
  expect_equal(a$standings, b$standings)
})

test_that("cfb_simulations rejects a nonsense chunk count", {
  testthat::skip_on_cran()
  i <- sim_inputs()
  expect_error(
    cfb_simulations(i$games, i$teams, simulations = 4, chunks = 0,
                    verbosity = "NONE"),
    regexp = "chunks"
  )
})

test_that("verbosity is plumbed through and NONE stays silent", {
  testthat::skip_on_cran()
  i <- sim_inputs()
  set.seed(4)
  expect_silent(
    s <- cfb_simulations(i$games, i$teams, simulations = 2, playoff_seeds = 4,
                         chunks = 1, verbosity = "NONE")
  )
  expect_equal(s$sim_params$verbosity, "NONE")
  set.seed(4)
  expect_message(
    cfb_simulations(i$games, i$teams, simulations = 2, playoff_seeds = 4,
                    chunks = 1, verbosity = "MIN"),
    regexp = "Start simulation"
  )
})

test_that("simulations surface their tiebreak notes", {
  testthat::skip_on_cran()
  i <- sim_inputs()
  set.seed(4)
  s <- cfb_simulations(i$games, i$teams, simulations = 2, playoff_seeds = 4,
                       chunks = 1, verbosity = "NONE")
  expect_false(is.null(attr(s$standings, "tiebreak_notes")))
})

test_that("summary() dispatches on cfbseedR_simulation", {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("gt")
  testthat::skip_if_not_installed("scales")
  i <- sim_inputs()
  set.seed(4)
  s <- cfb_simulations(i$games, i$teams, simulations = 2, playoff_seeds = 4,
                       chunks = 1, verbosity = "NONE")
  expect_s3_class(summary(s), "gt_tbl")
})

test_that("fmt_pct_special keeps long-shots and near-locks legible", {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("scales")
  expect_equal(
    fmt_pct_special(c(0, 0.0004, 0.123, 0.9994, 1)),
    c("0%", "<1%", "12%", ">99.9%", "100%")
  )
  expect_error(fmt_pct_special(c(0.5, 1.5)), regexp = "between 0 and 1")
  expect_error(fmt_pct_special("a"), regexp = "numeric vector")
})

test_that("ranks = 'NONE' skips the rank cascade", {
  testthat::skip_on_cran()
  games <- cfb_games_example
  st_none <- cfb_standings(games, cfb_teams_example, ranks = "NONE",
                           verbosity = "NONE")
  st_conf <- cfb_standings(games, cfb_teams_example, verbosity = "NONE")
  expect_false("conf_rank" %in% names(st_none))
  expect_false("conf_champ" %in% names(st_none))
  expect_true("conf_rank" %in% names(st_conf))
  # the records themselves are untouched by the skip
  expect_equal(
    st_none[order(st_none$team), c("team", "wins", "losses", "conf_pct")],
    st_conf[order(st_conf$team), c("team", "wins", "losses", "conf_pct")]
  )
})
