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
| `"adj_epa"` | 31.8829 / 37.8903 / 45.1766 / 49.6115 | 17.0386 | 2.7625 | sportsdataverse-py `cfb_prediction_constants`, modern era, as refit in sportsdataverse-py #1300 (main `bcce2e681ee`) |

Home field is fixed at the ELO generator's within-season estimate (2.376,
`cfb_elo_constants.md`) for `"points"` and `"raw_epa"`: the free walk-forward
fits (2.5-3.2) are inflated because early-season ratings under-explain team
strength.

**Adjusted EPA uses sportsdataverse-py's constants, not this fit.** The two
adjustments differ, and so do their scales:

| Source | scale 0-3 / 4-5 / 6-7 / 8-20 | margin_sd | home |
|---|---|---|---|
| this script (play-weighted ridge, lambda 100 plays) | 59.33 / 53.53 / 60.58 / 63.17 | 17.50 / 16.90 / 16.54 / 16.95 | 2.71 (free fit) |
| sportsdataverse-py `adj_net` (shipped) | 31.88 / 37.89 / 45.18 / 49.61 | 17.04 | 2.76 |

The package ships sportsdataverse-py's values so that a rating on that
package's `adj_net` scale gives the same expected margins in R and Python
(sportsdataverse-py's own walk-forward of those constants is in its
`cfb_prediction_constants.py`). A rating from another adjustment should pass
its own `scale` and `margin_sd`. **The adjusted-EPA comparison row above
scores this script's adjustment with its own fitted coefficients; the shipped
`"adj_epa"` configuration is not scored here.**

## Caveats

- ELO's row is the shipped margin formula fed CollegeFootballData's pregame
  ELO, which carries ratings over between seasons and updates them weekly on
  real results. `cfbseedR_compute_results()` reproduces that only when given
  carried-over starting ratings through `elo`; without them it starts every
  team from a random rating.
- Every score is one week ahead (ratings refreshed with each week's real
  results). A simulation started at week w predicts weeks w to the end from
  week-w ratings, a longer horizon this test did not score.
- The points rating is a current-season ridge least-squares margin rating.
  SP+ and FPI blend in preseason priors, so they are accepted inputs, not
  validated ones, and the bucketed `scale` is an attenuation correction for
  this rating.
- From six games on, points and ELO differ by -0.02 (6-7) and -0.11 (8-20)
  MAE, within sampling noise; Brier at 8+ games is 0.1858 (ELO) vs 0.1865.
  Read them as level. Postseason games sit in the 8-20 bucket with late
  regular-season weeks and are not scored separately.
- Only Brier is reported for the win probabilities; no calibration table or
  `margin_sd` coverage check was run.
- Bucket 0-3 was fitted on 2-3-game ratings (scoring needs 2 prior games) and
  is also applied at 0-1 games.
