# Pull Request

## Summary
<!-- Provide a brief, clear summary of what this PR does (2-3 sentences max) -->

## Type of Change

- [ ] `feat`: New feature
- [ ] `fix`: Bug fix
- [ ] `docs`: Documentation only (roxygen, README, NEWS, vignettes, pkgdown)
- [ ] `test`: Adding or updating tests
- [ ] `refactor`: Code refactoring (no functional change)
- [ ] `chore`: Maintenance / tooling
- [ ] `ci`: GitHub Actions / workflow changes

## Related Issues

<!-- Link related issues: Closes #123, Fixes #456 -->

## Background & Context
<!--
Help future contributors understand the full picture:
- What problem or need prompted this change?
- If this touches the tiebreaker cascade, sov/sos scoping, CONF_CHAMP
  handling, or CFP seeding, note the semantics ruling involved (see
  CLAUDE.md / .github/copilot-instructions.md) and whether the
  sportsdataverse-py CFB standings side needs a matching change.
-->

## Changes Made
<!-- List ALL changes. Be specific — assume the reviewer has no prior context. -->

| File / Resource | Change Description |
| --------------- | ------------------ |
|                 |                    |
|                 |                    |

## Submission Checklist

- [ ] Code follows tidyverse style (`snake_case`, 2-space indent, native pipe `|>`)
- [ ] User-facing messages use `cli::cli_abort()` / `cli::cli_inform()` (not `stop()` / `message()`)
- [ ] `devtools::document()` has been run (no hand-edits to `man/` or `NAMESPACE`)
- [ ] New / changed functions have roxygen with `@export`, `@return` column table, and a runnable example (`\donttest{}` for simulations)
- [ ] Tests added / updated in `tests/testthat/` (offline, toy-fixture based)
- [ ] `devtools::check()` passes with 0 errors / 0 warnings
- [ ] `NEWS.md` updated (if user-facing)
- [ ] `_pkgdown.yml` reference index updated for new exports
- [ ] `README.Rmd` re-rendered (`devtools::build_readme()`) if README content changed
- [ ] Commit messages use conventional commit format (`type: description`); **no AI co-authors**

## Testing

<!-- How was this tested? devtools::test() output, manual smoke calls, etc. -->

```r
# e.g.
# devtools::test()
# cfb_standings(games, teams, tiebreaker_depth = "POINTS", verbosity = "MAX")
```

## Additional Notes
<!-- Any other information reviewers should know -->
