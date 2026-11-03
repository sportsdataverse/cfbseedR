# Expected values on the toy fixture are derived by hand from the shared
# cross-validation spec (Alpha 3-way 2-1 conference tie resolved by
# conference point differential at depth POINTS; Beta clean B1>B2>B3>B4;
# I1 independent).

test_that("toy standings records and ranks are correct at depth POINTS", {
  st <- toy_standings(tiebreaker_depth = "POINTS")

  expect_s3_class(st, "tbl_df")
  expect_equal(nrow(st), 9L)

  row <- function(team) st[st$team == team, ]

  # Overall records include the CONF_CHAMP game
  expect_equal(row("A1")$wins, 3)
  expect_equal(row("A1")$losses, 2)
  expect_equal(row("A1")$win_pct, 0.6)
  expect_equal(row("A1")$pd, 25)
  expect_equal(row("A2")$wins, 2)
  expect_equal(row("A2")$losses, 2)
  expect_equal(row("A3")$win_pct, 2 / 3)
  expect_equal(row("B1")$wins, 5)
  expect_equal(row("B1")$win_pct, 1)
  expect_equal(row("I1")$wins, 2)
  expect_equal(row("I1")$win_pct, 1)

  # Conference records exclude the CONF_CHAMP game
  for (t in c("A1", "A2", "A3")) {
    expect_equal(row(t)$conf_wins, 2)
    expect_equal(row(t)$conf_losses, 1)
    expect_equal(row(t)$conf_pct, 2 / 3)
  }
  expect_equal(row("B1")$conf_wins, 3)
  expect_equal(row("B1")$conf_losses, 0)
  expect_equal(row("I1")$conf_games, 0)
  expect_equal(row("I1")$conf_pct, 0)

  # Conference-scoped SOV/SOS (tied for the Alpha trio by construction)
  for (t in c("A1", "A2", "A3")) {
    expect_equal(row(t)$sov, 1 / 3)
    expect_equal(row(t)$sos, 4 / 9)
  }
  expect_equal(row("B2")$sov, 1 / 6)
  expect_equal(row("B3")$sos, 5 / 9)
  expect_equal(row("I1")$sov, 0)
  expect_equal(row("I1")$sos, 0)

  # Conference point differential (the POINTS tiebreaker)
  expect_equal(row("A1")$conf_pd, 25)
  expect_equal(row("A2")$conf_pd, 10)
  expect_equal(row("A3")$conf_pd, 3)

  # Alpha 3-way tie resolves A1 > A2 > A3 by conference point differential
  expect_equal(row("A1")$conf_rank, 1L)
  expect_equal(row("A2")$conf_rank, 2L)
  expect_equal(row("A3")$conf_rank, 3L)
  expect_equal(row("A4")$conf_rank, 4L)

  # Beta clean
  expect_equal(row("B1")$conf_rank, 1L)
  expect_equal(row("B2")$conf_rank, 2L)
  expect_equal(row("B3")$conf_rank, 3L)
  expect_equal(row("B4")$conf_rank, 4L)

  # Independent: no conference rank
  expect_true(is.na(row("I1")$conf_rank))

  # Champions come from the week-15 CONF_CHAMP games
  expect_true(row("A1")$conf_champ)
  expect_true(row("B1")$conf_champ)
  expect_equal(sum(st$conf_champ), 2L)
})

test_that("a conference without a CONF_CHAMP game crowns the conf_rank 1 team", {
  games <- load_toy_games()
  games <- games[games$game_type != "CONF_CHAMP", ]
  st <- cfb_standings(games, load_toy_teams(), tiebreaker_depth = "POINTS",
                      verbosity = "NONE")
  expect_true(st$conf_champ[st$team == "B1"])
  # Alpha: A1 still rank 1 (same conference tiebreak, CONF_CHAMP was not
  # part of the conference record anyway)
  expect_true(st$conf_champ[st$team == "A1"])
  expect_equal(sum(st$conf_champ), 2L)
})

test_that("season id column is accepted and returned as season", {
  games <- load_toy_games()
  names(games)[names(games) == "sim"] <- "season"
  st <- cfb_standings(games, load_toy_teams(), tiebreaker_depth = "POINTS",
                      verbosity = "NONE")
  expect_true("season" %in% names(st))
  expect_false("sim" %in% names(st))
  expect_equal(unique(st$season), 2024)
})

test_that("standings input validation errors are informative", {
  games <- load_toy_games()
  teams <- load_toy_teams()

  bad <- games
  bad$result[1] <- NA
  expect_error(
    cfb_standings(bad, teams, verbosity = "NONE"),
    regexp = "NA"
  )

  expect_error(
    cfb_standings(games[, setdiff(names(games), "result")], teams,
                  verbosity = "NONE"),
    regexp = "identifiers"
  )
})

test_that("a team missing from `teams` is excluded, not an error", {
  # `teams` need not exhaustively list every team in `games` - an unlisted
  # opponent (e.g. an FCS-or-lower team, or here I1 with I1 removed) simply
  # gets no standings row of its own, while its games still count for its
  # opponents' own records (A4/B4 still show their games against I1). This
  # is the same "unknown opponent" convention the Big 12 `total_wins` FCS
  # cap relies on (see the `cfb_toy_tiebreakers` parity fixture).
  games <- load_toy_games()
  teams <- load_toy_teams()
  st <- cfb_standings(games, teams[teams$team != "I1", ], verbosity = "NONE")
  expect_false("I1" %in% st$team)
  expect_equal(sum(st$team == "A4"), 1L)
})
