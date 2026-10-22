---
name: backlog
description: Use when the user asks to write something into the backlog (беклог, бэклог), to list or prioritise the open backlog items, to change, defer or close one, to take one into work, or to fix the small open items in priority order without questions (Fix small items).
---

# Backlog

Keep the project's backlog in the format of `${CLAUDE_PLUGIN_ROOT}/skills/backlog/backlog-format.md`. Read that file before you write, update or close an item. You write items yourself and dispatch no agent for them. Every item is committed on the branch that is checked out when you write it. Never check out another branch to write an item.

The backlog directory, the head of an item, the test for a git-ignored backlog and the commit messages are those of the format file. When `git check-ignore -q <path>` exits 0 for a file you change, skip its commit and say so in your report.

## Write

Input: what to write, from the user or from the session.

1. When the backlog directory does not exist, ask the user where it goes, propose `docs/backlog/`, and create the directory they name. When they name a directory other than `docs/backlog/`, add this line to the project's `CLAUDE.md`, with `<directory>` set to their directory, and commit it with the message `docs: name the backlog directory`:

   ```
   `<directory>` — the backlog: one file per deferred task in the format of `sh:backlog`; closed items move to `closed/`.
   ```

   Do not change `.gitignore`.
2. Read the head of each open item with `sed '/^## /q' <item>`. When an open item describes the same problem, change that item with **Update**, tell the user that you did, and write no second item.
3. Write the item in the format, with today's date in its file name. Propose the priority and tell the user the reason in one sentence. Commit the item.
4. Report the path, the priority with its reason, and the branch. The default branch is the output of `git symbolic-ref --short refs/remotes/origin/HEAD` without the `origin/` prefix. When the branch is not the default branch, say that the item reaches the default branch with the merge. When that command fails, name the branch and say nothing about the merge.

When the user corrects the priority, change it with **Update**.

## Update

Input: an item and what to change, from the user or from another action: the priority, the state, a `Partly done` line, or a dated section.

1. When the item has no status line of the format, give it one as the format's section on old items says, and propose a priority when it has none.
2. Change the item as the format's section on updates says. Keep everything else.
3. Commit it, and report the change and the branch.

## List

Input: none.

1. Read the head of every `.md` file directly in the backlog directory, not in `closed/` or another subdirectory, with `sed '/^## /q' <item>`. Never read a body for the list.
2. Take the state, the priority and the date raised from the status line. For an old item, take them from whatever header it has, and the date from the file name when the header has none. A missing priority is "not set".
3. Show a numbered table with the columns priority, date raised, H1 and file name. Order the rows `high`, `normal`, `low`, then "not set"; within a priority, oldest first. Show the deferred items after the table, each with its condition, numbered after the table's last number.
4. Below that, flag each item whose head says it is closed but which is still outside `closed/`. Propose to move them, and move only the ones the user confirms, with **Close by hand**.

Do not flag an item because its status line names a branch. An item raised in the review of a branch names that branch, and the merge of that branch does not close the item.

## Take into work

Input: a number from the last list, or a path.

When the item is under `closed/`, or its head records its close, say so and stop. Otherwise call `sh:design` with the item's path as the backlog item. Its step 1 sends small work to `sh:quick-fix` with the same path. The skill that finishes the work closes the item on the fix branch.

## Fix small items

Input: optionally the largest number of items to fix. It is 5 unless the user names another number in the request.

Fix the small open items one after another, each with `sh:quick-fix` in its unattended mode, and merge each clean result into the default branch. Never push, never run a command that changes state on another host, and never change another repository. Every question comes before the first item. After step 5, ask the user nothing until the leftovers list of step 12.

Before the first item:

1. Find the default branch: the output of `git symbolic-ref --short refs/remotes/origin/HEAD` without the `origin/` prefix. When that command fails, ask the user for the default branch.
2. When `git status --short` prints anything, stop and ask the user how to handle the changes.
3. When the branch that is checked out is not the default branch, ask the user whether to check out the default branch or to stop. **List** reads the backlog of the branch that is checked out, and every item is fixed on a branch cut from the default branch.
4. Take the full test command from the project's `CLAUDE.md`, then the README, else ask the user.
5. Say in one line that the action now runs without questions until its leftovers list, and name the largest number of items.

For the items:

6. Read the heads and order the open items as steps 1 to 3 of **List** say. The deferred items, and the items whose head records their close, are not candidates. When there is no candidate, say so and end.
7. Take the candidates in that order, one at a time: read the next candidate only after `sh:quick-fix` has returned for the previous one. Stop when the items given to `sh:quick-fix` that did not return `skipped: size` reach the largest number, or when the candidates run out. Do not read the candidates after that point. For each candidate, `<slug>` is its file name without the date prefix and without `.md`.
   - When `git rev-parse --verify --quiet refs/heads/fix/<slug>` prints a hash, skip the candidate. Its branch is an unmerged branch of an earlier run of this action.
   - Otherwise read the whole item, and skip it, with the reason, when any of these holds. Keep the names of the options of a skipped item for the report.
     - It has a `## Options` section, or its `## What to do` offers alternatives of which only one is to be carried out, also when one of them is marked as recommended. Numbered steps that are all carried out are not alternatives.
     - It has a `## Open questions` section.
     - Its `## What to do` or its `## Done when` needs a change in another repository or a change of state on another host. A `## Related` section that names another repository does not skip the item.
   - Run no size check yourself. `sh:quick-fix` runs it in its step 1.
8. Before each item, run `git checkout <default branch>`, then `git status --short`. When the checkout fails or the status prints anything, stop the action as step 10 says for a dirty tree, and name the item and the files.
9. Load `sh:quick-fix` with the Skill tool, and run the section `## Unattended mode` of `${CLAUDE_PLUGIN_ROOT}/skills/quick-fix/SKILL.md` with the item's path, the full test command and the default branch. Record the line it returns.
10. After the line, whatever it says, run `git status --short`. When it prints anything, stop the action. Stay on the branch that is checked out, give the report of step 11 with the files that `git status --short` prints and the review directories that the returned lines named, and end. Show no leftovers list and ask nothing: the user can run **Leftovers** directly once the tree is clean. Write nothing on a fix branch. When the tree is clean, go on with the next candidate. A `skipped: size: <reason>` line does not count toward the largest number.

After the last item:

11. Unless the action stopped on a dirty tree, run `git checkout <default branch>`. When that checkout fails, treat it as a stop on a dirty tree as step 10 says: stay on the branch that is checked out, give the report below with the files that `git status --short` prints, show no leftovers list and ask nothing. Report:
    - each item merged, with its branch, the commits that `git log --oneline <base hash>..fix/<slug>` prints with the base hash of its returned line, the number of `round-*` directories in its review directory, and the commit or the `mv` that closed the item;
    - each branch left unmerged, with its reason: the items that returned `unmerged:`, the items that returned `stopped:` on a clean tree, and the branches of an earlier run that step 7 skipped;
    - each item skipped, with its reason, and for an item with options the names of the options;
    - the items not read because of the largest number.

    Say that nothing was pushed. Every merged tree passed the full test command before its fast-forward, so run no further test.
12. Run **Leftovers** with fix now not allowed. Its sources are the advice of every review directory that a returned line names, with the path of each, and the open blocking defects of `round-4/full.md` in the review directory of each item that returned `unmerged:` with `open defects at the cap`. Those defects are backlog only, and each candidate made from one names the unmerged branch it was found on. **Leftovers** writes the items the user names on the default branch, which is checked out.

## Close by hand

Input: an item, and an outcome from the user unless the item's head already records its close. Use this action for items that close without a fix branch of `sh:quick-fix` or `sh:design`: retracted, superseded, dropped, or fixed outside those skills. Use it also for the items that **List** flags.

1. When the item is under `closed/`, say so and change nothing.
2. When its head already records its close, only move it with its references, as the format's section on closing says. Do not touch its head.
3. Otherwise ask the user for the outcome when they have not given it. Write the `Closed` line and `## Resolution`, move the file and change the references, as the format's section on closing says.
4. Commit, and report the outcome, the path under `closed/` and the branch. When the commit changes a file that is not a `.md` file, name the commit as not reviewed and list those files.

## Leftovers

The procedure that `sh:review`, `sh:quick-fix` and `sh:implement` follow at their end, and the action for "what should go into the backlog before this session ends".

Input from a skill that runs this action: the sources of the candidates, with the path of the review directory when a source is the advice of a code review; whether fix now is allowed; and the skill's intent and full test command when it has them. Run directly, the source is the session, and there is no intent and no test command. Fix now is then allowed only when the branch that is checked out is not the default branch. The default branch is the output of `git symbolic-ref --short refs/remotes/origin/HEAD` without the `origin/` prefix. When that command fails, fix now is not allowed.

1. Collect the candidates: work that remains to be done, a problem that was not fixed, a question that was not answered. A skill that runs this action names its sources. Run directly, the source is the session.
   - The advice of a code review is the `## Advice` section of every findings file in the review directory. Read each section from the `## Advice` line to the next line that starts with `## `, never the whole file:

     ```
     awk 'FNR==1{f=0} /^## Advice/{f=1; print "== " FILENAME; next} /^## /{f=0} f' <review directory>/round-*/*.md
     ```

     Turn each remark into one candidate line, merge remarks that repeat across files, and skip `None.`. No fixer reports which advice it applied, so a candidate may already be done. The user sees it in the list and does not pick it.
   - A rejected finding is not a candidate, because it is wrong. An accepted deviation is not a candidate, because it is done. The part of a backlog item that a branch did not cover is not a candidate either: it stays in the open item, under its `Partly done` line.
2. When there are no candidates, say so in one line and ask nothing. The action ends here, and the skill that ran it goes on with its next step.
3. Show all candidates as one numbered list in plain text, one line each, with the proposed priority. Do not use `AskUserQuestion`: the user answers with numbers.
   - When fix now is allowed, mark "backlog only" each candidate that may not be fixed now: an open blocking defect of a review that stopped at its cap, and a requirement of a spec's `## Deferred` section. Only the advice of a code review and, in a direct run, the candidates from the session may be fixed now. Below the list, show the answer form `backlog: 1, 3; fix now: 2`, and say that a number named in both sets counts as fix now.
   - When fix now is not allowed, every candidate is backlog only. Show no marks and no answer form.
4. Sort the user's answer into the backlog set and the fix-now set. An answer with one bare set of numbers names the backlog set. A number named in both sets belongs to the fix-now set. A number that is backlog only belongs to the backlog set, also when the user named it to fix now; the report says so.
5. Write each item of the backlog set with **Write**, and report their paths and the branch.
6. When the fix-now set is empty, the action ends here, and the skill that ran it goes on with its next step. Otherwise run `sh:quick-fix` in the section `## Fix-now mode` of `${CLAUDE_PLUGIN_ROOT}/skills/quick-fix/SKILL.md`. This step is the only place that starts a fix-now run. Pass:
   - the full text of each item of the fix-now set: for the advice of a code review, the whole remark from the `## Advice` section of its findings file, not the one-line candidate; for a candidate from the session, the candidate as the session states it, with its evidence;
   - the intent you were given, or none in a direct run;
   - the test command you were given, or none.
7. When the run returns `stopped: size: <reason>`, show the user the reason and offer to write the items of the fix-now set with **Write**. Write the ones they name. Return the result of the run to the skill that ran this action: `done`, `stopped: size: <reason>` or `stopped: <reason>`.
