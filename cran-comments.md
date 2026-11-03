## Update submission

This is a minor release, 0.3.0, following 0.2.0 (on CRAN since 2026-09-09).

Changes since 0.2.0:

* `cfb_simulations()` now aborts with a clear error when a game that still
  has to be simulated involves a team missing from `teams`, or has an `NA`
  team name. Previously this silently produced `NA` results in every
  remaining week.
* The `fmt_pct_special()` and `summary.cfbseedR_simulation()` examples are
  now conditional on their Suggests packages (scales, gt) via `@examplesIf`,
  so they are skipped cleanly when those packages are not installed.
* The test suite is no longer skipped on CRAN. All tests are offline, run
  against the bundled toy season, and take about 15 seconds; tests that
  need gt or scales call `skip_if_not_installed()`.
* `Language: en-US` and an `inst/WORDLIST` were added.

## Test environments

* local Windows 10, R 4.6.0 (ucrt): `R CMD check --as-cran --run-donttest`
* local Windows 10, R 4.6.0, without Suggests
  (`_R_CHECK_DEPENDS_ONLY_=true`): `R CMD check --as-cran --run-donttest`
* R-hub v2: linux, windows, macos, macos-arm64 (R-devel), nosuggests
  (results below)

## R CMD check results

0 errors | 0 warnings | 0 notes

Both local checks (with and without Suggests) return Status: OK.

## R-hub results

R-hub v2 run on 0.3.0 (2026-11-03,
<https://github.com/sportsdataverse/cfbseedR/actions/runs/41611775535>):

* linux (R-devel): Status: OK
* windows (R-devel): Status: OK
* macos (R-devel): Status: OK
* macos-arm64 (R-devel): Status: OK
* nosuggests: Status: OK (2 tests skipped because gt/scales are absent)

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
