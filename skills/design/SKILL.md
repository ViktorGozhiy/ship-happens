---
name: design
description: Use when Viktor brings an idea for a feature or a change larger than one small fix, before any plan or code exists.
---

# Design

Turn an idea from Viktor into an approved spec `YYYY-MM-DD-<topic>.md` in the project's directory for specs, then hand it to `sh:plan`. Agents read the code for you. Pass absolute paths to agents.

## Input

An idea from Viktor, or the path of a backlog item. For a backlog item, the item's text is the idea.

## Steps

1. Estimate the size. When the change fits one implementer task and changes no interface that other code depends on, say so and call `sh:quick-fix` with the idea, and with the backlog item path when the input is a backlog item. Otherwise continue.
2. Dispatch `Explore` agents to read the code the idea touches, at most three at a time. They also find out how that code is built, packaged, tested and deployed: the build files, the package manifest, and the container or deploy configuration. The spec's claims about the repository then cover them. Work from their summaries. Read a source file yourself only for a single short lookup.
3. State the problem in a few plain sentences: what is wrong or missing today, and what will be different when the work is done. Ask Viktor in plain text, not with `AskUserQuestion`, whether that is right, and correct it until he agrees. Only then ask Viktor questions with `AskUserQuestion` until the purpose, the constraints and the success criteria are clear. Offer prepared options where options exist. Put independent questions in one form.
4. Prepare two or three approaches and show them to Viktor in plain text, not with `AskUserQuestion`. For each approach give a name, what it does in two or three sentences, and its important advantages and disadvantages. Do this for the approach you recommend too. One line per approach is too little and a wall of text is too much. Viktor may exclude an approach, correct one, or add his own. Only then dispatch `sh:advisor` without a `name`, with a summary of the task and the approaches as Viktor left them, and keep the agent id from the dispatch result. A named agent sends each answer twice, as a message and again inside its idle notice. Discuss with it until you both agree or the disagreement is clear. Send each reply with `SendMessage` to that agent id, and never dispatch a second advisor. Then ask Viktor to choose an approach with `AskUserQuestion`, and give your recommendation. When you and the advisor disagree, show both positions.
5. Write the spec to `<specs directory>/<date>-<topic>.md`. `<specs directory>` is, in this order: the `specs/` subdirectory of a directory that the project's `CLAUDE.md` names for specs and plans together; the directory it names for specs alone; an existing directory of the project that already holds specs, such as `docs/superpowers/specs/`; `docs/specs/`. `<date>` is today as `YYYY-MM-DD`, and `<topic>` is a short lowercase name joined with hyphens. The spec states the goal, what is out of scope, the decisions Viktor made, the decisions you made yourself, the design, what is left to the implementer in its own section, the success criteria and how the result is verified. When the spec removes, renames or changes the signature of a name, it states one rule for the tests that use the name, for example "a test that only passes the removed keyword loses it; a test of the removed behaviour is rewritten to test the behaviour that takes its place". The spec lists no test lines. When the idea is a backlog item, the spec carries two lines after its title and date line: `Backlog item: <path relative to the repository root>`, and either `Covers: the whole item` or `Covers: <which part>; the rest stays open`. The spec's out-of-scope section names the rest. `sh:implement` reads these lines to close the item. Send the spec's absolute path to the same advisor by its agent id with `SendMessage` and resolve its objections yourself, without asking Viktor. Commit the spec. When `git check-ignore -q <spec path>` exits 0, skip the commit and say so in your report.
6. Call `sh:review` with `kind` `spec` and `target` the spec path. Commit the revised spec afterwards, under the same rule for an ignored file. When the review stops at the cap of three full reads, or stops because a findings file is missing, keep the open defects for step 7. Between step 4 and step 7 you do not ask Viktor. Settle review findings yourself, reject a finding that would reverse one of his decisions, and bring every objection you did not settle to step 7.
7. Describe the design to Viktor in a few sentences. Name the decisions that matter, list the decisions you made yourself so that he can check them while he reads, name anything `sh:review` left open, and any disagreement with the advisor. Ask for approval with `AskUserQuestion`. When he asks for changes, revise the spec, commit it under the same rule for an ignored file, and ask again.
8. After approval call `sh:plan` with the spec path. From there to the final report the work runs without Viktor, except at the stops that `sh:plan`, `sh:review` and `sh:implement` define.

## Report

Return the spec path, the review status from `sh:review`, and any disagreement with the advisor that Viktor settled.
