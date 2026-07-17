# Issue tracker: GitHub

Issues and PRDs for this repo live as GitHub issues. Use the `gh` CLI for issue operations.

## Repository

`psibrunosg/bsnutri`

## Conventions

- Create an issue: `gh issue create --title "..." --body "..."`
- Read an issue: `gh issue view <number> --comments`
- List issues: `gh issue list --state open --json number,title,body,labels,comments`
- Comment on an issue: `gh issue comment <number> --body "..."`
- Apply labels: `gh issue edit <number> --add-label "..."`
- Remove labels: `gh issue edit <number> --remove-label "..."`
- Close an issue: `gh issue close <number> --comment "..."`

Run `gh` commands inside this clone so it can infer the repo from `git remote -v`.

## Pull requests as a triage surface

PRs as a request surface: no.

If this changes later, flip this flag to `yes` and use the equivalent `gh pr` commands for reading, commenting, labeling, and closing PRs.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.

## Wayfinding operations

Used by `wayfinder`. The map is a single issue with child issues as tickets.

- Map: create one issue labeled `wayfinder:map`.
- Child ticket: create an issue linked to the map as a GitHub sub-issue when available. If sub-issues are not enabled, add the child to a task list in the map body and put `Part of #<map>` at the top of the child body.
- Labels: use `wayfinder:<type>`, where type is `research`, `prototype`, `grilling`, or `task`.
- Blocking: use GitHub native issue dependencies when available. If dependencies are not available, use a `Blocked by: #<n>` line at the top of the child body.
- Claim: assign the issue to the current agent or maintainer before implementation.
- Resolve: comment with the answer, close the issue, then update the map with the decision or context pointer.
