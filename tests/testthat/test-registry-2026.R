# Season-scoped registry epochs, the ACC-2026 candidate-pool rule, Sun Belt
# division support, and the cfp_ranked_final_week rung.

reg_game <- function(season, week, home, away, result) {
  data.frame(
    season = season, week = week, game_type = "REG",
    home_team = home, away_team = away, result = result
  )
}

# A 2-0, B 2-0 (never met), C 2-2, D 1-2, E 0-3. A holds the better pooled
# opponents' conference win pct; B holds the better analytics rating.
acc_epoch_games <- function(season) {
  rbind(
    reg_game(season, 1, "A", "C", 7),
    reg_game(season, 2, "A", "D", 7),
    reg_game(season, 1, "B", "C", 7),
    reg_game(season, 2, "B", "E", 7),
    reg_game(season, 3, "C", "D", 7),
    reg_game(season, 4, "C", "E", 7),
    reg_game(season, 3, "D", "E", 7)
  )
}

test_that("ACC registry epochs: 2025 uses the old cascade, 2026 the new one", {
  testthat::skip_on_cran()
  teams <- data.frame(team = c("A", "B", "C", "D", "E"), conference = "ACC")
  # C is rated too: under the 2026 pool rule C (2 wins, alternate game
  # count) joins the {A, B} tie, and an unrated pool member would knock
  # the analytics rung out.
  ratings <- data.frame(team = c("A", "B", "C"), rating = c(1, 2, 0.5))

  st25 <- cfb_standings(acc_epoch_games(2025), teams, verbosity = "NONE",
    tiebreaker_data = list(analytics_ratings = ratings)
  )
  st26 <- cfb_standings(acc_epoch_games(2026), teams, verbosity = "NONE",
    tiebreaker_data = list(analytics_ratings = ratings)
  )
  rank25 <- setNames(st25$conf_rank, st25$team)
  rank26 <- setNames(st26$conf_rank, st26$team)
  # 2025 cascade reaches pooled opponents' win pct: A over B.
  expect_equal(unname(rank25[["A"]]), 1L)
  expect_equal(unname(rank25[["B"]]), 2L)
  # 2026 cascade goes h2h -> analytics: B over A.
  expect_equal(unname(rank26[["B"]]), 1L)
  expect_equal(unname(rank26[["A"]]), 2L)
})

test_that("ACC 2026 pool rule admits alternate-game-count teams by wins or losses", {
  testthat::skip_on_cran()
  teams <- data.frame(
    team = c("L", "X", "Y", "M", "F1", "F2", "F3", "F4"),
    conference = "ACC"
  )
  games <- rbind(
    # L 3-1 (leader, .750)
    reg_game(2026, 1, "L", "F1", 7),
    reg_game(2026, 2, "L", "F2", 7),
    reg_game(2026, 3, "L", "F3", 7),
    reg_game(2026, 4, "M", "L", 7),
    # Y 2-1 (.667) - matches L's loss count
    reg_game(2026, 1, "Y", "F1", 7),
    reg_game(2026, 2, "Y", "F2", 7),
    reg_game(2026, 3, "M", "Y", 7),
    # X 3-2 (.600) - matches L's win count
    reg_game(2026, 1, "X", "F1", 7),
    reg_game(2026, 2, "X", "F2", 7),
    reg_game(2026, 3, "X", "F3", 7),
    reg_game(2026, 4, "F4", "X", 7),
    reg_game(2026, 5, "F4", "X", 7),
    # M 2-3 (.400), F4 2-2 (.500) - match neither wins nor losses
    reg_game(2026, 5, "F1", "M", 7),
    reg_game(2026, 6, "F2", "M", 7),
    reg_game(2026, 7, "F3", "M", 7),
    reg_game(2026, 6, "F1", "F4", 7),
    reg_game(2026, 7, "F2", "F4", 7)
  )
  ratings <- data.frame(team = c("L", "X", "Y"), rating = c(100, 90, 80))
  st <- cfb_standings(games, teams, verbosity = "NONE",
    tiebreaker_data = list(analytics_ratings = ratings)
  )
  ranks <- setNames(st$conf_rank, st$team)
  pcts <- setNames(round(st$conf_pct, 3), st$team)
  expect_equal(unname(pcts[c("L", "Y", "X")]), c(0.75, 0.667, 0.6))
  # X and Y join L's tier via the pool rule; analytics orders L > X > Y,
  # so X takes the second CCG berth over the higher-win-pct Y.
  expect_equal(unname(ranks[["L"]]), 1L)
  expect_equal(unname(ranks[["X"]]), 2L)
  expect_equal(unname(ranks[["Y"]]), 3L)
})

test_that("Sun Belt divisions send the two division champions to ranks 1-2", {
  testthat::skip_on_cran()
  teams <- data.frame(
    team = c("E1", "E2", "W1", "W2"),
    conference = "Sun Belt",
    conf_division = c("East", "East", "West", "West")
  )
  games <- rbind(
    reg_game(2026, 1, "E1", "E2", 7),
    reg_game(2026, 1, "W1", "W2", 7),
    reg_game(2026, 2, "E1", "W1", 7),
    reg_game(2026, 2, "E2", "W2", 7)
  )
  st <- cfb_standings(games, teams, verbosity = "NONE")
  ranks <- setNames(st$conf_rank, st$team)
  # E1 2-0; E2 and W1 both 1-1; W2 0-2. Without divisions E2 could take
  # the second spot - with divisions the West champion W1 must.
  expect_equal(unname(ranks[["E1"]]), 1L)
  expect_equal(unname(ranks[["W1"]]), 2L)
  expect_equal(unname(ranks[["E2"]]), 3L)
})

test_that("cfp_ranked_final_week advances a ranked winner and falls through on a loss", {
  testthat::skip_on_cran()
  teams <- data.frame(team = c("A", "B", "C", "D"), conference = "American Athletic")
  base <- rbind(
    reg_game(2026, 1, "A", "C", 7),
    reg_game(2026, 1, "B", "D", 7),
    reg_game(2026, 2, "A", "D", 7),
    reg_game(2026, 2, "B", "C", 7)
  )
  cfp <- data.frame(team = "A", rank = 20)
  ratings <- data.frame(team = c("A", "B"), rating = c(1, 2))

  # A and B both 2-0, no h2h, equal vs common opponents {C, D}. A is CFP
  # ranked and won its final game -> A advances.
  st_win <- cfb_standings(base, teams, verbosity = "NONE",
    tiebreaker_data = list(cfp_rankings = cfp, analytics_ratings = ratings)
  )
  expect_equal(st_win$conf_rank[st_win$team == "A"], 1L)

  # Week-3 split where the ranked team LOSES its final game: the clause
  # falls through and the composite (which favors B) decides.
  lost_final <- rbind(
    base,
    reg_game(2026, 3, "C", "A", 7),
    reg_game(2026, 3, "D", "B", 7)
  )
  st_loss <- cfb_standings(lost_final, teams, verbosity = "NONE",
    tiebreaker_data = list(cfp_rankings = cfp, analytics_ratings = ratings)
  )
  expect_equal(st_loss$conf_rank[st_loss$team == "B"], 1L)
  expect_true(any(grepl(
    "cfp_ranked_final_week fell through",
    attr(st_loss, "tiebreak_notes")
  )))
})
