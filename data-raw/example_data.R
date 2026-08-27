# Build the exported example datasets from the bundled toy fixtures.
#
# Mirrors nflseedR's `sims_games_example` / `sims_teams_example`: a small,
# self-contained season that every example and `simulations_verify_fct()`
# can lean on without a `read.csv(system.file(...))` dance.
#
# Run after changing inst/extdata: Rscript data-raw/example_data.R

cfb_games_example <- utils::read.csv(
  system.file("extdata", "toy_games.csv", package = "cfbseedR"),
  stringsAsFactors = FALSE
)
cfb_teams_example <- utils::read.csv(
  system.file("extdata", "toy_teams.csv", package = "cfbseedR"),
  stringsAsFactors = FALSE
)

cfb_games_example <- tibble::as_tibble(cfb_games_example)
cfb_teams_example <- tibble::as_tibble(cfb_teams_example)

usethis::use_data(cfb_games_example, cfb_teams_example, overwrite = TRUE)
