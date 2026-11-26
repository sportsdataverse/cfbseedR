toy_ratings <- function(teams = load_toy_teams()) {
  data.frame(team = teams$team, rating = seq(10, -10, length.out = nrow(teams)))
}

toy_week3 <- function() {
  games <- load_toy_games()
  games$result[games$week >= 3] <- NA
  games
}

test_that("cfbseedR_ratings_compute_results meets the compute_results contract", {
  for (type in c("points", "adj_epa", "raw_epa")) {
    expect_true(simulations_verify_fct(
      cfbseedR_ratings_compute_results,
      ratings = toy_ratings(), rating_type = type
    ))
  }
})

test_that("only this week's unplayed games get a result and teams pass through", {
  games <- toy_week3()
  teams <- load_toy_teams()
  teams$sim <- games$sim[1]
  out <- cfbseedR_ratings_compute_results(teams, games, 3, ratings = toy_ratings())
  wk3 <- out$games$week == 3
  expect_false(anyNA(out$games$result[wk3]))
  expect_true(all(is.na(out$games$result[out$games$week > 3])))
  expect_identical(out$games$result[out$games$week < 3], games$result[games$week < 3])
  expect_type(out$games$result[wk3], "integer")
  expect_identical(out$teams, teams)
})

test_that("results are reproducible with a seed and follow the ratings", {
  games <- toy_week3()
  teams <- load_toy_teams()
  set.seed(7)
  a <- cfbseedR_ratings_compute_results(teams, games, 3, ratings = toy_ratings())
  set.seed(7)
  b <- cfbseedR_ratings_compute_results(teams, games, 3, ratings = toy_ratings())
  expect_identical(a$games, b$games)

  # With no noise the simulated margin is the rounded expected margin.
  r <- toy_ratings()
  out <- cfbseedR_ratings_compute_results(
    teams, games, 3, ratings = r, margin_sd = 0, home_field = 0
  )
  wk3 <- games$week == 3
  rr <- setNames(r$rating, r$team)
  exp <- 1.0628 * (rr[games$home_team[wk3]] - rr[games$away_team[wk3]])
  expect_equal(out$games$result[wk3], as.integer(ifelse(exp < 0, floor(exp), ceiling(exp))))
})

test_that("teams missing from ratings rate 0 and home field applies off neutral sites", {
  m <- ratings_expected_margin(
    c("A", "A", "X"), c("X", "X", "B"), neutral = c(0, 1, 0),
    ratings = data.frame(team = c("A", "B"), rating = c(2, -1)),
    scale = 10, home_field = 3, margin_sd = 15
  )
  expect_equal(m$expected, c(23, 20, 13))
  expect_equal(m$margin_sd, rep(15, 3))
})

test_that("bucketed scale and margin_sd use the less-observed team's games", {
  ratings <- data.frame(team = c("A", "B", "C"), rating = c(1, 0, 0), games = c(2, 7, 30))
  scale <- c("0-3" = 1, "4-5" = 2, "6-7" = 3, "8-20" = 4)
  sd <- c("0-3" = 11, "4-5" = 12, "6-7" = 13, "8-20" = 14)
  m <- ratings_expected_margin(
    c("A", "B", "C", "Z"), c("C", "C", "B", "C"), neutral = rep(1, 4),
    ratings = ratings, scale = scale, home_field = 0, margin_sd = sd
  )
  # min(2, 30) = 2 -> 0-3; min(7, 30) = 7 -> 6-7; C-B again 6-7; Z unrated,
  # so C's 30 games alone, above every bucket -> the top one
  expect_equal(m$expected, c(1, 0, 0, 0))
  expect_equal(m$margin_sd, c(11, 13, 13, 14))

  # a count between buckets takes the lower one; below every bucket the bottom
  gap <- ratings_expected_margin(
    c("A", "A"), c("B", "B"), neutral = c(1, 1),
    ratings = data.frame(team = c("A", "B"), rating = c(1, 0), games = c(3.5, 9)),
    scale = c("0-3" = 1, "6-20" = 4), home_field = 0, margin_sd = c("2-3" = 11, "6-20" = 14)
  )
  expect_equal(gap$expected, c(1, 1))
  low <- ratings_expected_margin(
    "A", "B", 1, ratings = data.frame(team = c("A", "B"), rating = c(1, 0), games = c(1, 9)),
    scale = 1, home_field = 0, margin_sd = c("2-3" = 11, "6-20" = 14)
  )
  expect_equal(low$margin_sd, 11)

  # without a games column every game takes the top bucket
  m2 <- ratings_expected_margin(
    "A", "B", 1, ratings = ratings[c("team", "rating")],
    scale = scale, home_field = 0, margin_sd = sd
  )
  expect_equal(c(m2$expected, m2$margin_sd), c(4, 14))
})

test_that("defaults follow rating_type", {
  r <- data.frame(team = c("A", "B"), rating = c(0.1, 0))
  pts <- ratings_expected_margin("A", "B", 0, ratings = r, rating_type = "points")
  adj <- ratings_expected_margin("A", "B", 0, ratings = r, rating_type = "adj_epa")
  raw <- ratings_expected_margin("A", "B", 0, ratings = r, rating_type = "raw_epa")
  expect_equal(pts$expected, 1.0628 * 0.1 + 2.376)
  expect_equal(adj$expected, 49.6115 * 0.1 + 2.7625)
  expect_equal(c(adj$margin_sd, raw$margin_sd), c(17.0386, 17.3931))
})

test_that("bad ratings or buckets abort with a clear message", {
  games <- toy_week3()
  teams <- load_toy_teams()
  expect_error(
    cfbseedR_ratings_compute_results(teams, games, 3, ratings = data.frame(team = "A")),
    "columns"
  )
  expect_error(
    cfbseedR_ratings_compute_results(teams, games, 3, ratings = toy_ratings(), scale = c(a = 1, b = 2)),
    "lo-hi"
  )
  expect_error(
    cfbseedR_ratings_compute_results(teams, games, 3, ratings = toy_ratings(), rating_type = "elo"),
    "rating_type"
  )
  na_rating <- toy_ratings()
  na_rating$rating[1] <- NA
  expect_error(cfbseedR_ratings_compute_results(teams, games, 3, ratings = na_rating), "NA")
  chr_games <- transform(toy_ratings(), games = "8")
  expect_error(cfbseedR_ratings_compute_results(teams, games, 3, ratings = chr_games), "non-negative")
  expect_error(
    cfbseedR_ratings_compute_results(teams, games, 3, ratings = toy_ratings(), margin_sd = -1),
    "at least 0"
  )
})

test_that("a postseason tie is re-decided by one point", {
  teams <- data.frame(sim = 1, team = c("A", "B"), conference = "X")
  games <- data.frame(
    sim = 1, week = 1, game_type = "POST", home_team = "A", away_team = "B",
    result = NA_integer_, neutral = 1
  )
  r <- data.frame(team = c("A", "B"), rating = c(0, 0))
  set.seed(1)
  res <- replicate(20, cfbseedR_ratings_compute_results(
    teams, games, 1, ratings = r, margin_sd = 0
  )$games$result)
  expect_true(all(res %in% c(-1L, 1L)))
  expect_true(all(c(-1L, 1L) %in% res))
})

test_that("expected margins match the 2025 fixture (shared with sdv-py)", {
  dir <- test_path("fixtures", "cfb_2025_ratings")
  ratings <- read.csv(file.path(dir, "ratings.csv"))
  games <- read.csv(file.path(dir, "games.csv"))
  expected <- read.csv(file.path(dir, "expected.csv"))
  for (type in c("points", "adj_epa", "raw_epa")) {
    for (variant in c("full", "half", "quarter", "missing")) {
      want <- expected[expected$rating_type == type & expected$variant == variant, ]
      m <- ratings_expected_margin(
        games$home_team, games$away_team, games$neutral,
        ratings = ratings_fixture_variant(ratings, type, variant),
        rating_type = type
      )
      expect_identical(want$home_team, games$home_team)
      expect_equal(m$expected, want$expected, tolerance = 1e-9)
      expect_equal(m$margin_sd, want$margin_sd, tolerance = 1e-9)
    }
  }
})

test_that("cfb_simulations runs on the ratings generator", {
  games <- load_toy_games()
  games$result[games$week >= 3] <- NA
  teams <- load_toy_teams()
  set.seed(3)
  sim <- suppressMessages(cfb_simulations(
    games, teams, simulations = 4, chunks = 1, playoff_seeds = 4,
    compute_results = cfbseedR_ratings_compute_results,
    ratings = toy_ratings(teams), rating_type = "points"
  ))
  expect_s3_class(sim, "cfbseedR_simulation")
  expect_false(anyNA(sim$games$result))
})

test_that("edge inputs: no games to fill, no neutral column, duplicates and bad constants", {
  teams <- data.frame(sim = 1, team = c("A", "B"), conference = "X")
  games <- data.frame(
    sim = 1, week = 1, game_type = "REG", home_team = "A", away_team = "B",
    result = NA_integer_
  )
  r <- data.frame(team = c("A", "B"), rating = c(1, 0))
  # nothing unplayed in week 2: inputs come back as they are
  same <- cfbseedR_ratings_compute_results(teams, games, 2, ratings = r)
  expect_identical(same$games, games)
  # no neutral column: home field applies
  out <- cfbseedR_ratings_compute_results(teams, games, 1, ratings = r, scale = 1, home_field = 3, margin_sd = 0)
  expect_identical(out$games$result, 4L)
  expect_error(
    cfbseedR_ratings_compute_results(teams, games, 1, ratings = rbind(r, r)),
    "more than one row"
  )
  expect_error(
    cfbseedR_ratings_compute_results(teams, games, 1, ratings = r, home_field = c(1, 2)),
    "single number"
  )
  expect_error(
    cfbseedR_ratings_compute_results(teams, games, 1, ratings = r, scale = "a"),
    "named numeric vector"
  )
})
