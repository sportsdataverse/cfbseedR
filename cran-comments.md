# cfbseedR 0.2.0

First CRAN submission.

## Test environments

* local Windows 10, R 4.6.1
* win-builder (R-devel 2026-08-25 r90448, checked 2026-08-27): 1 NOTE, quoted below
* R-hub v2: linux, windows, macos, macos-arm64 (all R-devel): Status OK, no notes
* GitHub Actions (R-CMD-check): windows-latest (release),
  macOS-latest (release), ubuntu-latest (devel, release, oldrel-1)

## R CMD check results

0 errors | 0 warnings | 1 note

The note is the standard new-submission note from win-builder:

```
Maintainer: 'Saiem Gilani <saiem.gilani@gmail.com>'

New submission

Possibly misspelled words in DESCRIPTION:
  CFP (14:6)
  CFP's (16:24)
  FBS (15:61)
  pluggable (18:5)
```

All four flagged words are spelled correctly. "CFP" and "FBS" are the
standard abbreviations for the College Football Playoff and the Football
Bowl Subdivision; both are expanded on first use in the Description, and
the flagged occurrences are the later short forms (including the
possessive "CFP's"). "Pluggable" is used in its ordinary software sense,
describing the user-supplied results-generator function.

R-hub reports Status: OK on all four platforms with no notes.

## Comments

* The package ships one vignette ("Getting started with cfbseedR"); it
  builds in about 3 seconds and needs no network. The longer pkgdown
  articles are excluded from the build.
* All examples and tests run offline against the bundled toy season
  (exported as `cfb_games_example` / `cfb_teams_example`, also in
  `inst/extdata/`); no network access is required or attempted.
* Every example is wrapped in `\donttest{}` and every test calls
  `testthat::skip_on_cran()`, matching the conventions of the
  SportsDataverse packages already on CRAN (cfbfastR, hoopR, wehoop,
  baseballr).
* The package adapts nflseedR (MIT, Lee Sharpe & Sebastian Carl) to
  college football; both nflseedR authors are credited in Authors@R.
* gt and scales are used only by `summary.cfbseedR_simulation()` and
  `fmt_pct_special()`, are in Suggests, and are reached through
  `rlang::check_installed()`, so the package works fully without them.
* furrr/future/progressr back the optional chunked simulation. The default
  future plan is sequential, so nothing runs in parallel unless the user
  opts in, and no example or test sets a parallel plan.
