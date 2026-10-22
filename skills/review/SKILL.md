---
name: review
description: Use when a spec, a plan or a branch diff needs an independent review, or when the user asks to review a document or a diff.
---

# Review

Review a spec, a plan or a branch diff with independent agents, fix what they find, and stop at a clean read or at the cap, which is two full reads for `plan` and three for `spec` and `code`.

## Input

- `kind`: `spec`, `plan` or `code`.
- `target`: a document path, or `<base>..<head>` commit hashes for `code`.
- `intent`: what the caller has to check the target against. For a plan it is the spec path. For code it is the spec path and the plan path, or a description of the change. For a spec it may be empty.

## Setup

1. Create the review directory `<scratch>/review-<kind>-<YYYYMMDD-HHMMSS>`. `<scratch>` is the session's scratchpad directory, or the output of `mktemp -d` when there is none.
2. Create an empty `rejections.md` in it.

Each reviewer gets the parameters `target`, `aspect`, `findings_file`, `rejections_file` and `intent`. The agents are `sh:spec-reviewer`, `sh:plan-reviewer` and `sh:code-reviewer`. Round 1 findings files are `<review directory>/round-1/<aspect>.md`. Full reads are `round-2/full.md` and `round-3/full.md`, and `round-4/full.md` for `spec` and `code`.

## Round 1

Dispatch one reviewer per aspect, all in one message.

| Kind | Aspects |
|---|---|
| spec | `repo-claims`, `completeness`, `complexity` |
| plan | `coverage`, `feasibility` |
| code | `behaviour`, `tests`, `simplicity` |

For `spec` and `code` the round also has Codex or the `adversarial` reviewer, as follows. Run at most four Claude agents at a time.

**Codex.** The value of the Codex option is `${user_config.codex_review}`. Use Codex only when that value is exactly `true`. Any other text, including a value that still looks like a reference, means Codex does not take part.

1. Write the prompt to `<review directory>/codex-prompt.txt` with the Write tool. It names the target and the intent, defines a blocking defect as one that leads to wrong behaviour, and asks for the findings file layout of the reviewers. The first line is `VERDICT: clean` or `VERDICT: blocking defects found`. Sections follow for the intent, the blocking defects (each with evidence) and the advice. The prompt asks for these findings as Codex's final reply.
   - For `spec`, the prompt gives the reason: `-o` saves that reply, and the read-only sandbox blocks file writes.
   - For `code`, the layout has a section `## Checks not run` after the advice, with each check Codex could not run and the reason. The prompt gives the reason for the final reply: `-o` saves it outside the worktree. It tells Codex that `<review directory>/wt-codex` is its working root; to install the project's dependencies and run its tests as the project's `CLAUDE.md` or README says; to point a cache that it cannot write at `<review directory>/cache` with the tool's own environment variable; to change nothing outside the worktree, that cache directory and the temporary directory; and to run no command on another host. It says that a dependency that needs the ssh agent, such as a git dependency from a private repository, fails, and that such a failure goes under `## Checks not run`.
2. Run `mkdir -p <review directory>/round-1`. Codex exits 0 without writing the file when the directory is missing.
3. For `spec`, run in the background: `codex exec --sandbox read-only -o <review directory>/round-1/codex.md - < <review directory>/codex-prompt.txt`.
4. For `code`, Codex works in its own worktree with write access and network access, so that it can install the dependencies and run the tests. You create and remove the worktree and initialise its submodules, because the git directory of a linked worktree lies outside the paths Codex may write. Do this only when `codex` is on `PATH`. The command also needs `timeout` from GNU coreutils on `PATH`.
   1. Run `git worktree add --detach <review directory>/wt-codex <head>`, with the `<head>` of `target`. When `<review directory>/wt-codex/.gitmodules` exists, run `git -C <review directory>/wt-codex submodule update --init --recursive`. When either command fails, run no Codex command: Codex counts as skipped, as the rule below says.
   2. Run in the background:

      ```
      timeout 1800 env -u SSH_AUTH_SOCK codex exec --sandbox workspace-write -c sandbox_workspace_write.network_access=true --add-dir "$(uv cache dir)" -C <review directory>/wt-codex -o <review directory>/round-1/codex.md - < <review directory>/codex-prompt.txt
      ```

      Leave out `--add-dir "$(uv cache dir)"` when `uv` is not on `PATH`. `timeout` ends a run that hangs after 1800 seconds. `env -u SSH_AUTH_SOCK` removes the ssh agent from Codex's environment, so that Codex cannot use the agent to reach another host.
   3. After the command ends, whatever its result, run `git worktree remove --force <review directory>/wt-codex`.
5. Wait for the Codex command and for every reviewer of the round before you decide anything about the round.

Codex counts as skipped when `codex` is not on `PATH`, when `git worktree add` or the submodule update of step 4 fails, when the command exits non-zero, when `codex.md` does not exist, or when its first line is not a verdict line. A run that `timeout` ends exits non-zero. When a setup step failed, run `git worktree remove --force <review directory>/wt-codex` if the worktree was created. Then rename any output to `round-1/codex.failed`, report "Codex review skipped" with the reason, and continue with the Claude results. A skipped run is never read as `clean`. Codex is not a Claude agent and does not count toward the limit of four.

**Adversarial reviewer.** When Codex does not take part, or was skipped, add a reviewer with the aspect `adversarial`. Its findings file is `round-1/adversarial.md`. When the option is `true`, wait for Codex first and dispatch this reviewer only after a skipped run.

## Loop

1. Check that `round-1/` holds one `.md` findings file with a verdict line for every aspect you dispatched. When a reviewer returned without its file, dispatch it once more. When the file is still missing, stop and report to the user. A missing file is never read as `clean`. When the first line of every `.md` file in `round-1/` is `VERDICT: clean`, stop. The same check applies to `full.md` in later rounds.

   For `plan`, before you stop at a clean round 1, run `awk '/^## Advice/{f=1; next} /^## /{f=0} f' <review directory>/round-1/feasibility.md | grep '^Missing test:'`. When it prints a line, dispatch `sh:plan-writer` in fix mode once, as step 2 says, with `findings_dir` `<review directory>/round-1`. It applies each `Missing test:` line. Commit the plan as step 2 says, and stop without a further read.
2. Fix. The fixer reads every findings file in the round's directory, checks each finding, fixes the real ones, and appends each rejected one to `rejections.md` as `- <round directory>/<aspect> #<n> <title>: <reason>`.
   - `spec`: you are the fixer.
   - `plan`: dispatch `sh:plan-writer` in fix mode with `plan`, `format` (`${CLAUDE_PLUGIN_ROOT}/skills/plan/plan-format.md`), `findings_dir`, `rejections_file` and `intent`.
   - `code`: dispatch `sh:implementer` in fix mode with `findings_dir`, `rejections_file` and `intent`. It commits its fixes. When it ends with an error or returns a line starting with `blocked: `, stop and report that to the user. Otherwise add the text of each `deviated:` line it returns to the `intent` of every later full reader and of every later fixer, keep the line for the report, then run `git rev-parse HEAD` and use `<base>..<new head>` as the target of the next reader.

   Both agents return one line per finding: `fixed: <title>` or `rejected: <title> (<reason>)`. `sh:implementer` also returns zero or more lines `deviated: <what and why>` and one line per commit, as `git log --oneline` prints it. For `spec` and `plan` you commit the revised document. When `git check-ignore -q <path>` exits 0 for the document, skip the commit and say so in your report.
3. Dispatch one fresh reviewer of the same kind with the aspect `full` and `findings_file` `round-<n>/full.md`, where `<n>` is the next round number. It reads the whole target and `rejections.md` and reports blocking defects only.
4. When its verdict is `clean`, stop. Otherwise go to step 2 with this round's directory.
5. The cap depends on the kind, and it holds when another skill called you.
   - `plan`: round 1, fix, `round-2/full.md`, fix, `round-3/full.md`. When `round-3/full.md` reports a blocking defect, stop and show it to the user.
   - `code`: round 1, fix, `round-2/full.md`, fix, `round-3/full.md`. When that read reports a blocking defect, one more fix and `round-4/full.md` follow without a question. When `round-4/full.md` reports a blocking defect, stop and show the user the open blocking defects as a numbered list.
   - `spec`: round 1, then a fix before each of `round-2/full.md`, `round-3/full.md` and `round-4/full.md`. When `round-4/full.md` reports a blocking defect, stop and show it to the user.

## Report

Return the status, the number of rounds, one line per change made, each `deviated:` line a fixer returned, and the rejected findings with their reasons.

- For `spec` and `plan`, add the advice you did not apply.
- For `code`, add the advice of the review directory, collected as the **Leftovers** action of `sh:backlog` in `${CLAUDE_PLUGIN_ROOT}/skills/backlog/SKILL.md` says for the advice of a code review. When the review stopped at the cap, add the open blocking defects as the numbered list you showed the user.

## Leftovers

When the user called you directly with `kind` `code`, end with the **Leftovers** action of `sh:backlog` after the report. Its sources are the advice of the report, with the path of the review directory, and, when the review stopped at the cap, the open blocking defects. Pass your `intent` and no test command. **Leftovers** writes the items the user names for the backlog on the branch that is checked out.

Fix now is allowed only when all of these hold:

- the review did not stop at the cap;
- the branch that is checked out is not the default branch. The default branch is the output of `git symbolic-ref --short refs/remotes/origin/HEAD` without the `origin/` prefix. When that command fails, fix now is not allowed;
- `git merge-base --is-ancestor <head> HEAD` exits 0 for the `<head>` of your `target`.

You ask no merge question, so after a fix-now run you end with its report.

When another skill called you, or `kind` is `spec` or `plan`, offer no leftovers and ask the user nothing about them. The skill that called you offers them from your report.
