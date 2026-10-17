---
name: quick-fix
description: Use when Viktor asks for a small change that fits one task and changes no interface that other code depends on.
---

# Quick fix

Carry out a small change, often one backlog item, on a branch with `sh:implementer`, review it with `sh:code-reviewer`, then ask Viktor about merging. You never write code and never fix a failure yourself. Pass absolute paths to agents.

## Input

A description of the change, and optionally the path of a backlog item in the format of `${CLAUDE_PLUGIN_ROOT}/skills/backlog/backlog-format.md`. With an item path, the description of the change is the item's whole text, including `## Done when`, so that a clean review checks the item's goal. When Viktor narrowed the change to part of the item, the description is the item's whole text followed by a sentence that names the part this change covers.

## Steps

1. Check that the change fits one implementer task and changes no interface that other code depends on. If not, stop and propose `sh:design`, and pass it the backlog item path when the input has one. Ask Viktor to confirm only for a real choice between solutions.
2. When `git status` shows uncommitted changes, stop and ask Viktor how to handle them. Take the full test command from the project's `CLAUDE.md`, then the README, else ask Viktor.
3. Run `git rev-parse HEAD` and keep the hash as the base. Create the branch `fix/<slug>` with a short lowercase `<slug>`.
4. Dispatch `sh:implementer` in change mode with `change` set to the description. Do not pass the full test command: the implementer runs the tests that cover its change, and you run the full command in step 9. `blocked` stops the skill: report the reason. When the change is larger than step 1 allows, also propose `sh:design`, and pass it the backlog item path when the input has one. Record `deviated` for the report, and add its text to the `intent` of the reviewers and fixers. When the implementer ends with an error or returns none of the three lines, stop and report to Viktor.
5. Create the review directory `<scratch>/review-code-<YYYYMMDD-HHMMSS>` with an empty `rejections.md`. `<scratch>` is the session's scratchpad directory, else `mktemp -d`.
6. Run `git rev-parse HEAD`. Dispatch one `sh:code-reviewer` with `target` `<base>..<HEAD hash>`, `aspect` `full`, `findings_file` `<review directory>/round-1/full.md`, `rejections_file` `<review directory>/rejections.md`, and `intent` the description.
7. When the reviewer ends with an error, or its findings file is missing or has no verdict line, dispatch it once more. When that fails too, stop and report to Viktor. A missing file is never read as `clean`. On `clean`, go to step 9.
8. Otherwise dispatch `sh:implementer` in fix mode with `findings_dir` set to the round directory that holds the findings, `rejections_file`, and `intent` the description. When the fixer ends with an error or returns a line starting with `blocked: `, stop and report that to Viktor. Otherwise record each `deviated:` line it returns for the report, and add its text to the `intent` of every later reviewer and of every later fixer. Run `git rev-parse HEAD`. Dispatch one fresh reviewer on `<base>..<new head>`, writing `round-2/full.md` after the first fix, `round-3/full.md` after the second, or `round-4/full.md` after the third. Repeat from step 7. When `round-3/full.md` reports a blocking defect, the third fix and `round-4/full.md` follow without a question. When `round-4/full.md` reports a blocking defect, stop and show Viktor the open blocking defects and the advice of the review directory as one numbered list. Collect the advice as the **Leftovers** action of `sh:backlog` in `${CLAUDE_PLUGIN_ROOT}/skills/backlog/SKILL.md` says for the advice of a code review. Viktor can name the ones to write: write them on the fix branch with the **Write** action of `sh:backlog`.
9. Run the test command on the final tree. When it fails, dispatch `sh:implementer` in change mode with `change` set to the command, its failing output and the instruction to make the tests pass, then run it again. When the implementer returns `blocked: ` or the command fails a second time, stop and report to Viktor.
10. When the input named a backlog item and the test command passed in step 9, close the item in the format of `${CLAUDE_PLUGIN_ROOT}/skills/backlog/backlog-format.md`.
    - When the item does not exist or is under `closed/`, change nothing and say so in the report.
    - When Viktor narrowed the change to part of the item, the change is a `Partly done` line that names the fix branch and what was done, added with the **Update** action of `sh:backlog`. The item stays open.
    - Otherwise the change is the close with the outcome `fixed on <branch>`, as the format's section on closing says, with `## Resolution` written from the output of `git log --format=%B <base>..HEAD`.
    - Tracked backlog: make the change and its commit in this step, on the fix branch. Git-ignored backlog: change nothing before the merge question. Step 13 makes the change.
11. Report the change, taken from the output of `git log --format=%B <base>..HEAD`, any deviation from step 4 and each `deviated:` line a fixer returned in step 8, the review rounds and the test result, and any line in which an implementer said it could not tell how to run single tests. Name each commit made after the review as not reviewed, except the commit of step 10: name it as a documentation commit made after the review. When that commit changes a file that is not a `.md` file, name it as not reviewed and list those files. With the report, run the **Leftovers** action of `sh:backlog` with fix now allowed. Its source is the advice of the review directory, whose path you pass. Pass the description as the intent, and the test command of step 2. **Leftovers** writes the items Viktor names for the backlog on the fix branch, and then runs the items he names to fix now on the fix branch, in the fix-now mode of this skill.
12. Take the result that **Leftovers** returns. After `done`, after `stopped: size: <reason>`, or when **Leftovers** started no fix-now run, ask with `AskUserQuestion`: merge into the base branch, open a pull request, or leave the branch. Do not push or publish before the answer. After any other `stopped: <reason>`, ask no merge question and stop. Report the reason, and that the commits from the fix-now base to HEAD carry open defects. When step 10 left the change of a git-ignored backlog for later, say that stopping skips it.
13. Carry out his answer. When step 10 left the change of a git-ignored backlog for later: after "merge", once the merge is done, make that change. It needs no commit. After any other answer, leave the item as it is and tell Viktor.

When the work proves larger than step 1 allows, stop, say so, and propose `sh:design`, and pass it the backlog item path when the input has one.

## Fix-now mode

The **Leftovers** action of `sh:backlog` runs this mode when Viktor names leftovers to fix now. The work stays on the branch that is checked out and ends before the merge question of the skill that ran **Leftovers**.

Input: the items to fix, each with its full text; the intent of the skill that ran **Leftovers**, which is empty in a direct run of **Leftovers**; and optionally the full test command.

Run these steps of the normal run, with these changes:

1. Step 1, on all items together. When they do not fit one implementer task, or change an interface that other code depends on, make no commit and return `stopped: size: <reason>`.
2. Step 2. Take the test command as step 2 says only when the input has none.
3. In place of step 3, run `git rev-parse HEAD` and keep the hash as the fix-now base. Create no branch. In every step this mode runs, `<base>` is the fix-now base, so steps 6 and 8 review `<fix-now base>..<HEAD hash>`. The base of the skill that ran **Leftovers** keeps its value, also when that skill is a normal run of `sh:quick-fix`, whose step 13 uses it.
4. Step 4, with `change` set to the items followed by the intent.
5. Steps 5 to 8, with `intent` set to the intent followed by the items. When `round-4/full.md` reports a blocking defect, the numbered list you show Viktor holds only the open blocking defects. Write the ones he names on the branch that is checked out with the **Write** action of `sh:backlog`.
6. Step 9.
7. The report of step 11, with the fix-now base in place of the base. Name each commit made after the review as not reviewed, as step 11 says. List the advice of the fix-now review directory as plain lines, collected as the **Leftovers** action of `sh:backlog` says for the advice of a code review. Do not offer it as a list.

Do not run step 10: this mode closes no backlog item. Offer no leftovers, and do not ask the merge question.

Return one of these to **Leftovers**:

- `done` when the test command passed in step 9.
- `stopped: size: <reason>` when step 1 found the items too large. No commit was made.
- `stopped: <reason>` when the mode stopped after it started work: a `blocked` implementer, a blocking defect in `round-4/full.md`, the test command failing twice, or any other stop in steps 4 to 9. The report then names the commits from the fix-now base to HEAD as carrying open defects, and names the uncommitted changes a blocked implementer left in the tree.
