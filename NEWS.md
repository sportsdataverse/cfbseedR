# cfbseedR 0.1.0

Initial release.

* `cfb_standings()` computes overall and conference standings with a
  documented generic tiebreaker cascade (win pct, head-to-head, common
  opponents, SOV, SOS, point differential, coin flip) gated by
  `tiebreaker_depth`.
* `cfb_playoff_seeds()` implements 12-team College Football Playoff
  straight seeding (5 highest-ranked conference champions guaranteed).
* `cfb_simulations()` simulates seasons week by week with a pluggable
  `compute_results` function and returns a classed `cfbseedR_simulation`
  list with standings, games, and aggregated probabilities.
* `cfbseedR_compute_results()` is the default ELO-based results generator,
  a faithful adaptation of `nflseedR_compute_results()`.
* `cfb_games_from_schedule()` maps `cfbfastR::load_cfb_schedules()` output
  to the engine games schema.
* `simulations_verify_fct()` verifies custom `compute_results` functions.

Adapted from [nflseedR](https://nflseedr.com) (MIT) by Sebastian Carl and
Lee Sharpe.
