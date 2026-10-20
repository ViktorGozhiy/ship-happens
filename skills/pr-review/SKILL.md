---
name: pr-review
description: Use when the user asks to review a pull request by number or a branch by name.
---

# Pull request review

Review a pull request or a branch with three `sh:code-reviewer` agents, confirm their findings yourself, save the confirmed ones as a review record, and summarise them for the user. Never check out a branch or change a tracked file in the main working tree. Never post to GitHub unless the user explicitly tells you to in this session.

## Input

A pull request number, or a branch name. For a branch the user may also give a description of the change and the name of a base branch.

## Steps

1. Get the head commit.
   - Pull request number: run `git fetch origin pull/<number>/head`.
   - Branch name with no local branch: run `git fetch origin <branch>`.
   - After either fetch, run `git rev-parse FETCH_HEAD` at once, before any other fetch. The output is the head hash.
   - Branch name with a local branch: run `git rev-parse <branch>`, with no fetch.

   Use the head hash in every later step.
2. Find the base branch. For a pull request run `gh pr view <number> --json title,body,baseRefName` and use `baseRefName`. For a branch it is the repository's default branch, which `git symbolic-ref --short refs/remotes/origin/HEAD` prints as `origin/<name>`, unless the user names another. Run `git fetch origin <base branch>`.
3. Look for an existing review record. Its name is `pr-<number>.md` for a pull request, or `branch-<name>.md` for a branch with every `/` in the name replaced by `-`. It lives in `.claude/reviews/` of the project. Its first line is `Reviewed head: <hash>`.
   - When the recorded hash equals the head, there is nothing new. Tell the user and stop.
   - No record: the range starts at `git merge-base origin/<base branch> <head>`.
   - A record exists: run `git merge-base --is-ancestor <recorded hash> <head>`. When it succeeds, the range starts at the recorded hash. When it fails, the branch was rebased or force pushed, so the range starts at the merge-base as in the first case.
4. Create the review directory `<scratch>/review-pr-<YYYYMMDD-HHMMSS>` and an empty `rejections.md` in it. `<scratch>` is the session's scratchpad directory, or the output of `mktemp -d` when there is none.
5. Dispatch three `sh:code-reviewer` agents in one message, with the aspects `behaviour`, `tests` and `simplicity`. Give each `target` as `<range start>..<head>`, `findings_file` as `<review directory>/round-1/<aspect>.md`, `rejections_file`, and `intent`. The intent is the pull request's title and body, or the user's description for a branch. The reviewers make their own worktrees from the head commit. When a reviewer ends with an error, or its findings file is missing or has no verdict line, dispatch it once more. When that fails too, run step 8, write no review record, and tell the user which aspect has no findings. A missing file is never read as `clean`.
6. Check every finding yourself against the code at the head commit. Read files with `git show <head>:<path>`. Drop each finding you cannot confirm.
7. Save the confirmed findings in the review record.
   - Line 1 is `Reviewed head: <head hash>`.
   - Create `.claude/reviews/` if it is missing. Before the first write, run `git check-ignore -q .claude/reviews/<record name>`. When it exits non-zero, append the line `.claude/reviews/` to the file that `git rev-parse --git-path info/exclude` prints, so the record never shows as untracked.
   - When you updated an existing record, state for each earlier finding whether it is resolved, and keep the earlier findings in the record.
8. Run `git worktree list`. For each of `<review directory>/wt-behaviour`, `<review directory>/wt-tests` and `<review directory>/wt-simplicity` that is still listed, run `git worktree remove --force` on it and say so in your summary. Leave every other worktree alone, because it may belong to another session.
9. Give the user a summary in plain language with the most severe findings first. Say which range you reviewed. For an update, say which earlier findings are resolved. Name the review record's path.
