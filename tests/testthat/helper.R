load_toy_games <- function() {
  read.csv(test_path("fixtures", "toy_games.csv"))
}

load_toy_teams <- function() {
  read.csv(test_path("fixtures", "toy_teams.csv"))
}

toy_standings <- function(...) {
  cfb_standings(load_toy_games(), load_toy_teams(), verbosity = "NONE", ...)
}
