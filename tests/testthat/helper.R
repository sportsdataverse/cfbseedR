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
