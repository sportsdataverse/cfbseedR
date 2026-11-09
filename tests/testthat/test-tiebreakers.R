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

# `.pick_winner()` takes the doubled conference-REG game frame (one row per
# team per game: team/opp/outcome). `pairs` are c(winner, loser).
tie_cg <- function(...) {
  do.call(rbind, lapply(list(...), function(p) {
    data.frame(team = c(p[[1]], p[[2]]), opp = c(p[[2]], p[[1]]),
               outcome = c(1, 0))
  }))
}

tie_rungs <- list(
  list(kind = "h2h"),
  list(kind = "record_vs_common"),
  list(kind = "sov")
)

tie_pick <- function(tied, cg, sov) {
  metrics <- lapply(setNames(nm = c("A", "B", "C", "D")),
                    function(tm) list(sov = sov[[tm]]))
  .pick_winner(tied, metrics, cg, tie_rungs, depth = 3L,
               ctx = list(conf_name = "Delta", conf_pct_by_team = c()),
               notes_env = new.env(parent = emptyenv()))
}

test_that("an elimination restarts the cascade instead of descending it", {
  # A, B, C are level head-to-head (each 1-1: A beat B, B beat C, C beat A),
  # and against the common opponent D, A lost while B and C won - so common
  # opponents cut the tie to {B, C}. The published procedure repeats from
  # rung 1 on the survivors, which is the two-team rule: B beat C, so B.
  # Descending the same rung list instead reads SOV next, where C is better.
  cg <- tie_cg(c("A", "B"), c("B", "C"), c("C", "A"),
               c("B", "D"), c("C", "D"), c("D", "A"))
  expect_identical(tie_pick(c("A", "B", "C"), cg,
                            list(A = 0.5, B = 0.5, C = 0.9, D = 0.1)), "B")
})

test_that("a 4-team tie cut to three re-tests the survivors from rung 1", {
  # A, B, C, D are tied; head-to-head seeds nobody yet (A beat B and C but
  # lost to D, and B, C, D never played each other, so no team beat
  # everything it played). Common opponent E eliminates D (A, B, C beat E,
  # D lost), leaving {A, B, C} - and on THOSE three A's wins over B and C
  # are a "defeated all" head-to-head, so the restarted rung 1 seeds A.
  # Descending instead reaches SOV, where C is better.
  cg <- tie_cg(c("A", "B"), c("A", "C"), c("D", "A"),
               c("A", "E"), c("B", "E"), c("C", "E"), c("E", "D"))
  expect_identical(tie_pick(c("A", "B", "C", "D"), cg,
                            list(A = 0.5, B = 0.5, C = 0.9, D = 0.5)), "A")
})

test_that("cfb_standings() restarts an eliminated generic tie at the 2-team rule", {
  # Unregistered conference (generic cascade). F is clear at 4-1; A, B and C
  # are 3-2 and level head-to-head (A beat B, B beat C, C beat A). Records vs
  # the common opponent H (the only team all three played) put A out (A lost
  # to H, B and C beat it), leaving {B, C}: the two-team rule gives it to B,
  # which beat C. Descending would read SOV (level) and then SOS, where C is
  # stronger, so the bug ranks C first.
  games <- data.frame(
    sim = 1, week = seq_len(20), game_type = "REG",
    home_team = c("A", "C", "A", "A", "H", "B", "B", "E", "B", "C",
                  "F", "C", "D", "F", "D", "H", "F", "E", "F", "G"),
    away_team = c("B", "A", "F", "G", "A", "C", "D", "B", "H", "E",
                  "C", "H", "E", "D", "G", "D", "E", "G", "G", "H"),
    result = rep(7, 20), neutral = 0
  )
  teams <- data.frame(team = c("A", "B", "C", "D", "E", "F", "G", "H"),
                      conference = "Zeta")
  st <- cfb_standings(games, teams, tiebreaker_depth = "POINTS",
                      verbosity = "NONE")
  ranks <- setNames(st$conf_rank, st$team)

  expect_equal(ranks[["F"]], 1L) # 4-1 sits alone at the top
  expect_equal(ranks[["B"]], 2L) # beat C head-to-head
  expect_equal(ranks[["C"]], 3L)
  expect_equal(ranks[["A"]], 4L)
})

# Real 2025 ACC + SEC conference games (fixtures/cfb_2025_title_ties/README.md):
# the order-of-finish descent compares only opponents every tied team played.
title_ties_top2 <- function(conference) {
  games <- read.csv(test_path("fixtures", "cfb_2025_title_ties", "games.csv"))
  teams <- read.csv(test_path("fixtures", "cfb_2025_title_ties", "teams.csv"))
  st <- cfb_standings(games, teams, verbosity = "NONE")
  st <- st[st$conference == conference, ]
  c(st$team[st$conf_rank == 1L], st$team[st$conf_rank == 2L])
}

test_that("2025 ACC five-way tie at 6-2 sends Duke, as the ACC ruled", {
  # Syracuse is the only opponent all of Duke, Georgia Tech, Miami, Pitt and
  # SMU played, and all five beat it, so the descent cannot separate them;
  # opponents' conference win % does.
  expect_identical(title_ties_top2("ACC"), c("Virginia", "Duke"))
})

test_that("2025 SEC four-way tie at 7-1 seeds Alabama, then Georgia", {
  expect_identical(title_ties_top2("SEC"), c("Alabama", "Georgia"))
})

test_that("2026 Big 12 descent skips opponents not every tied team played", {
  # Real 2026 Big 12 games through week 10 (fixtures/cfb_2026_big12_partial):
  # the loose reading seeds TCU first of Cincinnati / Iowa State / TCU / West
  # Virginia and Kansas first of Colorado / Kansas / Kansas State on an
  # opponent tier not all tied teams played; common-only leaves both ties
  # level through the descent and opponents' conference win % orders them.
  games <- read.csv(test_path("fixtures", "cfb_2026_big12_partial", "games.csv"))
  teams <- read.csv(test_path("fixtures", "cfb_2026_big12_partial", "teams.csv"))
  st <- cfb_standings(games, teams, verbosity = "NONE")
  ranks <- setNames(st$conf_rank, st$team)
  expect_equal(unname(ranks[c("Iowa State", "West Virginia", "Cincinnati", "TCU")]), 10:13)
  expect_equal(unname(ranks[c("Colorado", "Kansas State", "Kansas")]), 14:16)
})
