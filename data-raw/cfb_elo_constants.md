# CFB ELO constants: fit record

Source of the `home_field` and `margin_sd` defaults of
`cfbseedR_compute_results()`. Script: `data-raw/cfb_elo_constants.R`
(method in its header). Per-season output:
`data-raw/cfb_elo_constants_by_season.csv`.

- Run: 2026-11-24, R 4.6.1, cfbfastR 3.0.0.9000, `load_cfb_schedules()`.
- Data: completed FBS-vs-FBS games, regular season and postseason,
  2014-2025. 9,085 games fitted; the pooled defaults leave out 2020 (most
  games had no crowd or a capped one), leaving **8,551 games** (7,865 true
  home games).

## Result

| Quantity | Value | SE | Default |
|---|---|---|---|
| Home-field advantage (Massey, within season) | 2.376 pts | 0.168 (between-season SD 0.442) | `home_field = 59.4` ELO (= 25 x 2.376) |
| Margin SD around the generator's estimate (CFBD pregame ELO) | 16.724 pts | 0.128 | `margin_sd = 16.7` |

Replaced: nflseedR's NFL values, `home_field = 20` (0.8 pt) and
`margin_sd = 13`.

## Checks

- Conference games only: margin SD 16.235 (n = 5,823), home-field from the
  pregame-ELO regression 2.52 (SE 0.22), in line with the Massey 2.38.
- Game-noise floor (in-sample Massey residual SD, df 7,113): 14.424. The
  default is the larger predictive value because a simulator draws around
  a pregame rating, not around a season-long fitted one.
- Free regression `margin ~ home + elo_diff` on CFBD pregame ELO: slope
  0.0423 pts per ELO point (SE 0.0006) against the 1/25 = 0.0400 the
  generator uses, so the 25 ELO-per-point scale is kept. Its home term
  (3.34) is inflated by non-conference "buy" games where pregame ELO
  underrates the home team; restricted to conference games it falls to
  2.52.
- Per season, the home-field estimate ranges 1.74-3.08 outside 2020 (0.76
  in 2020); the margin SD ranges 16.2-17.4.

## Pooled output (verbatim)

```
seasons 2014-2025, pooled excludes 2020
FBS-vs-FBS games: 9085 fitted, 8551 pooled (7865 true-home)
hfa        = 2.376 pts (SE 0.168; between-season SD 0.442)
home_field = 25 * hfa = 59.4 ELO
margin_sd  = 16.724 pts (SE 0.128; n 8551 games with pregame ELO)
  conference games only: 16.235 (n 5823)
  in-sample Massey residual SD (game-noise floor): 14.424 (df 7113)
  free fit margin ~ home + elo_diff: home 3.337 (SE 0.189), pts per ELO 0.0423 (SE 0.0006; 1/25 = 0.0400)
```
