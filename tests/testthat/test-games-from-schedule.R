test_that("cfb_games_from_schedule maps the cfbfastR schedule shape", {
  schedule <- data.frame(
    season = 2024,
    week = c(1, 1, 15, 16),
    season_type = c("regular", "regular", "regular", "postseason"),
    home_team = c("A1", "B1", "A1", "A1"),
    away_team = c("A2", "B2", "A2", "B1"),
    home_points = c(21, 24, 17, NA),
    away_points = c(14, 20, 14, NA),
    neutral_site = c(FALSE, FALSE, TRUE, TRUE),
    notes = c(NA, NA, "Alpha Championship Game", NA)
  )
  games <- cfb_games_from_schedule(schedule)

  expect_named(
    games,
    c("season", "week", "game_type", "home_team", "away_team", "result", "neutral")
  )
  expect_equal(games$season, rep(2024, 4))
  expect_equal(games$game_type, c("REG", "REG", "CONF_CHAMP", "POST"))
  expect_equal(games$result, c(7, 4, 3, NA))
  expect_equal(games$neutral, c(0L, 0L, 1L, 1L))
})

test_that("cfb_games_from_schedule works without optional columns", {
  schedule <- data.frame(
    season = 2024, week = 1, season_type = "regular",
    home_team = "A1", away_team = "A2"
  )
  games <- cfb_games_from_schedule(schedule)
  expect_true(is.na(games$result))
  expect_equal(games$game_type, "REG")
  expect_equal(games$neutral, 0L)
})

test_that("cfb_games_from_schedule errors on missing required columns", {
  expect_error(
    cfb_games_from_schedule(data.frame(season = 2024, week = 1)),
    regexp = "missing"
  )
})

test_that("mapped schedule feeds cfb_standings end to end", {
  schedule <- data.frame(
    season = 2024,
    week = c(1, 2, 3),
    season_type = "regular",
    home_team = c("X1", "X2", "X1"),
    away_team = c("X2", "X3", "X3"),
    home_points = c(21, 17, 28),
    away_points = c(14, 20, 10),
    neutral_site = FALSE,
    notes = NA_character_
  )
  games <- cfb_games_from_schedule(schedule)
  teams <- data.frame(team = c("X1", "X2", "X3"), conference = "Omega")
  st <- cfb_standings(games, teams, verbosity = "NONE")
  expect_equal(st$conf_rank[st$team == "X1"], 1L)
  expect_true("season" %in% names(st))
})
