---
name: implement
description: Use when a reviewed implementation plan is ready to be carried out by one implementer, with one review of the whole branch and a report to Viktor.
---

# Implement

Carry out a reviewed plan with one `sh:implementer`, review the whole branch, and report to Viktor. You never write code and never fix a failure yourself. Pass absolute paths to agents.

## Input

The path of a reviewed plan. Its header names the spec and the project's full test command, which you run once on the final tree and the implementer reads for its form, or runs before each commit when it is the only test command.

## Setup

1. When `git status` shows uncommitted changes, stop and ask Viktor how to handle them.
2. The branch name is the plan's file name without the date and without `.md`. For `2026-10-05-skill-set.md` it is `skill-set`.
3. When the branch does not exist, run `git rev-parse HEAD` and keep the hash as the base, then create the branch in the current working tree. When it exists, check it out, and the base is the output of `git merge-base HEAD <default branch>`. The default branch is the output of `git symbolic-ref --short refs/remotes/origin/HEAD` without the `origin/` prefix, which is the name of the local branch. When that fails, ask Viktor.
4. Use a git worktree only when Viktor has said that another session works in this repository.

## While the plan has an unchecked task

A task is unchecked when its line `- [ ] Task <n> done` is unticked. Before each dispatch, run `git rev-parse HEAD` and keep the hash.

1. Dispatch `sh:implementer` in plan mode with `plan` and `spec`, and with `failure` when step 3 or step 5 sets it. Its return starts with `done`, `blocked: task <n>: <reason>` or `deviated: task <n>: <what and why>`.
2. `done`: when the plan still has an unchecked task, treat the return as an error under step 5. Otherwise go to "After the last task".
3. `blocked: task <n>: <reason>`: stop and report the reason to Viktor. When the reason is `no code in the plan`, the plan has to be written again: say so and propose `sh:plan` on the spec. For any other reason, including one that starts with `Write refused`, wait until Viktor has settled the point. Then write his answer into task `<n>` of the plan as a line starting `Decided in plan:`, commit the plan unless `git check-ignore -q <plan>` exits 0, and dispatch again with `failure` set to the blocked reason. The implementer builds on the committed work.
4. `deviated: task <n>: <what and why>`: stop and report the deviation to Viktor.
   - When he rejects it, find the task base: the parent of the first commit after the branch base whose message body has the line `Task: <n>`, from `git log --reverse --format='%H%n%b' <base>..HEAD`. Note each `Decided in plan:` line of task `<n>` that `git diff <task base> HEAD -- <plan>` adds. Run `git reset --hard <task base>`, which removes the task's commits with their `Deviation:` line. When the plan is git-ignored, the reset leaves the file as it is, so set the task's line back to `- [ ] Task <n> done` yourself. Write his decision into task `<n>` as a line starting `Decided in plan:`, together with each line you noted that is missing from the plan after the reset. Commit the plan unless its path is git-ignored, and go back to the loop condition.
   - When he accepts it, go back to the loop condition. The `Deviation:` line in the commit reaches the branch review through `git log`.
5. When the implementer ends with an error, or its return starts with none of `done`, `blocked: ` and `deviated: `, dispatch again with `failure` set to the error text. When two dispatches in a row add no commit, so that HEAD after each equals the hash you kept before it, stop and report to Viktor.

## After the last task

1. Call `sh:review` with `kind` `code`, `target` `<base>..<HEAD hash>`, and `intent` the spec path and the plan path, followed by each line that starts with `Deviation:` in the output of `git log --format=%B <base>..HEAD`. That output includes tasks finished in an earlier run and deviations that Viktor accepted. When it stops with open blocking defects or a missing findings file, show them to Viktor and stop.
2. Run the project's full test command from the plan header on the final tree. A green run from before the last commit does not count. When it fails, dispatch `sh:implementer` in change mode with `change` set to the test command, its failing output and the instruction to make the tests pass, then run the command again. When the implementer returns `blocked: ` or the command fails a second time, stop and report to Viktor.
3. Report: what was built, taken from the output of `git log --format=%B <base>..HEAD`, the deviations from that same output, each `deviated:` line a fixer returned in the review, the review rounds and what they found, the test result, and the peak context size if you know it. Name each commit made after the branch review as not reviewed. Add any line an implementer returned about an ignored plan file, and any line in which an implementer said it could not tell how to run single tests.
4. Ask with `AskUserQuestion`: merge into the base branch, open a pull request, or leave the branch. Do not push or publish before the answer.

The plan's `Finishing (main session)` section is yours, never the implementer's. Carry out its push and pull request steps only when Viktor chose them in his answer.
