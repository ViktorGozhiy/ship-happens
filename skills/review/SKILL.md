---
name: review
description: Use when a spec, a plan or a branch diff needs an independent review, or when Viktor asks to review a document or a diff.
---

# Review

Review a spec, a plan or a branch diff with independent agents, fix what they find, and stop at a clean read or at the cap of three full reads.

## Input

- `kind`: `spec`, `plan` or `code`.
- `target`: a document path, or `<base>..<head>` commit hashes for `code`.
- `intent`: what the caller has to check the target against. For a plan it is the spec path. For code it is the spec path and the plan path, or a description of the change. For a spec it may be empty.

## Setup

1. Create the review directory `<scratch>/review-<kind>-<YYYYMMDD-HHMMSS>`. `<scratch>` is the session's scratchpad directory, or the output of `mktemp -d` when there is none.
2. Create an empty `rejections.md` in it.

Each reviewer gets the parameters `target`, `aspect`, `findings_file`, `rejections_file` and `intent`. The agents are `sh:spec-reviewer`, `sh:plan-reviewer` and `sh:code-reviewer`. Round 1 findings files are `<review directory>/round-1/<aspect>.md`. Full reads are `round-2/full.md` to `round-4/full.md`.

## Round 1

Dispatch one reviewer per aspect, all in one message.

| Kind | Aspects |
|---|---|
| spec | `repo-claims`, `completeness`, `complexity` |
| plan | `coverage`, `feasibility` |
| code | `behaviour`, `tests`, `simplicity` |

For `spec` and `code` the round also has Codex or the `adversarial` reviewer, as follows. Run at most four Claude agents at a time.

**Codex.** The value of the Codex option is `${user_config.codex_review}`. Use Codex only when that value is exactly `true`. Any other text, including a value that still looks like a reference, means Codex does not take part.

1. Write the prompt to `<review directory>/codex-prompt.txt` with the Write tool. It names the target and the intent, defines a blocking defect as one that leads to wrong behaviour, and asks for the findings file layout of the reviewers. The first line is `VERDICT: clean` or `VERDICT: blocking defects found`. Sections follow for the intent, the blocking defects (each with evidence) and the advice. The prompt asks for these findings as Codex's final reply, because `-o` saves that reply and the read-only sandbox blocks file writes.
2. Run `mkdir -p <review directory>/round-1`. Codex exits 0 without writing the file when the directory is missing.
3. Run in the background: `codex exec --sandbox read-only -o <review directory>/round-1/codex.md - < <review directory>/codex-prompt.txt`.
4. Wait for this command and for every reviewer of the round before you decide anything about the round.

Codex counts as skipped when `codex` is not on `PATH`, when the command exits non-zero, when `codex.md` does not exist, or when its first line is not a verdict line. Then rename any output to `round-1/codex.failed`, report "Codex review skipped" with the reason, and continue with the Claude results. A skipped run is never read as `clean`. Codex is not a Claude agent and does not count toward the limit of four.

**Adversarial reviewer.** When Codex does not take part, or was skipped, add a reviewer with the aspect `adversarial`. Its findings file is `round-1/adversarial.md`. When the option is `true`, wait for Codex first and dispatch this reviewer only after a skipped run.

## Loop

1. Check that `round-1/` holds one `.md` findings file with a verdict line for every aspect you dispatched. When a reviewer returned without its file, dispatch it once more. When the file is still missing, stop and report to Viktor. A missing file is never read as `clean`. When the first line of every `.md` file in `round-1/` is `VERDICT: clean`, stop. The same check applies to `full.md` in later rounds.
2. Fix. The fixer reads every findings file in the round's directory, checks each finding, fixes the real ones, and appends each rejected one to `rejections.md` as `- <round directory>/<aspect> #<n> <title>: <reason>`.
   - `spec`: you are the fixer.
   - `plan`: dispatch `sh:plan-writer` in fix mode with `plan`, `format` (`${CLAUDE_PLUGIN_ROOT}/skills/plan/plan-format.md`), `findings_dir`, `rejections_file` and `intent`.
   - `code`: dispatch `sh:implementer` in fix mode with `findings_dir`, `rejections_file` and `intent`. It commits its fixes. Afterwards run `git rev-parse HEAD` and use `<base>..<new head>` as the target of the next reader.

   Both agents return one line per finding: `fixed: <title>` or `rejected: <title> (<reason>)`. For `spec` and `plan` you commit the revised document. When `git check-ignore -q <path>` exits 0 for the document, skip the commit and say so in your report.
3. Dispatch one fresh reviewer of the same kind with the aspect `full` and `findings_file` `round-<n>/full.md`, where `<n>` is the next round number. It reads the whole target and `rejections.md` and reports blocking defects only.
4. When its verdict is `clean`, stop. Otherwise go to step 2 with this round's directory.
5. Three full reads are the cap. When the third still reports blocking defects, stop and show them to Viktor. This holds in the autonomous part of the cycle too.

## Report

Return the status, the number of rounds, one line per change made, the rejected findings with their reasons, and the advice you did not apply.
