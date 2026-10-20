# ship-happens

Skills and agents for Claude Code that take a change from an idea to a reviewed, merged branch. The plugin is called `sh`, so its skills are named `sh:design`, `sh:plan` and so on.

The main path starts with `sh:design`. It turns an idea into a spec that you approve, and `sh:review` checks the spec. `sh:plan` turns the spec into an implementation plan, and `sh:review` checks the plan. `sh:implement` carries out the plan with one implementer agent, has the whole branch reviewed once, runs the full test command and reports to you. After your approval of the spec the work runs without you, except at the points where a skill stops to ask.

The side paths are `sh:quick-fix` for a small change, `sh:debugging` to find the root cause of a bug before anyone fixes it, `sh:pr-review` to review a pull request or a branch, and `sh:backlog` to keep a list of deferred work.

## Skills

| Skill | When to use it |
|---|---|
| `sh:design` | You have an idea for a feature or a change larger than one small fix. It reads the code, agrees the problem with you, compares two or three approaches with the `advisor` agent, writes a spec, has it reviewed and asks for your approval. Then it calls `sh:plan`. Small work goes to `sh:quick-fix`. |
| `sh:review` | A spec, a plan or a branch diff needs an independent review. Reviewers write findings, a fixer corrects the real ones, and a fresh reviewer reads the result. It stops at a clean read or at a cap of two full reads for a plan and three for a spec or a diff. Other skills call it; you can call it directly. |
| `sh:plan` | A spec is approved and needs an implementation plan. The `plan-writer` agent writes the plan, `sh:review` checks it, and then `sh:implement` starts. |
| `sh:implement` | A reviewed plan is ready. One `implementer` agent carries out the tasks in order, then `sh:review` reads the whole branch, the full test command runs on the final tree, and you get a report and a choice: merge, open a pull request, or leave the branch. |
| `sh:quick-fix` | You ask for a small change that fits one task and changes no interface that other code depends on. It works on a branch `fix/<slug>`, has the change reviewed and tested, and asks what to do with the branch. |
| `sh:debugging` | A bug, a failing test or unexpected behaviour needs its root cause found. It writes no test and no fix. It ends with the root cause, the evidence, and a description of a test that fails because of the cause, and hands that to `sh:quick-fix` or `sh:design`. |
| `sh:pr-review` | You ask to review a pull request by number or a branch by name. Three code reviewers read the diff, the skill confirms their findings itself, and it saves them as a review record in `.claude/reviews/`. It does not check out the branch and posts nothing to GitHub unless you tell it to. |
| `sh:backlog` | You want to write something into the backlog, list or prioritise open items, change, defer or close one, or take one into work. Each item is one Markdown file. At the end of `sh:review`, `sh:quick-fix` and `sh:implement` it also offers the leftovers of the session as backlog items. |

## Agents

The skills dispatch these agents. You do not call them yourself.

| Agent | Model | What it does |
|---|---|---|
| `advisor` | opus | Gives a second opinion on approaches and on a spec, and keeps its position through a dialogue. Used by `sh:design`. |
| `spec-reviewer` | opus | Reviews a spec for one aspect, or reads it in full for blocking defects, and writes a findings file. |
| `plan-writer` | opus | Writes an implementation plan from a spec and the code, or revises a plan against review findings. |
| `plan-reviewer` | opus | Reviews a plan for one aspect, or reads it in full, and writes a findings file. |
| `implementer` | sonnet | Carries out a reviewed plan, or one small change test first, or fixes a list of review findings, and commits. |
| `code-reviewer` | opus | Reviews a diff between two commits for one aspect, or reads it in full, running checks in its own git worktree. |

## Installation

In Claude Code:

```
/plugin marketplace add ViktorGozhiy/ship-happens
/plugin install sh@ship-happens
```

Claude Code loads agent definitions when it starts. Restart Claude Code after you install or update the plugin, or the skills will not find the agents.

## Codex review

The plugin has one option, `codex_review`. It is a boolean and is off by default.

When it is on, the first round of a spec review and of a branch review also sends the target to Codex, run as `codex exec --sandbox read-only`. Codex gets the path of the spec or the commit range, and the intent of the review, and reads the files. This sends your specs and branch diffs to an external service, so turn the option on only when your project allows that. The `codex` CLI must be on `PATH`.

When the option is off, an extra Claude reviewer with the aspect `adversarial` takes the place of Codex in the first round. The same happens when Codex is skipped. Codex counts as skipped when `codex` is not on `PATH`, when the command exits with an error, or when it writes no findings file with a verdict on its first line. The skill then reports "Codex review skipped" with the reason, adds the `adversarial` reviewer, and never reads a skipped run as a clean review. Plan reviews do not use Codex.

## What the skills assume about a project

- The project is a git repository. The skills commit specs, plans, code and backlog items, and they stop and ask when the working tree has uncommitted changes. `sh:implement` creates a branch named after the plan file, and `sh:quick-fix` creates `fix/<slug>`.
- The default branch is read with `git symbolic-ref --short refs/remotes/origin/HEAD`, so the repository needs an `origin` remote with its HEAD set. When that command fails, `sh:implement` asks you for the branch, and the leftovers action offers no fix-now run. `sh:pr-review` fetches from `origin`, and it needs the `gh` CLI to read a pull request by number.
- Specs go to `<date>-<topic>.md` in the first of these that applies: the `specs/` subdirectory of a directory that the project's `CLAUDE.md` names for specs and plans together; a directory that `CLAUDE.md` names for specs alone; an existing directory of the project that already holds specs, such as `docs/superpowers/specs/`; `docs/specs/`.
- Plans go to the spec's file name without the `-design` suffix, in the first of these that applies: the `plans/` subdirectory of the directory that `CLAUDE.md` names for specs and plans together; a directory that `CLAUDE.md` names for plans alone; the `plans/` directory next to the spec's directory when that directory is named `specs`; `docs/plans/`.
- The backlog is the directory that `CLAUDE.md` names for it, else `docs/backlog/`. When the directory does not exist, `sh:backlog` asks where it goes, proposes `docs/backlog/`, and records another choice in `CLAUDE.md`. Closed items move to `closed/` inside it.
- The full test command comes from the project. `sh:quick-fix` takes it from `CLAUDE.md`, then the README, and asks you when neither names it. `sh:plan-writer` looks in the spec, `CLAUDE.md`, the README and the build files, and writes the command into the plan header. `sh:implement` runs that command once on the final tree. The `implementer` also looks in `CLAUDE.md` or the README for how to run a single test.
- A git-ignored spec or plan is still used, but the skills skip its commit and say so in the report. For a git-ignored backlog, `sh:backlog` makes no commit, and an item that `sh:quick-fix` or `sh:implement` closes is changed only after you answer "merge". `sh:pr-review` adds `.claude/reviews/` to the repository's `info/exclude` file when it is not ignored, so review records never show as untracked.
- No skill pushes or publishes before you answer its question about merging, opening a pull request, or leaving the branch.

The skills and agents read the project's `CLAUDE.md`, so that file is the place to tell Claude when to use them and where your documents live. For example:

```markdown
A new feature starts with sh:design, a small change with sh:quick-fix, a bug with sh:debugging.
Specs and plans are in `docs/`.
`docs/backlog/` — the backlog: one file per deferred task in the format of `sh:backlog`; closed items move to `closed/`.
The full test command is `make test`.
```

## Development

```
bash tests/check-structure.sh
```

The script needs `jq`, the `claude` CLI and `python3` with PyYAML, and it reports a missing tool as a failure. It first runs its own tests on small fixture trees. Then it checks the repository: that the manifests are valid JSON with the expected names, that `claude plugin validate --strict` accepts both manifests, that every file of the repository layout exists, that every skill and agent has valid frontmatter with a matching name (an agent also needs `model` set to `opus` or `sonnet`, and `tools`), that no skill and agent share a name, and that every `sh:<name>` reference, every `${CLAUDE_PLUGIN_ROOT}/` path and every `${user_config.<key>}` reference in the skills and agents resolves. It exits 0 only when all of that passes, and prints a `FAIL:` line for each problem.

## Credits

Parts of this plugin come from [superpowers](https://github.com/obra/superpowers) by Jesse Vincent. `skills/plan/plan-format.md` copies sections of its `writing-plans` skill, and `skills/debugging/SKILL.md` is shortened from its `systematic-debugging` skill.

## License

MIT. See [LICENSE](LICENSE), which also holds the license of superpowers.
