# `cfb_2025_ratings`: real 2025 FBS ratings and postseason games

Inputs and expected output for `cfbseedR_ratings_compute_results()`.

- **`ratings.csv`**: one row per FBS team (136), its end-of-regular-season
  `games` (FBS-vs-FBS games played) and three ratings: `points` (ridge
  least-squares margin rating, points per game), `raw_epa` (net EPA per play)
  and `adj_epa` (opponent-adjusted net EPA per play). Built by
  `data-raw/cfb_generator_constants.R` from `cfbfastR::load_cfb_schedules()`
  and `cfbfastR::load_cfb_pbp()` for 2025 (method in the script header).
- **`games.csv`**: the 47 games of the last regular-season week and the
  postseason (bowls and CFP) in the engine schema, results blanked. Written by
  the same script.
- **`expected.csv`**: the expected home margin and margin SD the package's
  defaults give every game, for each rating type, with the recorded `games`
  (`games_div = 1`, top bucket) and with `games %/% 2` (`games_div = 2`, the
  middle buckets). Rebuilt by `capture.R` in this directory.

The `adj_epa` column is the fitting script's own adjustment, so it is only
roughly on the scale of sportsdataverse-py's `adj_net`, whose constants the
`"adj_epa"` defaults use. That does not matter here: the fixture checks the
margin formula, the bucket lookup and the defaults, not the ratings.

sportsdataverse-py keeps byte-identical copies of the three CSVs for its
`cfb_ratings_compute_results()` parity test.
