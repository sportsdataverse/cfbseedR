load_toy_games <- function() {
  read.csv(test_path("fixtures", "toy_games.csv"))
}

load_toy_teams <- function() {
  read.csv(test_path("fixtures", "toy_teams.csv"))
}

toy_standings <- function(...) {
  cfb_standings(load_toy_games(), load_toy_teams(), verbosity = "NONE", ...)
}

# Cross-language parity fixture (shared oracle with sdv-py's
# `cfb_standings.py` `CONFERENCE_TIEBREAKERS` registry) - see
# tests/testthat/fixtures/cfb_toy_tiebreakers/README.md.
load_registry_games <- function() {
  read.csv(test_path("fixtures", "cfb_toy_tiebreakers", "toy_games.csv"))
}

load_registry_teams <- function() {
  read.csv(test_path("fixtures", "cfb_toy_tiebreakers", "toy_teams.csv"))
}

load_registry_expected <- function() {
  read.csv(test_path("fixtures", "cfb_toy_tiebreakers", "expected_standings.csv"))
}

# Rating table for one rating column of fixtures/cfb_2025_ratings/ratings.csv
# under one variant of expected.csv (see that fixture's README and capture.R):
# "full" = games as recorded, "half" / "quarter" = games %/% 2 / %/% 4,
# "missing" = Georgia Southern dropped (rates 0, no count) and Navy's games NA.
ratings_fixture_variant <- function(ratings, type, variant) {
  out <- data.frame(team = ratings$team, rating = ratings[[type]], games = ratings$games)
  if (variant == "half") out$games <- out$games %/% 2
  if (variant == "quarter") out$games <- out$games %/% 4
  if (variant == "missing") {
    out <- out[out$team != "Georgia Southern", ]
    out$games[out$team == "Navy"] <- NA
  }
  out
}
