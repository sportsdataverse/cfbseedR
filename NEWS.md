# cfbseedR 0.3.0

Closes the remaining surface gaps with [nflseedR](https://nflseedr.com).

* **Parallel simulation.** `cfb_simulations()` gains `chunks` (default 8):
  simulations are split into contiguous blocks and dispatched with
  `furrr::future_map()`, so setting a parallel plan
  (`future::plan("multisession")`) spreads them across cores. Progress is
  reported through `progressr`. A given seed reproduces exactly for a fixed
  `chunks`, and a parallel plan gives bit-identical results to a sequential
  one -- but the RNG stream differs from a single unchunked pass, so output
  for the same seed changes if you change `chunks`.
* **`summary()` for simulations.** `cfbseedR_simulation` objects were classed
  but had no methods, so `summary()` fell back to R's generic list summary.
  There is now a `summary.cfbseedR_simulation()` gt method rendering the
  `overall` table grouped by conference, the counterpart of nflseedR's
  `summary.nflseedR_simulation()`.
* **`fmt_pct_special()`** formats probabilities the way simulation summaries
  want them: `<1%` instead of a flat `0%`, `>99.9%` instead of a false
  `100%`. Ported from nflseedR.
* **Exported example data.** `cfb_games_example` and `cfb_teams_example`
  replace the `read.csv(system.file(...))` dance in examples, mirroring
  nflseedR's `sims_games_example` / `sims_teams_example`.
* **`verbosity` on `cfb_simulations()`**, matching `cfb_standings()` and
  `nfl_simulations()`; `"NONE"` silences it completely. The simulation's
  tiebreak notes are now attached to the returned standings as well -- they
  were previously computed and discarded.
* **`ranks = "NONE"`** on `cfb_standings()` skips the conference-rank
  cascade entirely when you only need records, after nflseedR's `ranks`
  argument.
* New Imports: furrr, future, progressr. New Suggests: gt, scales (both
  only needed for `summary()` and `fmt_pct_special()`).

# cfbseedR 0.2.0

2026-season rules refresh (researched against official conference and CFP
sources, 2026-08-26).

* `cfb_playoff_seeds()` gains a season-keyed `autobid` policy. The new
  default `"2026"` implements the current CFP automatic-qualifier rule:
  the ACC / Big 12 / Big Ten / SEC champions are in regardless of ranking,
  the highest-ranked Group-of-6 team is in whether or not it won its
  conference, and Notre Dame is in when ranked inside the field.
  `autobid = "2025"` keeps the 2024-2025 rule (5 highest-ranked
  champions). `cfb_simulations()` passes the policy through.
* The conference tiebreaker registry is now **season-scoped**: each
  conference registers dated epochs, resolved per season (current rules
  for plain `sim` ids). The ACC's all-new 2026 policy (head-to-head, then
  SportSource Team Success Ranking, then a draw, with the
  alternate-game-count candidate-pool rule and the postseason-eligibility
  filter) applies from 2026; earlier ACC seasons keep the 2024 cascade.
* New official registry entries: **American**, **Conference USA**, and
  **Mountain West** (head-to-head / CFP-ranked-final-week clause /
  metric-composite procedures), and the **Sun Belt** (division format).
  The MAC entry now matches its published three-step procedure. The
  re-formed Pac-12 has not published a procedure and stays on the generic
  fallback.
* New rung primitives: `cfp_ranked_final_week` (fed by
  `tiebreaker_data$cfp_rankings`; the best-ranked tied team advances only
  if it won its final conference game) and `div_pct` (win pct vs
  same-division opponents).
* `cfb_simulations()` gains `tiebreaker_data` (external tiebreaker
  inputs, held static across simulations) so simulated standings use the
  same official rungs as `cfb_standings()`.
* The CUSA registry gains the policy's late `apr` rung (fed by
  `tiebreaker_data$apr`); the CFP auto-bid policy matches both short and
  full conference spellings (e.g. `"Southeastern Conference"`).
* CRAN preparation: every test skips on CRAN, every example is wrapped in
  `\donttest{}`, and the packaging metadata (LICENSE, cph, CITATION,
  `.Rbuildignore`, `.gitattributes`) was reviewed.
* `teams` gains two optional columns: `conf_division` (division-format
  ranking - the two division champions take `conf_rank` 1-2, as in the
  2026 Sun Belt) and `postseason_eligible` (an ineligible team cannot
  occupy a championship-game berth while its games still count).

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
