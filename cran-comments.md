## Update submission

This is a minor release, 0.3.0, following 0.2.0 (on CRAN since 2026-09-09).

Changes since 0.2.0:

* `cfb_simulations()` now aborts with a clear error when a game that still
  has to be simulated involves a team missing from `teams`, or has an `NA`
  team name. Previously this silently produced `NA` results in every
  remaining week.
* The test suite is no longer skipped on CRAN. All tests are offline, run
  against the bundled toy season, and take under a minute; tests that need
  gt or scales call `skip_if_not_installed()`.
* Examples are no longer wrapped in `\donttest{}`. They are all offline and
  each finishes in under 1.5 s. The `fmt_pct_special()` and
  `summary.cfbseedR_simulation()` examples are conditional on their Suggests
  packages (scales, gt) via `@examplesIf`.
* cfbfastR was dropped from Suggests; nothing in the package used it.
* `Language: en-US` and an `inst/WORDLIST` were added.
* The CITATION year is fixed instead of being taken from the current date.

## Test environments

* local Windows 10, R 4.6.0 (ucrt):
  `R CMD check --as-cran --run-donttest`, with `_R_CHECK_CRAN_INCOMING_REMOTE_=true`
* GitHub Actions (R-CMD-check workflow): windows-latest (release),
  ubuntu-latest (release), ubuntu-latest (oldrel-1)
* win-builder (devel and release): to be run before submission

## R CMD check results

0 errors | 0 warnings | 0 notes

The local check returned `Status: OK`. Tests: 199 passed, 0 failed, 0 skipped,
in 26 s.

## Reverse dependencies

There are no reverse dependencies on CRAN.

## Comments

* Long-form documentation is published as pkgdown articles at
  <https://cfbseedR.sportsdataverse.org/> rather than shipped as vignettes;
  the vignettes directory is excluded from the build.
* All examples and tests run offline against the bundled toy season
  (`cfb_games_example` / `cfb_teams_example`); no network access is
  required or attempted.
* No example or test sets a parallel future plan, so everything runs
  sequentially.
