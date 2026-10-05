---
name: plan
description: Use when a design spec has been approved and needs an implementation plan.
---

# Plan

Turn an approved spec into a reviewed implementation plan with `sh:plan-writer` and `sh:review`, then hand the plan to `sh:implement`. You read no code and you do not write the plan. Pass absolute paths to agents.

## Input

The path of an approved spec.

## Steps

1. Work out the plan path. It is the plans directory plus the spec's file name without a `-design` suffix. The plans directory is, in this order: the directory that the project's `CLAUDE.md` names for plans; the `plans/` subdirectory of a directory it names for specs and plans together; the `plans/` directory next to the spec's directory when that directory is named `specs`; `docs/plans/`. For `docs/specs/2026-10-05-skill-set-design.md` the plan path is `docs/plans/2026-10-05-skill-set.md`. When the plan path is the same as the spec path, stop and tell Viktor.
2. Dispatch `sh:plan-writer` in write mode with `spec`, `plan` and `format`. Use `${CLAUDE_PLUGIN_ROOT}/skills/plan/plan-format.md` as `format`. It returns `PLAN: <plan path>; TASKS: <n>`. When it ends with an error or returns neither that line nor one starting with `blocked: `, dispatch it once more. When that fails too, stop and report to Viktor.
3. When it returns a line starting with `blocked: `, the spec contradicts itself or the code, or cannot be built. No plan was written. Settle the point from your dialogue with Viktor when the dialogue answers it. Otherwise stop and ask Viktor. Once the point is settled, record the answer in the spec, commit the spec, and dispatch `sh:plan-writer` again. When `git check-ignore -q <spec path>` exits 0, skip the commit of the spec and say so in your report.
4. Commit the plan. When `git check-ignore -q <plan path>` exits 0, skip the commit and say so in your report.
5. Call `sh:review` with `kind` `plan`, `target` the plan path, and `intent` the spec path. When the review stops at the cap, or stops because a findings file is missing, show the open defects to Viktor and stop.
6. Read the final plan once. Check that it does not contradict a decision taken with Viktor. When it does, stop and ask Viktor.
7. Call `sh:implement` with the plan path.

## Report

Return the plan path, the number of tasks, the review status from `sh:review`, and any decision you took from the dialogue in step 3.
