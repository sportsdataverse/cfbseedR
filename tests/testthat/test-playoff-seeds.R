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

test_that("2025 policy guarantees the 5 best-ranked conference champions", {
  st <- synthetic_standings()
  rankings <- data.frame(team = sprintf("T%02d", 1:16), rank = 1:16)
  seeded <- cfb_playoff_seeds(st, rankings = rankings, playoff_seeds = 12,
                              autobid = "2025")
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
  seeded <- cfb_playoff_seeds(st, rankings = rankings, playoff_seeds = 12,
                              autobid = "2025")
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

test_that("2026 policy: P4 champs regardless of rank, best G6 team, ND clause", {
  # 16 teams: P4 champ ranked dead last still gets in; the best-ranked
  # Group-of-6 TEAM gets in without being champion; Notre Dame gets in
  # when ranked inside the field.
  st <- tibble::tibble(
    sim = 1L,
    team = c(sprintf("T%02d", 1:13), "SecChamp", "MwTeam", "Notre Dame"),
    conference = c(
      rep("Big Ten", 6), rep("ACC", 4), rep("Big 12", 3),
      "SEC", "Mountain West", "FBS Independents"
    ),
    conf_champ = c(
      TRUE, rep(FALSE, 5), # T01 Big Ten champ
      TRUE, rep(FALSE, 3), # T07 ACC champ
      TRUE, FALSE, FALSE,  # T11 Big 12 champ
      TRUE,                # SecChamp SEC champ
      FALSE,               # MwTeam: NOT its conference champion
      FALSE
    ),
    win_pct = seq(1, 0.25, length.out = 16),
    sov = 0, sos = 0, pd = 0
  )
  # SecChamp unranked (P4 champ must still get in); MwTeam ranked 14;
  # Notre Dame ranked 12.
  rankings <- data.frame(
    team = c(sprintf("T%02d", 1:11), "Notre Dame", "T12", "MwTeam", "T13"),
    rank = 1:15
  )
  seeded <- cfb_playoff_seeds(st, rankings = rankings, playoff_seeds = 12)
  seeds <- setNames(seeded$seed, seeded$team)

  expect_false(is.na(seeds[["SecChamp"]])) # unranked P4 champ is in
  expect_false(is.na(seeds[["MwTeam"]]))   # best G6 team, no title needed
  expect_false(is.na(seeds[["Notre Dame"]])) # ND ranked 12 -> in
  expect_equal(sum(!is.na(seeded$seed)), 12L)
  # Straight seeding: ranked field members keep committee order
  expect_equal(seeds[["T01"]], 1L)
  expect_equal(seeds[["Notre Dame"]], 10L) # ranks 1-9 ahead of it in field
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

test_that("cfb_standings(playoff_seeds =) passes autobid through and keys it by season", {
  # Rankings that push both toy champions (A1, B1) outside a 4-team field:
  # the 2025 rule (5 best champions guaranteed) seeds them, the 2026 rule
  # (P4 champs + best G6 team; Alpha/Beta are neither) does not.
  rankings <- data.frame(
    team = c("I1", "A3", "A2", "B2", "B3", "A1", "B1", "A4", "B4"),
    rank = 1:9
  )
  seeds_of <- function(x) setNames(x$seed, x$team)[sort(x$team)]
  season_games <- function(season) {
    g <- load_toy_games()
    g$sim <- NULL
    g$season <- season
    g
  }
  base <- cfb_standings(season_games(2025), load_toy_teams(), verbosity = "NONE")
  rule <- function(autobid) {
    seeds_of(cfb_playoff_seeds(base, rankings = rankings, playoff_seeds = 4,
                               autobid = autobid))
  }
  expect_false(identical(rule("2025"), rule("2026"))) # the fixture separates them
  seeded <- function(games, ...) {
    seeds_of(cfb_standings(games, load_toy_teams(), playoff_seeds = 4,
                           rankings = rankings, verbosity = "NONE", ...))
  }

  # An explicit autobid reaches cfb_playoff_seeds() (it used to be swallowed
  # by `...`, so every call seeded under the 2026 rule).
  expect_identical(seeded(season_games(2025), autobid = "2025"), rule("2025"))
  expect_identical(seeded(season_games(2025), autobid = "2026"), rule("2026"))
  # Unset, it follows the season: pre-2026 seasons get the 2025 rule, 2026+
  # and plain `sim` ids (the current rules) get the 2026 rule.
  expect_identical(seeded(season_games(2025)), rule("2025"))
  expect_identical(seeded(season_games(2026)), rule("2026"))
  expect_identical(seeded(load_toy_games()), rule("2026"))
  expect_error(seeded(season_games(2025), autobid = "2027"), "autobid")
})
