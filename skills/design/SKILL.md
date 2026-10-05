---
name: design
description: Use when Viktor brings an idea for a feature or a change larger than one small fix, before any plan or code exists.
---

# Design

Turn an idea from Viktor into an approved spec in `docs/specs/YYYY-MM-DD-<topic>.md`, then hand it to `sh:plan`. Agents read the code for you. Pass absolute paths to agents.

## Input

An idea from Viktor.

## Steps

1. Estimate the size. When the change fits one implementer task and changes no interface that other code depends on, say so and call `sh:quick-fix` with the idea. Otherwise continue.
2. Dispatch `Explore` agents to read the code the idea touches, at most three at a time. Work from their summaries. Read a source file yourself only for a single short lookup.
3. Ask Viktor questions with `AskUserQuestion` until the purpose, the constraints and the success criteria are clear. Offer prepared options where options exist. Put independent questions in one form.
4. Prepare two or three approaches. Dispatch `sh:advisor` with a summary of the task and the approaches. Discuss with it until you both agree or the disagreement is clear. Send each reply to the same advisor with `SendMessage`, and never dispatch a second one. Then ask Viktor to choose an approach with `AskUserQuestion`, and give your recommendation. When you and the advisor disagree, show both positions.
5. Write the spec to `docs/specs/<date>-<topic>.md`. `<date>` is today as `YYYY-MM-DD`, and `<topic>` is a short lowercase name joined with hyphens. The spec states the goal, what is out of scope, the decisions Viktor made, the design, the success criteria and how the result is verified. Send the spec's absolute path to the same advisor with `SendMessage` and resolve its objections. Commit the spec. When `git check-ignore -q <spec path>` exits 0, skip the commit and say so in your report.
6. Call `sh:review` with `kind` `spec` and `target` the spec path. Commit the revised spec afterwards, under the same rule for an ignored file. When the review stops at the cap of three full reads, or stops because a findings file is missing, keep the open defects for step 7.
7. Describe the design to Viktor in a few sentences. Name the decisions that matter, anything `sh:review` left open, and any disagreement with the advisor. Ask for approval with `AskUserQuestion`. When he asks for changes, revise the spec, commit it, and ask again.
8. After approval call `sh:plan` with the spec path. From there to the final report the work runs without Viktor, except at the stops that `sh:plan`, `sh:review` and `sh:implement` define.

## Report

Return the spec path, the review status from `sh:review`, and any disagreement with the advisor that Viktor settled.
