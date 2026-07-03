synthetic_standings <- function() {
  # 16 teams, 5 conferences; champs are T01, T03, T08, T13, T16
  tibble::tibble(
    sim = 1L,
    team = sprintf("T%02d", 1:16),
    conference = rep(c("C1", "C2", "C3", "C4", "C5"), length.out = 16),
    conf_champ = sprintf("T%02d", 1:16) %in% c("T01", "T03", "T08", "T13", "T16"),
    win_pct = seq(1, 0.25, length.out = 16),
    sov = 0, sos = 0, pd = 0
  )
}

test_that("straight seeding guarantees the 5 best-ranked conference champions", {
  st <- synthetic_standings()
  rankings <- data.frame(team = sprintf("T%02d", 1:16), rank = 1:16)
  seeded <- cfb_playoff_seeds(st, rankings = rankings, playoff_seeds = 12)
  seeds <- setNames(seeded$seed, seeded$team)

  # Field: ranks 1-10 (at-large + champs) plus champs ranked 13 and 16,
  # which bump the rank 11 and 12 at-larges
  expect_true(is.na(seeds[["T11"]]))
  expect_true(is.na(seeds[["T12"]]))
  # Straight seeding: seeds strictly in ranking order within the field
  expect_equal(unname(seeds[sprintf("T%02d", 1:10)]), 1:10)
  expect_equal(seeds[["T13"]], 11L)  # champ outside top 12, seeded last-but-one
  expect_equal(seeds[["T16"]], 12L)  # lowest-ranked guaranteed champ
  expect_equal(sum(!is.na(seeded$seed)), 12L)
})

test_that("unranked teams sort behind ranked teams", {
  st <- synthetic_standings()
  rankings <- data.frame(team = sprintf("T%02d", 1:10), rank = 1:10) # 11-16 unranked
  seeded <- cfb_playoff_seeds(st, rankings = rankings, playoff_seeds = 12)
  seeds <- setNames(seeded$seed, seeded$team)
  expect_equal(unname(seeds[sprintf("T%02d", 1:10)]), 1:10)
  # Unranked champs T13/T16 still guaranteed; unranked order falls back to
  # win_pct, which decreases with team number -> T13 before T16
  expect_equal(seeds[["T13"]], 11L)
  expect_equal(seeds[["T16"]], 12L)
  expect_true(is.na(seeds[["T11"]]))
})

test_that("rankings = NULL falls back to the standings ordering", {
  st <- toy_standings(tiebreaker_depth = "POINTS")
  seeded <- cfb_playoff_seeds(st, rankings = NULL, playoff_seeds = 4)
  seeds <- setNames(seeded$seed, seeded$team)
  # Champs A1/B1 guaranteed; fallback order = win_pct, sov, sos, pd:
  # B1 (1.0), I1 (1.0, lower sov), A3 (.667), A1 (.6)
  expect_equal(seeds[["B1"]], 1L)
  expect_equal(seeds[["I1"]], 2L)
  expect_equal(seeds[["A3"]], 3L)
  expect_equal(seeds[["A1"]], 4L)
  expect_equal(sum(!is.na(seeded$seed)), 4L)
})

test_that("cfb_playoff_seeds validates its inputs", {
  st <- synthetic_standings()
  expect_error(
    cfb_playoff_seeds(st, playoff_seeds = 20),
    regexp = "exceeds"
  )
  expect_error(
    cfb_playoff_seeds(st, rankings = data.frame(team = "T01"), playoff_seeds = 4),
    regexp = "rank"
  )
  expect_error(
    cfb_playoff_seeds(st[, setdiff(names(st), "conf_champ")], playoff_seeds = 4),
    regexp = "conf_champ"
  )
})
