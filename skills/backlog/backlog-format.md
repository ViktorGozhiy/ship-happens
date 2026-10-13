# Backlog format

A backlog item is one Markdown file about one deferred task: a fix, a problem found while doing something else, or an idea to research. The main session writes, updates and closes items itself, and no agent writes them. An item is 30 to 80 lines.

## Directory

The backlog directory is the directory that the project's `CLAUDE.md` names for the backlog, else `docs/backlog/`, relative to the repository root.

The backlog is git-ignored when `git check-ignore -q <backlog directory>/` exits 0. Keep the trailing slash: without it, a pattern such as `docs/backlog/` does not match when the directory is missing from the working tree. An ignored directory is not checked out into a git worktree. So when the backlog is git-ignored and the session works in a git worktree, the backlog directory is in the main working tree, which is the first path that `git worktree list` prints.

An item is a `.md` file directly in the backlog directory. Closed items are in `<backlog directory>/closed/`. Other subdirectories hold no items, only reference documents, such as `docs/backlog/<topic>/`.

## File name

`YYYY-MM-DD-<slug>.md`: the date the item was raised, then a short lowercase slug of the problem joined with hyphens, for example `2026-10-13-gas-model-ignores-base-fee.md`. A closed item keeps its file name.

## Head

The head is the lines from the H1 up to the first line that starts with `## `. Read it with `sed '/^## /q' <item>`.

- Line 1 is `# <the problem as a sentence>`.
- After a blank line comes the status line, one paragraph that may wrap: `Status: <state>, priority <high|normal|low>. Raised <YYYY-MM-DD> <source>.`
  - `<state>` is `open`, or `deferred by Viktor <YYYY-MM-DD> until <condition>`.
  - `<source>` says where the item came from, for example `in the branch review of <branch>`, `by Viktor`, `while <what the session was doing>`, or `from the Deferred section of <spec path>`.
- For each partial fix, a line `Partly done <YYYY-MM-DD> on <branch>: <what was done>.` follows the status line, after any earlier `Partly done` line.
- On a closed item, the line `Closed <YYYY-MM-DD>: <outcome>.` comes before the status line.

Each of these lines is its own paragraph, with a blank line before it. The status line is the only place for the state and the priority.

The head of a closed item that was partly done before it was closed:

```markdown
# The gas model ignores the base fee on Arbitrum.

Closed 2026-10-20: fixed on fix/gas-base-fee.

Status: open, priority high. Raised 2026-10-13 in the branch review of wip/gas-model.

Partly done 2026-10-15 on fix/gas-l1-fee: the L1 part of the fee is included.
```

## Priority

- `high`: wrong behaviour that users or production see, or work that blocks other work.
- `normal`: everything else that has to be done.
- `low`: cosmetic, rare, or research with no deadline.

The writer proposes the priority and tells Viktor the reason in one sentence. The reason is not written into the item. When Viktor corrects the priority, the status line takes his value.

## Sections

Required:

- `## The problem`: what happens, with file paths and line numbers, or commands, as evidence.
- `## What to do`: the steps, or numbered options with a recommended one.
- `## Done when`: what has to be true to close the item. A close and a partial fix are checked against it.

Optional: `## Why it matters`, `## Options`, `## Open questions`, and `## Related` with links to other items. An item that concerns another repository names it in `## Related`.

An open question stays an open question. Never write it as a decision.

## Updates

An update does one of these things and keeps everything else:

- it rewrites the status line, for example to change the priority or to set the state `deferred by Viktor <YYYY-MM-DD> until <condition>`;
- it adds a `Partly done` line;
- it adds a dated section `## Update <YYYY-MM-DD>` at the end of the item.

## Closing

An item is never deleted.

1. An item under `closed/` is closed. Do not close it again.
2. An item outside `closed/` whose head already records its close, in this format or in an old one such as `**Closed:** 2026-10-10` or `Status: closed 2026-10-04, fixed on …`, gets no second `Closed` line and no second `## Resolution`. Only move it with its references, as below. Only moving an item does not touch its head, so the rule for old items does not apply.
3. Any other item: when it has no status line of this format, first give it one, as the section on old items says. Write the line `Closed <YYYY-MM-DD>: <outcome>.` before the status line, and keep the status line as it was. `<outcome>` is one of `fixed on <branch>`, `retracted: <why>`, `superseded by <path>`, `dropped: <why>`. Append a section `## Resolution` at the end of the item. It says what was done, names the commits or the spec, and lists what stays open. Then move the item with its references.

Moving an item with its references:

- Tracked backlog: run `mkdir -p <backlog directory>/closed` and `git mv <item> <backlog directory>/closed/<file name>`. Find every tracked file that names the item's file name with `git grep -l <file name>`, and change each of those references so that it points to the file under `closed/`. The move and the changed references go into one commit.
- Git-ignored backlog: run `mkdir -p <backlog directory>/closed` and move the file with `mv`. Find the other items of the backlog that name it with `grep -rl <file name> <backlog directory>`, and change only those. Tracked files keep the old path, so that closing leaves no uncommitted change.

References in code, tests, scripts and configuration change too, such as a path in `src/app/config.py`. When the close commit changes a file that is not a `.md` file, the report of the skill that made the commit names the commit as not reviewed and lists those files.

## Old items

An item without the status line of this format is an old item. Read it as text. Its state and priority come from whatever header it has, and a missing priority is "not set". In some backlogs the state of old items is in body sections such as `## Status 2026-09-10, later`; the list of open items does not see it.

When an update or a close touches an old item, put the status line of this format after the H1, and keep the old header lines below the status line. Take the state, the date raised and the source from the old header or the file name. When the date is not known, use the date of the file's first commit, from `git log --diff-filter=A --follow --format=%as -- <item> | tail -n 1`, or in a git-ignored backlog the date of its last change, from `date -r <item> +%F`. When the source is not known, end the status line after the date. When the item has no priority, propose one and tell Viktor the reason in one sentence, as for an item being written.

## Commits

- Writing an item: `docs(backlog): <the H1 sentence>`.
- An update: `docs(backlog): update <file name without date and .md>; <what changed>`.
- A close: `docs(backlog): close <file name without date and .md>; <outcome>`.

When `git check-ignore -q <item path>` exits 0, make no commit and say so in the report.
