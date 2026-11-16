---
name: pr-review
description: Use when the user asks to review a pull request by number or a branch by name, to post named findings of such a review to GitHub, to fix named findings on the branch of a pull request, to check the review comments of others on a pull request, or to reply in their threads or resolve them.
---

# Pull request review

Review a pull request or a branch with three `sh:code-reviewer` agents, check its merge state and its CI checks, confirm the findings yourself, save the confirmed ones as a numbered review record, summarise them for the user, and post the findings the user names as one GitHub review. At the user's request, fix named findings on the branch of a pull request, in a worktree of its own. Check the open review threads of others on a pull request against the head, and give each a verdict. Reply in those threads or resolve them only when the user names them in this session. Never check out a branch or change a tracked file in the main working tree. Never post to GitHub unless the user explicitly tells you to in this session. "ok" after a summary of step 11 counts as the user's word to post the findings that the summary proposes to post.

## Input

A pull request number, or a branch name. For a branch the user may also give a description of the change and the name of a base branch. Or the request to post or to fix named findings of a pull request, to check the review comments of others on a pull request, or to reply in their threads or resolve them, which step 1 handles.

## Steps

1. When the user asks to post named findings of a pull request, and its review record `pr-<number>.md` of step 5 exists, run only this step and step 12. Read the head hash from line 1 of the record; it is the head in step 12. Run `gh pr view <number> --json title,body,baseRefName`, take the base branch from `baseRefName`, and run `git fetch origin <base branch>` and `git fetch origin pull/<number>/head`. When `git cat-file -e <head>^{commit}` fails for the head hash of the record, for example after a force push, say so and post nothing. Create the directory `<scratch>/review-pr-post-<YYYYMMDD-HHMMSS>` for the JSON file of step 12, with `<scratch>` as step 6 says. When no record exists, say so and post nothing. When the user asks to fix named findings of a pull request, run only the section `## Fix named findings` of this file. A request to review runs steps 2 to 11, and step 12 when the user names findings to post or answers "ok" to the summary. When the user refers to a finding by the number in a posted review, for example because the author replied to it, take its record number from the `Posted` line of that review, and tell the user the record number. When the user asks to check the review comments of others on a pull request without a review, run step 2 for the head hash, then only the section `## Review threads`. When the user asks to reply in the threads of others or to resolve them, run step 2 for the head hash, then only the section `## Replies in threads`.
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

   For a pull request, run the section `## Review threads` after this step, also when step 5 then stops.
5. Look for an existing review record. Its name is `pr-<number>.md` for a pull request, or `branch-<name>.md` for a branch with every `/` in the name replaced by `-`. It lives in `.claude/reviews/` of the project. Its first line is `Reviewed head: <hash>`.
   - When the recorded hash equals the head, there is nothing new to review. Give the user the merge state of step 4 as the second bullet of step 11 says, say that the head has no new commits since the record, list the threads of `## Review threads` as step 11 does, and stop. Change no record.
   - No record: the range starts at `git merge-base origin/<base branch> <head>`.
   - A record exists: run `git merge-base --is-ancestor <recorded hash> <head>`. When it succeeds, the range starts at the recorded hash. When it fails, the branch was rebased or force pushed, so the range starts at the merge-base as in the first case.
6. Create the review directory `<scratch>/review-pr-<YYYYMMDD-HHMMSS>` and an empty `rejections.md` in it. `<scratch>` is the session's scratchpad directory, or the output of `mktemp -d` when there is none.
7. Dispatch three `sh:code-reviewer` agents in one message, with the aspects `behaviour`, `tests` and `simplicity`. Give each `target` as `<range start>..<head>`, `findings_file` as `<review directory>/round-1/<aspect>.md`, `rejections_file`, and `intent`. The intent is the pull request's title and body, or the user's description for a branch. The reviewers make their own worktrees from the head commit. When a reviewer ends with an error, or its findings file is missing or has no verdict line, dispatch it once more. When that fails too, run step 10, write no review record, and tell the user which aspect has no findings. A missing file is never read as `clean`.
8. Check every finding yourself against the code at the head commit. Read files with `git show <head>:<path>`. Drop each finding you cannot confirm. For each confirmed finding, note its path and its line number in `git show <head>:<path>`, or that it has no line. In an update run, find in the same way the path and the line at the head of each earlier finding that is still open.
9. Save the confirmed findings in the review record.
   - Line 1 is `Reviewed head: <head hash>`.
   - Number the findings from 1, most severe first. Write each finding as a heading `### <n>. <severity>: <title>`, then the line `Line: <path>:<line>` or `Line: none`, then the line `State: open` or `State: resolved at <head hash>`, then its text. The severity is `high` for wrong behaviour that users or production would see, `medium` for other wrong behaviour and for a missing test, and `low` for everything else.
   - In an update run, keep the earlier findings with their numbers, and number the findings of this run after the highest earlier number. When the record holds findings without numbers, first number them in their order and write them in the form above. State for each earlier finding whether it is resolved, and set `State: resolved at <head hash>` when it is. Set the `Line:` of each earlier finding that is still open to its path and line from step 8, so that every open finding refers to the head in line 1.
   - Keep the `Posted` lines that step 12 added. Their record numbers stay valid, because the findings keep their numbers.
   - Create `.claude/reviews/` if it is missing. Before the first write, run `git check-ignore -q .claude/reviews/<record name>`. When it exits non-zero, append the line `.claude/reviews/` to the file that `git rev-parse --git-path info/exclude` prints, so the record never shows as untracked.
10. Run `git worktree list`. For each of `<review directory>/wt-behaviour`, `<review directory>/wt-tests` and `<review directory>/wt-simplicity` that is still listed, run `git worktree remove --force` on it and say so in your summary. Leave every other worktree alone, because it may belong to another session.
11. Give the user a summary in plain language, in this order:
    - two or three sentences on what the pull request or the branch does and the problem it solves, taken from the intent and the diff;
    - the merge state of step 4: whether the head conflicts with the base branch, with the conflicting files; for a pull request, `mergeable` and `mergeStateStatus`, and the checks that failed or are pending;
    - the findings with the record's numbers and severities, most severe first, each with a proposal, `post` or `skip`, and its reason in one clause. Propose `post` when posting the finding gives this pull request a benefit now, such as a fix of wrong behaviour or of a missing test, and `skip` otherwise. A finding that a `Posted` line lists, and a resolved finding, get no proposal. For an update, say which earlier findings are resolved; for each finding that a `Posted` line lists, give the review it was posted in and the number it got there;
    - below the findings, the answer forms: "ok" posts the findings proposed `post`, and numbers name the findings to post;
    - for a pull request, the threads of `## Review threads`: each `T` number with its author, its verdict and its reason;
    - the range you reviewed, and the review record's path.
12. Post findings only for a pull request, and only when the user names in this session the numbers of the findings to post, right after a review or after step 1, or answers "ok" to a summary of step 11, which names the findings proposed `post`. `<head>` is the hash in line 1 of the review record. A `T` item of the threads file is never posted.
    - The user names findings by their numbers in the review record, and those stay record numbers in everything you say to the user and write in the record. Take each named finding from the review record. Do not post a finding whose state is resolved, and say so in the report with its record number. When no named finding is left, post nothing.
    - A finding's line is commentable when it is a line on the new side of a hunk, context lines included, in the output of `git diff $(git merge-base origin/<base branch> <head>) <head> -- <path>`.
    - Write the posted text in the language of the pull request's title and body. The author of the pull request has not seen the review record, so the posted text never shows a record number. Number the findings that you post from 1, in the order of their record numbers, and start the text of each finding, in `comments` and in `body`, with its posted number and its title, as `<posted number>. <title>`. A review that you post later starts at 1 again.
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
    - When that command fails, write `post-review-body.json` in the same directory, with the same `commit_id` and `event`, every named finding in `body` with the same posted numbers, and no `comments`, and post it with the same command. When that fails too, report the error and the paths of both JSON files, and stop.
    - Report the URL of the review, which is the `html_url` field of the response, and for each posted finding the posted number with its record number. Append to the review record the line `Posted <YYYY-MM-DD>: <pairs>: <URL>`, where `<pairs>` has one `<posted number>=<record number>` for each posted finding, in posted order, separated by `, `. For example, `Posted 2026-11-01: 1=2, 2=9: https://github.com/<owner>/<repo>/pull/7#pullrequestreview-1` says that the review posted record finding 2 as number 1 and record finding 9 as number 2.

## Review threads

Check the review threads and the review bodies of others on a pull request against the head, give each remark a verdict, and write the result to a threads file. You do this yourself and dispatch no agent. `<head>` is the head hash of step 2 of `## Steps`.

1. Run `gh api user --jq .login`. The threads that this login started are the posted findings of the review record, so the check leaves them out.
2. Create `<scratch>/review-pr-threads-<YYYYMMDD-HHMMSS>`, with `<scratch>` as step 6 of `## Steps` says. It is `<threads directory>` below. Read the threads:

   ```
   gh api graphql --paginate -F owner='{owner}' -F name='{repo}' -F number=<number> -f query='
   query($owner: String!, $name: String!, $number: Int!, $endCursor: String) {
     repository(owner: $owner, name: $name) {
       pullRequest(number: $number) {
         reviewThreads(first: 50, after: $endCursor) {
           pageInfo { hasNextPage endCursor }
           nodes {
             id isResolved isOutdated path line originalLine
             comments(first: 100) {
               pageInfo { hasNextPage endCursor }
               nodes {
                 databaseId url body createdAt
                 author { login __typename }
                 replyTo { databaseId }
                 diffHunk
                 originalCommit { oid }
               }
             }
           }
         }
       }
     }
   }' > <threads directory>/threads.json
   ```

   `--paginate` follows the cursor of `reviewThreads`, because its `pageInfo` comes before the comments, and the file holds one JSON document per page. When the comments of a thread have `hasNextPage` true, read the rest of them:

   ```
   gh api graphql --paginate -F id=<thread id> -f query='
   query($id: ID!, $endCursor: String) {
     node(id: $id) {
       ... on PullRequestReviewThread {
         comments(first: 100, after: $endCursor) {
           pageInfo { hasNextPage endCursor }
           nodes { databaseId url body createdAt author { login __typename } replyTo { databaseId } diffHunk originalCommit { oid } }
         }
       }
     }
   }'
   ```

   Read the reviews:

   ```
   gh api graphql --paginate -F owner='{owner}' -F name='{repo}' -F number=<number> -f query='
   query($owner: String!, $name: String!, $number: Int!, $endCursor: String) {
     repository(owner: $owner, name: $name) {
       pullRequest(number: $number) {
         reviews(first: 100, after: $endCursor) {
           pageInfo { hasNextPage endCursor }
           nodes { url body state author { login __typename } commit { oid } }
         }
       }
     }
   }' > <threads directory>/reviews.json
   ```

3. Keep the threads that are not resolved and whose first comment is not by the login of step 1. A bot counts like a person.
4. Check each kept thread against the head as step 8 of `## Steps` checks a finding, with `git show <head>:<path>`. For an outdated thread, read the code that the comment was about from its `diffHunk` and from `git show <oid>:<path>` with the `oid` of its `originalCommit`, then find the same code at the head. The verdict is `valid` when the remark holds at the head, `wrong` when it does not apply, or `fixed` when the head does not have the problem, with a reason in one clause.
5. Read the bodies of the reviews by other logins. Give each remark in them that has no thread a verdict in the same way.
6. Write `.claude/reviews/pr-<number>-threads.md`. Line 1 of `pr-<number>.md` claims a code review of a head, so the check never writes the review record.
   - Line 1 is `Checked head: <head hash>`.
   - Each thread or remark gets a heading `### T<n>. <verdict>: <title>`. Then follows the line `Thread: <url>` with the URL of the first comment of the thread, or, for a remark in a review body, the line `Review: <url>` with the URL of the review and the line `Quote: <the first sentence of the remark>`. Then follow `Author: <login>`, `Line: <path>:<line>` with its line at the head or `Line: none`, `State: open`, and the text with the reason.
   - A later check keeps each earlier `T` number: a thread by its URL, a remark in a review body by its review URL and its quote. It numbers new items after the highest number. It keeps the `Replied` and `Resolved` lines, and a `State: resolved at <hash>` that a fix set. It changes a state only from `open`: to `State: resolved on GitHub` when the thread is resolved on GitHub, or to `State: gone` when the review body lacks the quote. An item in such a state is not fixed and not replied to. For each item whose state stays `open`, it writes the verdict, the line and the reason of this check.
   - Create `.claude/reviews/` if it is missing. Before the first write, apply the rule of step 9 of `## Steps` for `git check-ignore` and `info/exclude` to this file.
7. Give the user the list as step 11 of `## Steps` says: each `T` number with its author, its verdict and its reason.

## Replies in threads

Reply in the threads of others, or resolve them, only on the word of the user in this session that names items of the threads file `.claude/reviews/pr-<number>-threads.md` of `## Review threads`, because a reply on GitHub cannot be taken back. `<head>` is the head hash of step 2 of `## Steps`.

1. When the threads file is missing, or its `Checked head:` differs from `<head>`, run `## Review threads` first and show its list. Reply and resolve nothing until the user names `T` numbers from that list.
2. When the file is current, the user names items by their `T` numbers. A request that names the threads by author, or as "all", such as "ответь в тредах бота и закрой их", names every `T` item of that author, or every `T` item, except those with `State: resolved on GitHub` or `State: gone`. A named item in one of those two states is left out, and the report says so.
3. An item with `Review:` has no thread. It gets no reply and no resolve, and the report says so.
4. A reply follows the verdict and the state: for `wrong`, why the remark does not apply; for `fixed` or `State: resolved at <hash>`, the commit that fixed it; for `valid` with `State: open`, that it is not fixed yet. Write it in the language of the thread. Send it to the first comment of the thread, whose `<databaseId>` is the number after `discussion_r` in the `Thread:` URL:

   ```
   gh api repos/{owner}/{repo}/pulls/<number>/comments/<databaseId>/replies -X POST -f body=<text>
   ```

5. Resolving skips a `valid` item with `State: open`, and the report says so. To resolve another item, run the threads query of step 2 of `## Review threads` again, take the `id` of the thread whose first comment has the URL of the `Thread:` line, and run:

   ```
   gh api graphql -F threadId=<id> -f query='mutation($threadId: ID!) { resolveReviewThread(input: {threadId: $threadId}) { thread { isResolved } } }'
   ```

6. After each reply or resolve, append to the item in the threads file the line `Replied <YYYY-MM-DD>: <url>`, with the `html_url` of the reply that the command returned, or `Resolved <YYYY-MM-DD>`.
7. Report the `T` numbers you replied to and those you resolved, and each named item you left out with its reason.

## Fix named findings

Fix the findings the user names on the branch of a pull request, in a worktree of its own, and ask one question: whether to push. A branch without a pull request is out of scope. The user may name record numbers, `T` numbers of the threads file of `## Review threads`, or both. The opening rule on the main working tree covers this section. Step numbers in this section refer to this section, unless they name `## Steps`.

1. When the user names record numbers and no review record `pr-<number>.md` exists, or names `T` numbers and no threads file `pr-<number>-threads.md` exists, say so and fix nothing. `T` numbers need only the threads file.
2. Run `git fetch origin pull/<number>/head` and `git rev-parse FETCH_HEAD`. The output is `<head>`. When the user names record numbers and the hash differs from line 1 of the record, stop and propose an update review, because the record's lines refer to another head. When the user names `T` numbers and the hash differs from `Checked head:` of the threads file, stop and propose a new check of the threads, for the same reason. A request with both kinds stops when the two heads differ.
3. Take the named findings from the record. The numbers are record numbers, as for posting. A finding whose state is resolved, and a number the record does not hold, is left out, and the report says so. Take the named `T` items from the threads file. Only an item with the verdict `valid` and `State: open` is fixed. Any other named `T` item, and a `T` number the file does not hold, is left out, and the report says so. When no named finding and no `T` item is left, fix nothing.
4. Run `gh pr view <number> --json title,body,baseRefName,headRefName,isCrossRepository`. When `isCrossRepository` is true, say that the branch lies in a fork, and stop. Take the full test command as the last sentence of step 2 of `${CLAUDE_PLUGIN_ROOT}/skills/quick-fix/SKILL.md` says.
5. Create `<scratch>/review-pr-fix-<YYYYMMDD-HHMMSS>`, with `<scratch>` as step 6 of `## Steps` says, and run `git worktree add --detach <that directory>/wt-fix <head>`. When `<that directory>/wt-fix/.gitmodules` exists, run `git -C <that directory>/wt-fix submodule update --init --recursive`. Run the setup command that the project's `CLAUDE.md` or README names in `<that directory>/wt-fix`, with `cd <that directory>/wt-fix &&` at its start. Copy from the main working tree into `<that directory>/wt-fix` each git-ignored file that the test command reads, such as `.env`, because without it tests may skip silently and the run looks green. Keep `git rev-parse HEAD` and `git status --short` of the main working tree.
6. Load `sh:quick-fix` with the Skill tool, and run the section `## Pull request mode` of `${CLAUDE_PLUGIN_ROOT}/skills/quick-fix/SKILL.md` with the worktree, the full text of the named findings and `T` items, the intent (the title and the body of the pull request) and the test command.
7. Compare `git rev-parse HEAD` and `git status --short` of the main working tree with the kept values. When they changed, say so in the report and go on: another session may work there.
8. Take the mode's result. After `stopped: size: <reason>` no commit exists: remove the worktree with `git worktree remove --force`, report the reason and stop. After any other `stopped: <reason>`, run the `git switch -c` command of step 11 when the head hash of the `stopped:` line, or else `git -C <worktree> rev-parse HEAD`, differs from `<head>`, with the hash of the line as the start point of the new branch, keep the worktree, offer no push and stop. The report gives the reason, the worktree's path, the head hash and the branch that the command created. When the command fails, the report says what step 11 says of that failure.
9. After `done`, ask with `AskUserQuestion`: push to the branch of the pull request, or leave it.
10. On "push": run `git -C <worktree> push origin HEAD:<headRefName>`. Never force. Git rejects the push when the branch moved: run the `git switch -c` command of step 11, keep the worktree and stop. The report gives the error of the push, the worktree's path, the head hash and the branch that the command created. When the command fails, the report says what step 11 says of that failure. After a push, set `State: resolved at <new head>` for each fixed finding in the record, except a finding that a `deviated:` line names, and for each fixed `T` item in the threads file that no `deviated:` line names, and remove the worktree with `git worktree remove --force`.
11. On "leave": run `git -C <worktree> switch -c pr-<number>-fixes`, so that a ref holds the commits after the scratch directory is gone. Keep the worktree, and report its path, the branch and the head hash. When that command fails, the report gives its error, the worktree's path and the head hash, and names no branch, because no ref holds the commits. The user then has to save them. Stop.
