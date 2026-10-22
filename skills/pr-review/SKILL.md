---
name: pr-review
description: Use when the user asks to review a pull request by number or a branch by name, or to post named findings of such a review to GitHub.
---

# Pull request review

Review a pull request or a branch with three `sh:code-reviewer` agents, check its merge state and its CI checks, confirm the findings yourself, save the confirmed ones as a numbered review record, summarise them for the user, and post the findings the user names as one GitHub review. Never check out a branch or change a tracked file in the main working tree. Never post to GitHub unless the user explicitly tells you to in this session.

## Input

A pull request number, or a branch name. For a branch the user may also give a description of the change and the name of a base branch. Or the request to post named findings of a pull request, which step 1 handles.

## Steps

1. When the user asks to post named findings of a pull request, and its review record `pr-<number>.md` of step 5 exists, run only this step and step 12. Read the head hash from line 1 of the record; it is the head in step 12. Run `gh pr view <number> --json title,body,baseRefName`, take the base branch from `baseRefName`, and run `git fetch origin <base branch>` and `git fetch origin pull/<number>/head`. When `git cat-file -e <head>^{commit}` fails for the head hash of the record, for example after a force push, say so and post nothing. Create the directory `<scratch>/review-pr-post-<YYYYMMDD-HHMMSS>` for the JSON file of step 12, with `<scratch>` as step 6 says. When no record exists, say so and post nothing. A request to review runs steps 2 to 11, and step 12 when the user names findings to post.
2. Get the head commit.
   - Pull request number: run `git fetch origin pull/<number>/head`.
   - Branch name with no local branch: run `git fetch origin <branch>`.
   - After either fetch, run `git rev-parse FETCH_HEAD` at once, before any other fetch. The output is the head hash.
   - Branch name with a local branch: run `git rev-parse <branch>`, with no fetch.

   Use the head hash in every later step.
3. Find the base branch. For a pull request run `gh pr view <number> --json title,body,baseRefName` and use `baseRefName`. For a branch it is the repository's default branch, which `git symbolic-ref --short refs/remotes/origin/HEAD` prints as `origin/<name>`, unless the user names another. Run `git fetch origin <base branch>`.
4. Check the merge state against the base branch that step 3 fetched. A conflict or a failed check does not stop the review.
   - Run `git merge-tree --write-tree --name-only origin/<base branch> <head>`, also for a branch without a pull request. Exit code 0 means that the head merges without conflicts. Exit code 1 means conflicts: the lines after the first line, up to the first empty line, name the conflicting files. Report any other exit code with its output as the merge state.
   - For a pull request, run `gh pr view <number> --json mergeable,mergeStateStatus`. Report `mergeable` `UNKNOWN` as unknown. `git merge-tree` decides whether the head conflicts.
   - For a pull request, run `gh pr checks <number>` and read its printed output, never its exit code: a pending check, a failed check and a pull request with no checks all exit non-zero. Each line names a check and its state, such as `pass`, `fail`, `pending` or `skipping`. A pull request with no checks prints that no checks were reported. Keep the checks that failed or are pending.
5. Look for an existing review record. Its name is `pr-<number>.md` for a pull request, or `branch-<name>.md` for a branch with every `/` in the name replaced by `-`. It lives in `.claude/reviews/` of the project. Its first line is `Reviewed head: <hash>`.
   - When the recorded hash equals the head, there is nothing new to review. Give the user the merge state of step 4 as the second bullet of step 11 says, say that the head has no new commits since the record, and stop. Change no record.
   - No record: the range starts at `git merge-base origin/<base branch> <head>`.
   - A record exists: run `git merge-base --is-ancestor <recorded hash> <head>`. When it succeeds, the range starts at the recorded hash. When it fails, the branch was rebased or force pushed, so the range starts at the merge-base as in the first case.
6. Create the review directory `<scratch>/review-pr-<YYYYMMDD-HHMMSS>` and an empty `rejections.md` in it. `<scratch>` is the session's scratchpad directory, or the output of `mktemp -d` when there is none.
7. Dispatch three `sh:code-reviewer` agents in one message, with the aspects `behaviour`, `tests` and `simplicity`. Give each `target` as `<range start>..<head>`, `findings_file` as `<review directory>/round-1/<aspect>.md`, `rejections_file`, and `intent`. The intent is the pull request's title and body, or the user's description for a branch. The reviewers make their own worktrees from the head commit. When a reviewer ends with an error, or its findings file is missing or has no verdict line, dispatch it once more. When that fails too, run step 10, write no review record, and tell the user which aspect has no findings. A missing file is never read as `clean`.
8. Check every finding yourself against the code at the head commit. Read files with `git show <head>:<path>`. Drop each finding you cannot confirm. For each confirmed finding, note its path and its line number in `git show <head>:<path>`, or that it has no line. In an update run, find in the same way the path and the line at the head of each earlier finding that is still open.
9. Save the confirmed findings in the review record.
   - Line 1 is `Reviewed head: <head hash>`.
   - Number the findings from 1, most severe first. Write each finding as a heading `### <n>. <severity>: <title>`, then the line `Line: <path>:<line>` or `Line: none`, then the line `State: open` or `State: resolved at <head hash>`, then its text. The severity is `high` for wrong behaviour that users or production would see, `medium` for other wrong behaviour and for a missing test, and `low` for everything else.
   - In an update run, keep the earlier findings with their numbers, and number the findings of this run after the highest earlier number. When the record holds findings without numbers, first number them in their order and write them in the form above. State for each earlier finding whether it is resolved, and set `State: resolved at <head hash>` when it is. Set the `Line:` of each earlier finding that is still open to its path and line from step 8, so that every open finding refers to the head in line 1.
   - Keep the `Posted` lines that step 12 added.
   - Create `.claude/reviews/` if it is missing. Before the first write, run `git check-ignore -q .claude/reviews/<record name>`. When it exits non-zero, append the line `.claude/reviews/` to the file that `git rev-parse --git-path info/exclude` prints, so the record never shows as untracked.
10. Run `git worktree list`. For each of `<review directory>/wt-behaviour`, `<review directory>/wt-tests` and `<review directory>/wt-simplicity` that is still listed, run `git worktree remove --force` on it and say so in your summary. Leave every other worktree alone, because it may belong to another session.
11. Give the user a summary in plain language, in this order:
    - two or three sentences on what the pull request or the branch does and the problem it solves, taken from the intent and the diff;
    - the merge state of step 4: whether the head conflicts with the base branch, with the conflicting files; for a pull request, `mergeable` and `mergeStateStatus`, and the checks that failed or are pending;
    - the findings with the record's numbers and severities, most severe first; for an update, which earlier findings are resolved;
    - the range you reviewed, and the review record's path.
12. Post findings only for a pull request, and only when the user names in this session the numbers of the findings to post, right after a review or after step 1. `<head>` is the hash in line 1 of the review record.
    - Take each named finding from the review record. Do not post a finding whose state is resolved, and say so in the report. When no named finding is left, post nothing.
    - A finding's line is commentable when it is a line on the new side of a hunk, context lines included, in the output of `git diff $(git merge-base origin/<base branch> <head>) <head> -- <path>`.
    - Write the posted text in the language of the pull request's title and body. Start the text of each finding with its number and its title.
    - With the Write tool, write `post-review.json` in the review directory of step 6, or in the directory of step 1:

      ```json
      {
        "commit_id": "<head>",
        "event": "COMMENT",
        "body": "<one sentence that names the reviewed head, then each named finding whose line is not commentable>",
        "comments": [
          { "path": "<path>", "line": <line number>, "side": "RIGHT", "body": "<the finding>" }
        ]
      }
      ```

      `comments` holds one entry for each named finding whose line is commentable, and is empty when there is none. `line` is a number. `body` is never empty.
    - Run `gh api repos/{owner}/{repo}/pulls/<number>/reviews -X POST --input <directory>/post-review.json`. `gh` fills in `{owner}` and `{repo}` from the repository.
    - When that command fails, write `post-review-body.json` in the same directory, with the same `commit_id` and `event`, every named finding in `body`, and no `comments`, and post it with the same command. When that fails too, report the error and the paths of both JSON files, and stop.
    - Report the URL of the review, which is the `html_url` field of the response. Append to the review record the line `Posted <YYYY-MM-DD>: <numbers>: <URL>`.
