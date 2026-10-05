---
name: quick-fix
description: Use when Viktor asks for a small change that fits one task and changes no interface that other code depends on.
---

# Quick fix

Carry out a small change, often one backlog item, on a branch with `sh:implementer`, review it with `sh:code-reviewer`, then ask Viktor about merging. You never write code and never fix a failure yourself. Pass absolute paths to agents.

## Steps

1. Check that the change fits one implementer task and changes no interface that other code depends on. If not, stop and propose `sh:design`. Ask Viktor to confirm only for a real choice between solutions.
2. When `git status` shows uncommitted changes, stop and ask Viktor how to handle them. Take the full test command from `CLAUDE.md`, then the README, else ask Viktor.
3. Run `git rev-parse HEAD` and keep the hash as the base. Create the branch `fix/<slug>` with a short lowercase `<slug>`.
4. Dispatch `sh:implementer` in change mode with `change` set to the description and the test command. `blocked` stops the skill: report the reason, and propose `sh:design` when the change is larger than step 1 allows. Record `deviated` for the report.
5. Create the review directory `<scratch>/review-code-<YYYYMMDD-HHMMSS>` with an empty `rejections.md`. `<scratch>` is the session's scratchpad directory, else `mktemp -d`.
6. Run `git rev-parse HEAD`. Dispatch one `sh:code-reviewer` with `target` `<base>..<HEAD hash>`, `aspect` `full`, `findings_file` `<review directory>/round-1/full.md`, `rejections_file` `<review directory>/rejections.md`, and `intent` the description.
7. On `clean`, go to step 9.
8. Otherwise dispatch `sh:implementer` in fix mode with `findings_dir` set to the round directory that holds the findings, `rejections_file`, and `intent` the description and the test command. Run `git rev-parse HEAD`. Dispatch one fresh reviewer on `<base>..<new head>` writing `round-2/full.md`, or `round-3/full.md` after the second fix. Repeat from step 7. When the review after the second fix still reports blocking defects, stop and show them to Viktor.
9. Run the test command on the final tree. When it fails, dispatch `sh:implementer` in change mode with the command and its failing output, then run it again. When it fails a second time, stop and report to Viktor.
10. Report the change, review rounds and test result. Ask with `AskUserQuestion`: merge into the base branch, open a pull request, or leave the branch. Do not push or publish before the answer.

When the work proves larger than step 1 allows, stop, say so, and propose `sh:design`.
