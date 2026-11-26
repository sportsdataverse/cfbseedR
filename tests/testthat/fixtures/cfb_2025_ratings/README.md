# `cfb_2025_ratings`: real 2025 FBS ratings and postseason games

Inputs and expected output for `cfbseedR_ratings_compute_results()`.

- **`ratings.csv`**: one row per FBS team (136), its end-of-regular-season
  `games` (FBS-vs-FBS games played) and three ratings: `points` (ridge
  least-squares margin rating, points per game), `raw_epa` (net EPA per play)
  and `adj_epa` (opponent-adjusted net EPA per play). Built by
  `data-raw/cfb_generator_constants.R` from `cfbfastR::load_cfb_schedules()`
  and `cfbfastR::load_cfb_pbp()` for 2025 (method in the script header).
- **`games.csv`**: the 47 games from week 16 (Army-Navy, the one
  regular-season game left) through the postseason (bowls and CFP) in the
  engine schema, results blanked. Written by the same script.
- **`expected.csv`**: the expected home margin and margin SD the package's
  defaults give every game, for each rating type and four `variant`s of the
  `games` column (`ratings_fixture_variant()` in `tests/testthat/helper.R`):
  `full` (as recorded, top bucket), `half` (`games %/% 2`, the middle
  buckets), `quarter` (`games %/% 4`, the 0-3 bucket) and `missing` (Georgia
  Southern dropped, so it rates 0 with no count; Navy's `games` set to `NA`).
  Rebuilt by `capture.R` in this directory, with LF line endings and 10
  decimals. It is a regression snapshot of this package's output; compare
  with an absolute tolerance of about 1e-9.

The `adj_epa` column is the fitting script's own adjustment, on a different
scale from sportsdataverse-py's `adj_net`, whose constants the `"adj_epa"`
defaults use. That does not matter here: the fixture checks the
margin formula, the bucket lookup and the defaults, not the ratings.

sportsdataverse-py's `cfb_ratings_compute_results()` parity test reads
byte-identical copies of the three CSVs (copy them from git, not from a
Windows working tree).
