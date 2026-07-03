---
name: Feature request
about: Suggest a new capability or enhancement for cfbseedR
title: "[feat] <short description>"
labels: ["enhancement", "needs-triage"]
assignees: ""

---

## Is your feature request related to a problem?

A clear and concise description of what the problem is.
Example: *"I'm always frustrated when I have to hand-build the teams frame
from a cfbfastR schedule before simulating."*

## Which area?

- [ ] Standings / tiebreakers (`cfb_standings()`)
- [ ] Playoff seeding (`cfb_playoff_seeds()`)
- [ ] Season simulation (`cfb_simulations()` / `compute_results` contract)
- [ ] Data preparation (`cfb_games_from_schedule()`)
- [ ] Documentation / vignettes
- [ ] Other (please specify):

## Describe the solution you'd like

A clear and concise description of what you want to happen. If you're
proposing a new function or argument, sketch the signature:

```r
cfb_simulations(games, teams, ..., new_arg = NULL)
```

If nflseedR has an equivalent feature (e.g. chunked/parallel simulation,
`nfl_standings()` options), please link to its docs: https://nflseedr.com

## Describe alternatives you've considered

A clear and concise description of any alternative solutions, workarounds,
or existing functions you've considered.

## Additional context

Add any other context, sample output, or links to related issues / PRs /
external discussions here.
