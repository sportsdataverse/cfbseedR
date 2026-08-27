# CLAUDE.md — cfbseedR Development Guide

## Package purpose

cfbseedR simulates and evaluates college football seasons: standings with a
documented tiebreaker cascade, conference champions, College Football
Playoff (CFP) straight seeding, and week-by-week season simulation with a
pluggable results generator. It is an adaptation of
[nflseedR](https://nflseedr.com) (MIT, Lee Sharpe & Sebastian Carl) —
credit them in DESCRIPTION/README/vignettes when touching attribution.

- **License:** MIT. **Site:** https://cfbseedR.sportsdataverse.org
- **Branch:** `main` is default and release branch.

## Exports (6)

| Function | Role |
|---|---|
| `cfb_standings()` | Standings + conference ranks/champions (+ optional seeds) |
| `cfb_playoff_seeds()` | CFP 12-team straight seeding, season-keyed `autobid` policy (2026 default) |
| `cfb_simulations()` | Week-loop season simulator, returns `cfbseedR_simulation` list |
| `cfbseedR_compute_results()` | Default ELO results generator (nflseedR port) |
| `simulations_verify_fct()` | Contract checker for custom `compute_results` |
| `cfb_games_from_schedule()` | `cfbfastR::load_cfb_schedules()` → engine games schema |

Internal engine helpers live in `R/standings_utils.R` (mirrors nflseedR's
`standings_utils.R`/`standings_init.R` architecture).

## Binding semantics rulings

- **Conference-REG-scoped `sov`/`sos`:** all tiebreaker cascade quantities
  (head-to-head, common opponents, SOV, SOS, point differential) are
  computed over regular-season conference games only. `sov` is over
  conference victories, `sos` over conference opponents; independents get
  `0.0`. Do not widen to full-schedule scope.
- **`CONF_CHAMP` semantics:** conference championship games count toward
  the overall record and decide `conf_champ`, but do NOT count toward the
  conference record/rank. CONF_CHAMP matchups are simulated as scheduled,
  never re-derived from simulated standings.
- **Straight seeding + season-keyed auto-bids:** seeds are assigned
  strictly in ranking order — champions are never bumped into the top 4.
  `autobid = "2026"` (default): ACC/Big 12/Big Ten/SEC champions in
  regardless of ranking + the highest-ranked Group-of-6 team (champion not
  required) + Notre Dame when ranked inside the field. `autobid = "2025"`:
  the 5 highest-ranked conference champions.
- **Season-scoped tiebreaker registry:** `CONFERENCE_TIEBREAKERS` entries
  are lists of dated epochs resolved per season (`season` ids) or to the
  CURRENT rules (plain `sim` ids). The ACC's 2026 policy (h2h → SportSource
  SSR → draw, wins-or-losses candidate pool, eligibility filter) applies
  from 2026. External metrics (composites, CFP ranks, APR) enter only via
  `tiebreaker_data`; missing inputs skip their rungs with a
  `tiebreak_notes` entry — never invent a metric.
- **Division opt-in:** a `conf_division` column on `teams` is the opt-in
  for division-format ranking (division champs take `conf_rank` 1-2);
  never gate it to a hardcoded conference list.

## Cross-validation contract with sdv-py

`sportsdataverse-py`'s CFB standings implementation (`cfb_standings` on the
Python side) follows the same conference-REG-scoped sov/sos ruling and
CONF_CHAMP semantics. Changes to the cascade, scoping, or CONF_CHAMP
handling here must stay reconcilable with the Python side — if you change
one, flag the other.

## Conventions

- Tidyverse style: snake_case, 2-space indent, **native pipe `|>`** (not
  `%>%`), `.data` pronoun in dplyr verbs, `cli::cli_abort()` /
  `cli::cli_inform()` for messaging (never `stop()`/`message()`).
- testthat edition 3; tests are offline against the bundled toy fixtures
  (`inst/extdata/toy_games.csv` / `toy_teams.csv`). 142+ tests must pass.
- roxygen2 with markdown; `@return` blocks carry column tables; simulation
  examples wrapped in `\donttest{}`. Run `devtools::document()` — never
  hand-edit `man/` or `NAMESPACE`.
- Vignettes under `vignettes/` are `.Rbuildignore`d (pkgdown articles);
  they must stay runnable offline (toy data inline; `eval = FALSE` for
  cfbfastR network chunks).
- R CMD check must stay 0 errors / 0 warnings.

## Workflow

- Conventional Commits (`feat:`, `fix:`, `docs(pkgdown):`, `ci(actions):`,
  …); one logical change per commit; stage explicit paths.
- **Never add AI co-author trailers** (Claude/Copilot/etc.) to commits or
  PRs — the human author is the sole attributable contributor.
- Regenerate `README.md` from `README.Rmd`
  (`devtools::build_readme()` or `rmarkdown::render("README.Rmd")`) —
  never edit `README.md` directly.
- pkgdown site deploys to `gh-pages` via `.github/workflows/pkgdown.yaml`;
  verify locally with `pkgdown::build_site()` before pushing site changes.
