---
name: Bug report
about: Report a problem with a cfbseedR function
title: "[bug] <short description>"
labels: ["bug", "needs-triage"]
assignees: ""

---

## Describe the bug

A clear and concise description of what the bug is (error message, wrong
standings/seeds, unexpected `NA`s, a tiebreaker resolving incorrectly, etc.).

## Which function?

- [ ] `cfb_standings()` — standings / conference ranks / champions
- [ ] `cfb_playoff_seeds()` — CFP seeding
- [ ] `cfb_simulations()` — season simulation
- [ ] `cfbseedR_compute_results()` — default ELO results generator
- [ ] `simulations_verify_fct()` — custom generator verification
- [ ] `cfb_games_from_schedule()` — schedule mapping
- [ ] Other (please specify):

## Reproducible example

Please include a minimal reprex. The bundled toy season is ideal for this;
if the issue is data-shaped, include the smallest games/teams frame that
reproduces it.

```r
library(cfbseedR)

games <- read.csv(system.file("extdata", "toy_games.csv", package = "cfbseedR"))
teams <- read.csv(system.file("extdata", "toy_teams.csv", package = "cfbseedR"))

# Smallest call that reproduces the problem:
out <- cfb_standings(games, teams)

# Observed vs expected:
str(out)
```

## Expected behavior

A clear and concise description of what you expected to happen (e.g. team X
ranked above team Y via head-to-head, seed assigned to the guaranteed
champion, simulation filling week N).

## Error message / output

If applicable, paste the full error / warning output here (please use a code
fence — do **not** paste screenshots of text).

```
# Error in ...
```

## Session info

Please run the following and paste the output:

```r
sessionInfo()
packageVersion("cfbseedR")
R.version.string
```

```
# Paste output here
```

## Additional context

Anything else relevant — data source (cfbfastR schedules?), conference /
season involved, links to related issues or PRs.
