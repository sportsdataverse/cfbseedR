# cfbseedR 0.2.0

First CRAN submission.

## Test environments

* local Windows 10, R 4.6.1
* GitHub Actions (R-CMD-check): windows-latest (release),
  macOS-latest (release), ubuntu-latest (devel, release, oldrel-1)

## R CMD check results

0 errors | 0 warnings | 0 notes

## Comments

* All examples and tests run offline against bundled toy fixtures
  (`inst/extdata/`); no network access is required or attempted.
* Simulation examples are wrapped in `\donttest{}` (they run a few
  seconds of Monte Carlo).
* The package adapts nflseedR (MIT, Lee Sharpe & Sebastian Carl) to
  college football; both nflseedR authors are credited in Authors@R.
