# CFB ratings-generator constants: fit record

Source of the defaults of `cfbseedR_ratings_compute_results()` and of the
comparison against the default ELO generator. Script:
`data-raw/cfb_generator_constants.R` (method in its header). Full output:
`data-raw/cfb_generator_constants.log`; per-season scores:
`data-raw/cfb_generator_constants_by_season.csv`; the comparison table:
`data-raw/cfb_generator_comparison.csv`.

- Run: 2026-11-26, R 4.6.1, cfbfastR 3.0.0.9000, `load_cfb_schedules()` and
  `load_cfb_pbp()` (about 10 minutes for 2014-2025).
- Data: completed FBS-vs-FBS games, regular season and postseason,
  2014-2025, with 2020 left out of every fit and score (as in
  `cfb_elo_constants.md`).
- Ratings are walk-forward: a week-w game is rated from FBS-vs-FBS games
  before week w only; postseason games use the end-of-regular-season
  ratings. Scored: week >= 4 and the postseason, both teams with >= 2 prior
  games and a CFBD pregame ELO: **6,854 games in 146 (season, week)
  clusters**.
- Each test season is scored with coefficients fitted on the other seasons
  (leave one season out). ELO is the shipped `cfbseedR_compute_results()`
  formula on CFBD pregame ELO, whose constants were fitted on all of these
  seasons, which favours it slightly. Home edge fixed at 2.376 points for
  every generator. 95% intervals: paired differences against ELO,
  bootstrapped over (season, week) clusters.

## Comparison

| Generator | MAE | dMAE vs ELO [95% CI] | Brier | dBrier vs ELO [95% CI] |
|---|---|---|---|---|
| ELO (default) | 12.94 | - | 0.1875 | - |
| points | 13.10 | +0.157 [+0.023, +0.306] | 0.1910 | +0.0035 [+0.0007, +0.0065] |
| adjusted EPA/play | 13.38 | +0.439 [+0.267, +0.604] | 0.1969 | +0.0094 [+0.0059, +0.0130] |
| raw EPA/play | 13.70 | +0.765 [+0.586, +0.943] | 0.2017 | +0.0142 [+0.0105, +0.0179] |

By games played of the less-observed team (MAE):

| Bucket | Games | ELO | points | adj EPA | raw EPA |
|---|---|---|---|---|---|
| 0-3 | 1,387 | 12.73 | 13.39 | 13.75 | 14.13 |
| 4-5 | 1,428 | 12.85 | 13.19 | 13.32 | 13.48 |
| 6-7 | 1,412 | 13.05 | 13.03 | 13.21 | 13.56 |
| 8-20 | 2,627 | 13.04 | 12.93 | 13.30 | 13.68 |

Reading: ELO is best overall and early in the season, because it carries a
rating across seasons and these current-season ratings start from nothing.
From about six games the points rating ties or beats it. That is the basis of
the documented advice: ELO by default, a points rating for a late-season or
postseason simulation.

Checks: games-played buckets help a little (flat-scale MAE points 13.11,
adjusted 13.39, raw 13.82). The ridge penalty barely matters (points lambda
0.5 / 2 / 8 games: 13.08 / 13.10 / 13.25; adjusted lambda 30 / 100 / 300
plays: 13.378 / 13.379 / 13.480).

## Shipped defaults

Fit on all pooled seasons; buckets 0-3 / 4-5 / 6-7 / 8-20 games.

| `rating_type` | `scale` | `margin_sd` | `home_field` | Source |
|---|---|---|---|---|
| `"points"` | 1.0929 / 0.9234 / 1.0305 / 1.0628 | 16.968 / 16.638 / 16.231 / 16.451 | 2.376 | this fit (free home fit 2.517) |
| `"raw_epa"` | 28.585 / 34.321 / 45.097 / 52.025 | 17.931 / 17.240 / 16.981 / 17.393 | 2.376 | this fit (free home fit 3.207) |
| `"adj_epa"` | 41.2286 / 49.1525 / 60.1753 / 65.5762 | 17.2358 | 2.6828 | sportsdataverse-py `cfb_prediction_constants`, modern era |

Home field is fixed at the ELO generator's within-season estimate (2.376,
`cfb_elo_constants.md`) for `"points"` and `"raw_epa"`: the free walk-forward
fits (2.5-3.2) are inflated because early-season ratings under-explain team
strength.

**Adjusted EPA uses sportsdataverse-py's constants, not this fit.** This
script's own adjustment (a play-weighted ridge, lambda 100 plays) gives
59.33 / 53.53 / 60.58 / 63.17 points per EPA/play, SD 17.50 / 16.90 / 16.54
/ 16.95 and a free home fit of 2.71, close to sportsdataverse-py's values. The
package ships sportsdataverse-py's values so that a rating on that package's
`adj_net` scale gives the same expected margins in R and Python. A rating
from a different adjustment should pass its own `scale` and `margin_sd`.
The comparison row above scores this script's adjustment with its own fitted
coefficients.
