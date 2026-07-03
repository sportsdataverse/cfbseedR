gamma_games <- function() {
  # P: W Q, W S, L R (2-1); Q: L P, W R, W S (2-1)  -> pair broken by h2h
  # R: W P, L Q, L S (1-2); S: L P, L Q, W R (1-2)  -> pair broken by h2h
  data.frame(
    sim = 1, week = 1:6, game_type = "REG",
    home_team = c("P", "S", "R", "Q", "Q", "S"),
    away_team = c("Q", "P", "P", "R", "S", "R"),
    result = c(7, -7, 3, 3, 10, 1),
    neutral = 0
  )
}

gamma_teams <- function() {
  data.frame(team = c("P", "Q", "R", "S"), conference = "Gamma")
}

test_that("pairwise ties resolve via head-to-head at depth PRE-SOV", {
  st <- cfb_standings(gamma_games(), gamma_teams(),
                      tiebreaker_depth = "PRE-SOV", verbosity = "NONE")
  ranks <- setNames(st$conf_rank, st$team)
  expect_equal(ranks[["P"]], 1L) # beat Q head-to-head
  expect_equal(ranks[["Q"]], 2L)
  expect_equal(ranks[["S"]], 3L) # beat R head-to-head
  expect_equal(ranks[["R"]], 4L)
})

test_that("ties without head-to-head resolve via common opponents", {
  # E1: W E3, L E4, W E5 (2-1); E2: W E3, L E3, W E4 (2-1). No E1-E2 game.
  # Common conference opponents {E3, E4}: E1 is 1-1 (.5), E2 is 2-1 (.667).
  games <- data.frame(
    sim = 1, week = 1:6, game_type = "REG",
    home_team = c("E1", "E4", "E1", "E2", "E3", "E2"),
    away_team = c("E3", "E1", "E5", "E3", "E2", "E4"),
    result = c(7, 3, 4, 6, 3, 10),
    neutral = 0
  )
  teams <- data.frame(team = paste0("E", 1:5), conference = "Delta")
  st <- cfb_standings(games, teams, tiebreaker_depth = "PRE-SOV",
                      verbosity = "NONE")
  ranks <- setNames(st$conf_rank, st$team)
  expect_equal(ranks[["E2"]], 1L)
  expect_equal(ranks[["E1"]], 2L)
  expect_equal(ranks[["E4"]], 3L)
  expect_equal(ranks[["E3"]], 4L)
  expect_equal(ranks[["E5"]], 5L)
})

test_that("tiebreaker_depth RANDOM breaks ties by coin flip, deterministically under a seed", {
  run <- function() {
    set.seed(123)
    st <- toy_standings(tiebreaker_depth = "RANDOM")
    setNames(st$conf_rank, st$team)
  }
  r1 <- run()
  r2 <- run()
  expect_identical(r1, r2)
  # The Alpha trio gets ranks 1-3 in some order, A4 is alone at rank 4
  expect_setequal(unname(r1[c("A1", "A2", "A3")]), 1:3)
  expect_equal(r1[["A4"]], 4L)
})

test_that("depth gating stops the cascade before deeper tiebreakers", {
  # At depth SOS the Alpha trio is still tied after h2h, common opponents,
  # SOV, and SOS (all tied by construction) -> coin flip, so with different
  # seeds the winner can differ. At POINTS it is always A1.
  set.seed(1)
  st_points <- toy_standings(tiebreaker_depth = "POINTS")
  expect_equal(st_points$conf_rank[st_points$team == "A1"], 1L)

  ranks_at_sos <- vapply(1:20, function(s) {
    set.seed(s)
    st <- toy_standings(tiebreaker_depth = "SOS")
    st$conf_rank[st$team == "A1"]
  }, integer(1))
  # Coin flip: A1 must not always win the 3-way tie across 20 seeds
  expect_gt(length(unique(ranks_at_sos)), 1L)
})

test_that("independents never receive a conference rank or championship", {
  st <- toy_standings(tiebreaker_depth = "POINTS")
  expect_true(is.na(st$conf_rank[st$team == "I1"]))
  expect_false(st$conf_champ[st$team == "I1"])
})

# Cross-language parity: the official-registry SEC/Big 12 cascades run on
# the shared oracle fixture and must match sdv-py's `cfb_standings.py`
# output exactly (see tests/testthat/fixtures/cfb_toy_tiebreakers/README.md).
# If this diverges, the bug is in the R engine - never edit the expected CSV.
test_that("official registry cascades match the sdv-py cross-language oracle", {
  games <- load_registry_games()
  teams <- load_registry_teams()
  expected <- load_registry_expected()

  st <- cfb_standings(games, teams, tiebreaker_depth = "POINTS", verbosity = "NONE")
  st <- st[order(st$sim, st$conference, st$conf_rank), ]
  expected <- expected[order(expected$sim, expected$conference, expected$conf_rank), ]

  expect_identical(st$team, expected$team)
  expect_identical(as.integer(st$conf_rank), as.integer(expected$conf_rank))
  expect_identical(st$conf_champ, as.logical(expected$conf_champ))
})

test_that("registry rungs record skip notes when optional inputs are absent", {
  teams <- load_registry_teams()
  teams$division <- NULL
  games <- load_registry_games()
  games$home_points <- NULL
  games$away_points <- NULL

  st <- cfb_standings(games, teams, tiebreaker_depth = "POINTS", verbosity = "NONE")
  notes <- attr(st, "tiebreak_notes")

  expect_true(any(grepl("capped_scoring_margin skipped", notes)))
  expect_true(any(grepl("total_wins FCS cap not applied", notes)))
  expect_true(any(grepl("analytics_rating skipped", notes)))
})
