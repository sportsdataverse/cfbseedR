# Rebuild expected.csv: the expected home margin and margin SD that
# cfbseedR_ratings_compute_results() gives every game in games.csv, for each
# rating column of ratings.csv. Run from the package root:
#   Rscript tests/testthat/fixtures/cfb_2025_ratings/capture.R
# test-ratings-compute-results.R checks the package against this file, and
# sdv-py's cfb_ratings_compute_results() parity test reads the same three
# CSVs, so rerun it only when the defaults change on purpose.
#
# Every rating type is computed under four variants of the `games` column
# (ratings_fixture_variant() in tests/testthat/helper.R): "full" (as
# recorded, 11-13 games, the top bucket), "half" (games %/% 2, the middle
# buckets), "quarter" (games %/% 4, the 0-3 bucket) and "missing" (Georgia
# Southern dropped, so it rates 0 with no count, and Navy's games NA, so
# Navy's games use the opponent's count).
pkgload::load_all(quiet = TRUE) # also sources tests/testthat/helper*.R
dir <- file.path("tests", "testthat", "fixtures", "cfb_2025_ratings")
ratings <- read.csv(file.path(dir, "ratings.csv"))
games <- read.csv(file.path(dir, "games.csv"))

grid <- expand.grid(
  variant = c("full", "half", "quarter", "missing"),
  rating_type = c("points", "adj_epa", "raw_epa"),
  stringsAsFactors = FALSE
)
out <- do.call(rbind, lapply(seq_len(nrow(grid)), function(i) {
  type <- grid$rating_type[i]
  variant <- grid$variant[i]
  m <- ratings_expected_margin(
    games$home_team, games$away_team, games$neutral,
    ratings = ratings_fixture_variant(ratings, type, variant),
    rating_type = type
  )
  data.frame(
    rating_type = type, variant = variant, week = games$week,
    game_type = games$game_type, home_team = games$home_team,
    away_team = games$away_team, neutral = games$neutral,
    expected = sprintf("%.10f", m$expected), margin_sd = sprintf("%.10f", m$margin_sd)
  )
}))
con <- file(file.path(dir, "expected.csv"), open = "wb") # LF line endings on every OS
utils::write.csv(out, con, row.names = FALSE, quote = FALSE)
close(con)
