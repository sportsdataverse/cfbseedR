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
