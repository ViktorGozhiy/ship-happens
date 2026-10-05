---
name: implement
description: Use when a reviewed implementation plan is ready to be carried out task by task.
---

# Implement

Carry out a reviewed plan task by task with `sh:implementer`, review each task, review the whole branch, and report to Viktor. You never write code and never fix a failure yourself. Pass absolute paths to agents.

## Input

The path of a reviewed plan. Its header names the spec and the project's full test command.

## Setup

1. When `git status` shows uncommitted changes, stop and ask Viktor how to handle them.
2. The branch name is the plan's file name without the date and without `.md`. For `2026-10-05-skill-set.md` it is `skill-set`.
3. When the branch does not exist, run `git rev-parse HEAD` and keep the hash as the base, then create the branch in the current working tree. When it exists, check it out, and the base is the output of `git merge-base HEAD <default branch>`. The default branch is the output of `git symbolic-ref --short refs/remotes/origin/HEAD`. When that fails, ask Viktor.
4. Use a git worktree only when Viktor has said that another session works in this repository.

## For each unchecked task, in order

1. Run `git rev-parse HEAD` and keep the hash as the task base.
2. Dispatch a fresh `sh:implementer` in task mode with `plan`, `task` and `spec`. It ticks the task's checkbox in its last commit. Its return starts with `done`, `blocked: <reason>` or `deviated: <what and why>`.
3. `blocked` stops the loop. Report the reason to Viktor.
4. A deviation that changes behaviour the spec describes stops the loop. Report it to Viktor. Any other deviation is recorded for the report, and the task goes to review like a `done` task. Add the deviation text to the `intent` of that task's reviewers and fixers, so that the reviewer does not report it as a defect.
5. Review the task. Create a review directory `<scratch>/review-code-<YYYYMMDD-HHMMSS>` with an empty `rejections.md`. `<scratch>` is the session's scratchpad directory, or the output of `mktemp -d` when there is none.
6. Dispatch one `sh:code-reviewer` with `target` `<task base>..<HEAD hash>`, `aspect` `full`, `findings_file` `<review directory>/round-1/full.md`, `rejections_file` `<review directory>/rejections.md`, and `intent` "plan `<plan path>`, task `<n>`". It checks acceptance criteria and code quality in one pass.
7. When the reviewer ends with an error, or its findings file is missing or has no verdict line, dispatch it once more. When that fails too, stop and report to Viktor. A missing file is never read as `clean`. When the verdict is `clean`, go to the next task.
8. Otherwise dispatch `sh:implementer` in fix mode with `findings_dir` set to the round directory that holds the findings, `rejections_file` and the same `intent`. When the fixer ends with an error or returns a line starting with `blocked: `, stop and report that to Viktor. Otherwise run `git rev-parse HEAD`. Dispatch one fresh reviewer on `<task base>..<new head>`, with its findings file in `round-2/full.md`, or in `round-3/full.md` after the second fix. Then repeat from step 7.
9. Two fix attempts are the cap. When the review after the second fix still reports blocking defects, stop and report them to Viktor.

A task fails when the implementer ends with an error or its return does not start with `done`, `blocked: ` or `deviated: `. A `blocked` return is never a failure. When a task fails, dispatch `sh:implementer` in task mode again with `failure` set to the error text, and keep the task base from step 1. When the second attempt fails too, stop and report to Viktor.

## After the last task

1. Call `sh:review` with `kind` `code`, `target` `<base>..<HEAD hash>`, and `intent` the spec path and the plan path. When it stops with open blocking defects or a missing findings file, show them to Viktor and stop.
2. Run the project's full test command from the plan header on the final tree. A green run from before the last commit does not count. When it fails, dispatch `sh:implementer` in change mode with `change` set to the test command, its failing output and the instruction to make the tests pass, then run the command again. When the implementer returns `blocked: ` or the command fails a second time, stop and report to Viktor.
3. Report: what was built, the deviations, the review rounds and what they found, the test result, and the peak context size if you know it. Name each commit made after the branch review as not reviewed. Add any second line an implementer returned about an ignored plan file.
4. Ask with `AskUserQuestion`: merge into the base branch, open a pull request, or leave the branch. Do not push or publish before the answer.

The plan's `Finishing (main session)` section is yours, never the implementer's. Carry out its push and pull request steps only when Viktor chose them in his answer.
