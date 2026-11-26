# Rebuild expected.csv: the expected home margin and margin SD that
# cfbseedR_ratings_compute_results() gives every game in games.csv, for each
# rating column of ratings.csv. Run from the package root:
#   Rscript tests/testthat/fixtures/cfb_2025_ratings/capture.R
# test-ratings-compute-results.R checks the package against this file, and
# sdv-py's cfb_ratings_compute_results() parity test reads the same three
# CSVs, so rerun it only when the defaults change on purpose.
#
# Every rating type is computed twice: with the `games` column as recorded
# (end of the regular season, 11-13 games, so the top bucket) and with
# `games %/% 2` (5-6 games, the middle buckets), so the bucket lookup is
# covered too. `games_div` says which.
pkgload::load_all(quiet = TRUE)
dir <- file.path("tests", "testthat", "fixtures", "cfb_2025_ratings")
ratings <- read.csv(file.path(dir, "ratings.csv"))
games <- read.csv(file.path(dir, "games.csv"))

grid <- expand.grid(
  rating_type = c("points", "adj_epa", "raw_epa"), games_div = c(1L, 2L),
  stringsAsFactors = FALSE
)
out <- do.call(rbind, lapply(seq_len(nrow(grid)), function(i) {
  type <- grid$rating_type[i]
  div <- grid$games_div[i]
  m <- ratings_expected_margin(
    games$home_team, games$away_team, games$neutral,
    ratings = data.frame(team = ratings$team, rating = ratings[[type]], games = ratings$games %/% div),
    rating_type = type
  )
  data.frame(
    rating_type = type, games_div = div, week = games$week,
    game_type = games$game_type, home_team = games$home_team,
    away_team = games$away_team, neutral = games$neutral,
    expected = round(m$expected, 10), margin_sd = round(m$margin_sd, 10)
  )
}))
write.csv(out, file.path(dir, "expected.csv"), row.names = FALSE)
