## Update submission

This is a minor release, 0.3.0, following 0.2.0 (on CRAN since 2026-09-09).

### Changes that alter computed results

These change standings, playoff seeds or simulated results that users may
have stored from 0.2.0. They are deliberate corrections and are described in
NEWS.md.

* Conference tiebreakers now follow the conferences' published procedures:
  the MAC and Conference USA are dated epochs (new 2025 orders); the SEC,
  Big Ten, ACC and Big 12 "record against common opponents in order of
  finish" step compares only opponents every tied team played; and a
  multi-team tie restarts from the first step after any elimination. For
  the real 2025 season this moves the ACC title-game berth from Georgia
  Tech to Duke and the SEC pairing to Alabama and Georgia, matching the
  actual title games.
* The re-formed Pac-12's published 2026 tiebreaker procedure is
  registered from 2026 (separate two-team and multiple-team lists).
* `cfb_standings(playoff_seeds = )` now passes a new `autobid` argument to
  `cfb_playoff_seeds()`; left `NULL`, the CFP rule follows the season, so
  pre-2026 seasons are seeded under the 2025 rule. Before, every season was
  seeded under the 2026 rule.
* The default simulation generator uses college football home-field and
  margin-noise constants fitted on FBS results (2014-2025) instead of the
  NFL values inherited from nflseedR. Both are now arguments.

### Other changes

* `cfb_simulations()` aborts with a clear error when a game that still has
  to be simulated involves a team missing from `teams`, or an `NA` team
  name. Previously this silently produced `NA` results.
* The Notre Dame clause of the 2026 CFP rule also matches Notre Dame by its
  ESPN id.
* The test suite is no longer skipped on CRAN. All tests are offline, run
  against the bundled toy season, and take under a minute; tests that need
  gt or scales call `skip_if_not_installed()`.
* Examples are no longer wrapped in `\donttest{}`. They are all offline and
  each finishes in under 1.5 s. The `fmt_pct_special()` and
  `summary.cfbseedR_simulation()` examples are conditional on their Suggests
  packages (scales, gt) via `@examplesIf`.
* cfbfastR, knitr and rmarkdown were dropped from Suggests; nothing in the
  package, its tests or its examples uses them.
* The nflseedR authors, whose MIT-licensed code cfbseedR adapts, are now
  listed as copyright holders in DESCRIPTION and LICENSE.
* `Language: en-US` and an `inst/WORDLIST` were added, and the CITATION year
  is fixed instead of being taken from the current date.

## Test environments

* local Windows 10, R 4.6.1 (ucrt):
  `R CMD check --as-cran --run-donttest` on the built tarball, with
  `_R_CHECK_CRAN_INCOMING_REMOTE_=true`
* GitHub Actions (R-CMD-check workflow): macos-latest (release),
  windows-latest (release), ubuntu-latest (devel, release, oldrel-1)
* win-builder (devel and release): not yet run (win-builder unreachable
  2026-11-24); to be run before submission
* R-hub v2 (linux, windows, macos, macos-arm64 R-devel, nosuggests):
  all OK, 2026-11-24

## R CMD check results

0 errors | 0 warnings | 1 note

The local check returned one NOTE:

```
* checking for non-standard things in the check directory ... NOTE
Found the following files/directories:
  ''NULL''
```

This is an empty directory that the local Windows TeX installation leaves
in the check directory while building the PDF manual. The package does not
create it; the GitHub Actions checks of 0.2.0 and of the 0.3.0 development
version on main report no notes.

Tests: 275 expectations passed, 0 failed, 0 skipped, in 26 s.

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
