# cfbseedR Copilot Instructions

## Project Context

cfbseedR is an R package that simulates and evaluates college football
seasons: standings with a documented tiebreaker cascade, conference
champions, College Football Playoff (CFP) straight seeding, and
week-by-week season simulation with a pluggable results generator. It
adapts [nflseedR](https://nflseedr.com) (MIT, Lee Sharpe & Sebastian Carl)
to college football semantics. Docs: https://cfbseedR.sportsdataverse.org

## Exports (6)

`cfb_standings()`, `cfb_playoff_seeds()`, `cfb_simulations()`,
`cfbseedR_compute_results()`, `simulations_verify_fct()`,
`cfb_games_from_schedule()`. User-facing engine functions use the `cfb_`
prefix; the two helpers mirror their nflseedR namesakes.

## Semantics rulings (do not change casually)

- `sov`/`sos` are **conference-REG-scoped**: computed over regular-season
  conference games only; `sov` over conference victories, `sos` over
  conference opponents; independents get `0.0`.
- `CONF_CHAMP` games count toward the overall record and decide
  `conf_champ`, but NOT toward the conference record/rank; matchups are
  simulated as scheduled.
- CFP straight seeding (2025): 5 highest-ranked conference champions
  guaranteed; seeds strictly in ranking order (no champion bump).
- These rulings are cross-validated against sportsdataverse-py's CFB
  standings implementation — keep the two reconcilable.

## Code Style

- Tidyverse style: snake_case, 2-space indent, native pipe `|>` (never
  `%>%`), `.data` pronoun inside dplyr verbs.
- Messaging via `cli::cli_abort()` / `cli::cli_inform()` — not
  `stop()` / `warning()` / `message()`.
- roxygen2 markdown docs with `@return` column tables; simulation examples
  in `\donttest{}`. Run `devtools::document()`; never hand-edit `man/` or
  `NAMESPACE`.

## Testing

- testthat edition 3, fully offline against `inst/extdata/toy_games.csv` /
  `toy_teams.csv`. Run `devtools::test()`; R CMD check must stay
  0 errors / 0 warnings.
- Vignettes are `.Rbuildignore`d pkgdown articles and must run offline
  (`eval = FALSE` for cfbfastR network chunks).

## Commits & PRs

- Conventional Commits (`feat:`, `fix:`, `docs(pkgdown):`,
  `ci(actions):`, …); one logical change per commit.
- **Never add AI co-author trailers** (Copilot/Claude/etc.) to commits or
  PRs — the human author is the sole attributable contributor.
- `README.md` is generated from `README.Rmd` — edit the `.Rmd` and re-knit.
