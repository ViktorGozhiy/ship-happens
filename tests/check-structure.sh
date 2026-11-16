#!/usr/bin/env bash
# Runs the self-tests of the structure check on fixture trees, then checks the
# repository. Exits 0 only when both pass.
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

failures=0

fail() {
  echo "FAIL: $1: $2"
  failures=$((failures + 1))
}

require_tools() {
  local missing=0
  command -v jq >/dev/null 2>&1 || { echo "FAIL: missing tool: jq"; missing=1; }
  command -v claude >/dev/null 2>&1 || { echo "FAIL: missing tool: claude"; missing=1; }
  if ! command -v python3 >/dev/null 2>&1; then
    echo "FAIL: missing tool: python3"
    missing=1
  elif ! python3 -c 'import yaml' >/dev/null 2>&1; then
    echo "FAIL: missing tool: PyYAML for python3"
    missing=1
  fi
  return "$missing"
}

# Prints the problems of one frontmatter block, one per line.
# Arguments: file, kind (skill or agent), expected name.
frontmatter_problems() {
  python3 - "$1" "$2" "$3" <<'PY'
import sys
import yaml

path, kind, expected = sys.argv[1:4]
lines = open(path, encoding="utf-8").read().split("\n")
if lines[0].rstrip() != "---":
    print("frontmatter does not start with ---")
    sys.exit()
end = next((i for i in range(1, len(lines)) if lines[i].rstrip() == "---"), None)
if end is None:
    print("frontmatter is not closed")
    sys.exit()
try:
    data = yaml.safe_load("\n".join(lines[1:end]))
except yaml.YAMLError:
    print("frontmatter is not valid YAML")
    sys.exit()
if not isinstance(data, dict):
    print("frontmatter is not a YAML mapping")
    sys.exit()

def filled(value):
    if isinstance(value, list):
        return any(isinstance(v, str) and v.strip() for v in value)
    return isinstance(value, str) and value.strip() != ""

for key in ("name", "description"):
    if not filled(data.get(key)):
        print(f"{key} is missing or empty")
if filled(data.get("name")) and data["name"] != expected:
    print(f"name must be {expected}")
if kind == "agent":
    if data.get("model") not in ("opus", "sonnet"):
        print("model must be opus or sonnet")
    if not filled(data.get("tools")):
        print("tools is missing or empty")
PY
}

# The files of the spec's "Repository layout".
LAYOUT_FILES='.claude-plugin/plugin.json
.claude-plugin/marketplace.json
skills/design/SKILL.md
skills/review/SKILL.md
skills/plan/SKILL.md
skills/plan/plan-format.md
skills/implement/SKILL.md
skills/quick-fix/SKILL.md
skills/quick-fix/test-failures.md
skills/debugging/SKILL.md
skills/pr-review/SKILL.md
skills/backlog/SKILL.md
skills/backlog/backlog-format.md
agents/advisor.md
agents/spec-reviewer.md
agents/plan-writer.md
agents/plan-reviewer.md
agents/implementer.md
agents/code-reviewer.md
agents/document-reviewer.md
tests/check-structure.sh
LICENSE
README.md'

# Text that the specs rely on, one "<file>|<string>" per line. A file written as
# "description:<file>" must hold the string in its frontmatter description, which
# is the text that loads the skill. The check runs on the repository only.
REQUIRED_TEXT='description:skills/backlog/SKILL.md|Fix small items
description:skills/backlog/SKILL.md|sort the open items
description:skills/backlog/SKILL.md|without questions
description:skills/review/SKILL.md|only when the user asks
description:skills/pr-review/SKILL.md|post named findings
description:skills/pr-review/SKILL.md|fix named findings
description:skills/pr-review/SKILL.md|check the review comments of others on a pull request
description:skills/pr-review/SKILL.md|reply in their threads or resolve them
skills/quick-fix/SKILL.md|git merge --ff-only fix/<slug>
skills/quick-fix/SKILL.md|## Unattended mode
skills/quick-fix/SKILL.md|Fix small items
skills/pr-review/SKILL.md|git merge-tree --write-tree
skills/pr-review/SKILL.md|git fetch origin pull/<number>/head
skills/pr-review/SKILL.md|git cat-file -e
skills/pr-review/SKILL.md|gh pr checks
skills/pr-review/SKILL.md|"commit_id"
skills/pr-review/SKILL.md|with its posted number and its title
skills/pr-review/SKILL.md|<posted number>=<record number>
skills/pr-review/SKILL.md|Number the findings that you post from 1, in the order of their record numbers
skills/pr-review/SKILL.md|so the posted text never shows a record number
skills/pr-review/SKILL.md|those stay record numbers in everything you say to the user
skills/pr-review/SKILL.md|Append to the review record the line `Posted
skills/pr-review/SKILL.md|with the same posted numbers
skills/pr-review/SKILL.md|starts at 1 again
skills/pr-review/SKILL.md|the posted number with its record number
skills/pr-review/SKILL.md|take its record number from the `Posted` line
skills/pr-review/SKILL.md|the review it was posted in and the number it got there
skills/backlog/SKILL.md|The proposal is `fix now`, `backlog` with its priority
skills/backlog/SKILL.md|accepts every proposal, and so does an answer that hands the choice to you
skills/backlog/SKILL.md|A candidate that such an answer does not name is dropped.
skills/backlog/SKILL.md|Write nothing for the dropped candidates, and name them in one line of the report
skills/backlog/SKILL.md|the reason for the proposal in one clause
skills/backlog/SKILL.md|Propose `fix now` only for such a candidate
skills/backlog/SKILL.md|propose `backlog` or `drop` for every candidate
skills/backlog/SKILL.md|Propose `drop` for a candidate that is probably done already
skills/backlog/SKILL.md|An answer with one bare set of numbers names the backlog set
skills/backlog/SKILL.md|A number named in both sets belongs to the fix-now set
skills/backlog/SKILL.md|A number that is backlog only belongs to the backlog set
skills/backlog/SKILL.md|Mark "backlog only" each other candidate
skills/backlog/SKILL.md|puts each candidate into the set of its proposal
skills/backlog/SKILL.md|has the priority of its proposal
skills/backlog/SKILL.md|Leave that line out when none is dropped
skills/review/SKILL.md|timeout 1800 env -u SSH_AUTH_SOCK
skills/review/SKILL.md|--sandbox workspace-write
skills/review/SKILL.md|--sandbox read-only
skills/review/SKILL.md|`git worktree add` or the submodule update
agents/implementer.md|never wait with `sleep`, which the harness blocks
agents/implementer.md|Run a long test run in the foreground with a timeout long enough for it
agents/implementer.md|`Monitor` is not available to you
agents/code-reviewer.md|never wait with `sleep`, which the harness blocks
agents/code-reviewer.md|Run a long test run in the foreground with a timeout long enough for it
agents/code-reviewer.md|`Monitor` is not available to you
agents/plan-writer.md|never wait with `sleep`, which the harness blocks
agents/plan-writer.md|Run a long test run in the foreground with a timeout long enough for it
agents/plan-writer.md|`Monitor` is not available to you
agents/implementer.md|`change` (description of a small change), optionally `worktree`
agents/implementer.md|`intent` (what the work is checked against), optionally `worktree`
agents/implementer.md|with `cd <worktree> &&` at its start
agents/implementer.md|`findings_dir` and `rejections_file` may lie outside it
agents/implementer.md|The rule on uncommitted changes applies to that tree
agents/implementer.md|every project file you change lies under it
agents/implementer.md|In change mode and fix mode, before your first edit, run the existing tests of the code you will touch
agents/implementer.md|that `change` lists as failing on the base commit
agents/implementer.md|unless `change` asks you to fix it
agents/implementer.md|these failures exist before the change, and the user accepted that they do not block it
agents/implementer.md|Name such a test in the commit message body
agents/implementer.md|run those tests, because a full run can exceed the foreground limit of 10 minutes
agents/implementer.md|When `change` gives only a test command with its output, run that command
agents/implementer.md|blocked: passes without a change: <test>
skills/quick-fix/test-failures.md|the user accepted that it does not block a merge
skills/quick-fix/test-failures.md|on the head of the pull request
skills/quick-fix/test-failures.md|it never satisfies "no new failure"
skills/quick-fix/test-failures.md|After a void result, go to step 9
skills/quick-fix/test-failures.md|the output names no failing test
skills/quick-fix/test-failures.md|the command exited non-zero with all tests passing
skills/quick-fix/test-failures.md|Stash nothing and discard nothing
skills/quick-fix/test-failures.md|git branch --show-current
skills/quick-fix/test-failures.md|git diff --name-only <base> HEAD
skills/quick-fix/test-failures.md|When neither names one, the result is void
skills/quick-fix/test-failures.md|already made it at the same base hash
skills/quick-fix/test-failures.md|git checkout --detach <base>
skills/quick-fix/test-failures.md|A failed checkout or a failed rebuild counts as a base run that could not start, and step 6 still runs
skills/quick-fix/test-failures.md|git checkout --detach <head hash>
skills/quick-fix/test-failures.md|stopped: tree: <error>
skills/quick-fix/test-failures.md|when the base run could not start
skills/quick-fix/test-failures.md|the same test fails in `test-base.txt`
skills/quick-fix/test-failures.md|A number that the test compares
skills/quick-fix/test-failures.md|does not name the test or its file
skills/quick-fix/test-failures.md|the diff from the base commit does not change the file of the test
skills/quick-fix/test-failures.md|Write `test-comparison.md`
skills/quick-fix/test-failures.md|also for a void result
skills/quick-fix/test-failures.md|every test run of these steps runs in the worktree
skills/quick-fix/test-failures.md|every rebuild and every test run of these steps runs in the worktree
skills/quick-fix/test-failures.md|the run stopped before all its suites ran
skills/quick-fix/test-failures.md|it shows a build error, a collection error, a lint error or a timeout
skills/quick-fix/test-failures.md|When it prints anything, the result is void
skills/quick-fix/test-failures.md|the project needs a rebuild after each checkout
skills/quick-fix/test-failures.md|Take the rebuild command from the project
skills/quick-fix/test-failures.md|so the rebuild command has to rebuild it
skills/quick-fix/test-failures.md|the rebuild when step 4 asks for it, and the commands of the base run
skills/quick-fix/test-failures.md|then the rebuild when step 4 asks for it. The step is skipped only when no checkout happened
skills/quick-fix/test-failures.md|return: `git checkout <branch>`, or
skills/quick-fix/test-failures.md|When the checkout or the rebuild fails, stop and report the branch and the head hash
skills/quick-fix/test-failures.md|A failure is a base failure only when all of these hold; otherwise it is new
skills/quick-fix/test-failures.md|its error text is the same, apart from addresses
skills/quick-fix/test-failures.md|the new failures by name, and one line per base failure with its test and error text
skills/quick-fix/test-failures.md|the exit status is that of `tee`
skills/quick-fix/test-failures.md|## After the comparison
skills/quick-fix/test-failures.md|Dispatch `sh:implementer` in change mode with `change` set to the names of the new failures, how to run them, their output
skills/quick-fix/test-failures.md|and the list of base failures
skills/quick-fix/test-failures.md|follows this section after step 9, when new failures remain
skills/quick-fix/test-failures.md|The unattended mode does not follow it, because it dispatches no implementer
skills/quick-fix/test-failures.md|After a void result `change` holds the test command, its output and that instruction, because there may be no test name
skills/quick-fix/test-failures.md|Then run the command again. When it exits 0
skills/quick-fix/test-failures.md|delete `test-comparison.md`, because its failures are gone
skills/quick-fix/test-failures.md|When it exits non-zero, follow the steps above again: step 5 reuses `test-base.txt` when it exists
skills/quick-fix/test-failures.md|When the implementer returns `blocked: ` or new failures remain a second time
skills/quick-fix/test-failures.md|stop and report to the user
skills/quick-fix/SKILL.md|its section `## After the comparison` says what follows
skills/implement/SKILL.md|its section `## After the comparison` says what follows
skills/quick-fix/SKILL.md|which is its steps and not its section `## After the comparison`
skills/quick-fix/SKILL.md|Run the test command on the final tree with its output in `<review directory>/test-head.txt`
skills/quick-fix/SKILL.md|run the test command once with its output in `<review directory>/test-head.txt`
skills/quick-fix/SKILL.md|follow `${CLAUDE_PLUGIN_ROOT}/skills/quick-fix/test-failures.md`
skills/quick-fix/SKILL.md|When the input named a backlog item and step 9 left no new failure
skills/quick-fix/SKILL.md|When `test-comparison.md` exists, list the new failures and the base failures with its path
skills/quick-fix/SKILL.md|the first run in step 9 left no new failure
skills/quick-fix/SKILL.md|When it fails, dispatch no implementer
skills/quick-fix/SKILL.md|A commit made after a test run with a new failure
skills/quick-fix/SKILL.md|only when the first two conditions above hold
skills/quick-fix/SKILL.md|with the reason `tests failed`
skills/quick-fix/SKILL.md|after a failing run with no comparison, after a new failure and after a void result
skills/quick-fix/SKILL.md|after the fast-forward. Add `; tests: <path>`
skills/quick-fix/SKILL.md|separated by commas. Add `; tests: <path>`
skills/quick-fix/SKILL.md|so that the report can name the test that blocked the branch
skills/implement/SKILL.md|with its output in `test-head.txt`
skills/implement/SKILL.md|the exit status is that of `tee`
skills/implement/SKILL.md|follow `${CLAUDE_PLUGIN_ROOT}/skills/quick-fix/test-failures.md`
skills/implement/SKILL.md|When `test-comparison.md` exists, list the new failures and the base failures with its path
skills/backlog/SKILL.md|There is no limit unless the user names one
skills/backlog/SKILL.md|Every question comes before the first item
skills/backlog/SKILL.md|After the answer to the report, the action asks nothing
skills/backlog/SKILL.md|Every question came before this point, and nothing is asked after it
skills/backlog/SKILL.md|runs without questions to its end
skills/backlog/SKILL.md|Load `sh:quick-fix` with the Skill tool, and run the section
skills/backlog/SKILL.md|The answer may come later in the session, and it continues at step 10
skills/backlog/SKILL.md|in the order **Not now**, **Needs a design**, **Quick fix with a choice**, **Quick fix, no choice**
skills/backlog/SKILL.md|needs a change in another repository or on another host
skills/backlog/SKILL.md|prints a hash, which marks an unmerged branch
skills/backlog/SKILL.md|Pick the recommended option
skills/backlog/SKILL.md|make your own choice and give the reason
skills/backlog/SKILL.md|the chosen option and its reason for each item with a choice
skills/backlog/SKILL.md|It becomes the chosen option of that item
skills/backlog/SKILL.md|the new failures and the base failures of each item, with the path from its returned line
skills/backlog/SKILL.md|**Not now**, shown below the three groups with its reason
skills/backlog/SKILL.md|it waits for data that does not exist yet
skills/backlog/SKILL.md|A `## Related` section that names another repository does not put an item here
skills/backlog/SKILL.md|**Needs a design**: it does not fit
skills/backlog/SKILL.md|Never switch to a smaller option that was not recommended
skills/backlog/SKILL.md|**Quick fix with a choice**: it fits one implementer task
skills/backlog/SKILL.md|Judge the size by the chosen option
skills/backlog/SKILL.md|**Quick fix, no choice**: every other item
skills/backlog/SKILL.md|A choice stays out of the item
skills/backlog/SKILL.md|timeout 600 codex exec --sandbox read-only
skills/backlog/SKILL.md|is exactly `true`
skills/backlog/SKILL.md|its file is missing or empty, make the choice yourself
skills/backlog/SKILL.md|Then stop and wait
skills/backlog/SKILL.md|A word that accepts, such as "бери", takes both quick-fix groups
skills/backlog/SKILL.md|Bare numbers name the items to take
skills/backlog/SKILL.md|Numbers after "без" name the items to leave out
skills/backlog/SKILL.md|is not taken, also with another choice, and the report says so
skills/backlog/SKILL.md|does not count toward that number
skills/backlog/SKILL.md|and the chosen option with its reason when the item has one
skills/backlog/SKILL.md|A line that starts `stopped: tree:` stops the action in the same way
skills/backlog/SKILL.md|a list of decisions: each item, its option and the reason
skills/backlog/SKILL.md|An item with a chosen option that returned `skipped: size` is listed as needing a design
skills/backlog/SKILL.md|no `; tests:` part means that the comparison did not run
skills/backlog/SKILL.md|the items the action did not take, with their groups, also those past the largest number
skills/backlog/SKILL.md|No merged tree had a new failure before its fast-forward
skills/quick-fix/SKILL.md|and optionally the chosen option with its reason
skills/quick-fix/SKILL.md|This sentence does not narrow the change
skills/quick-fix/SKILL.md|`## Resolution` also names the option and the reason
skills/quick-fix/SKILL.md|Try no second option
skills/quick-fix/SKILL.md|## Pull request mode
skills/quick-fix/SKILL.md|Only `sh:pr-review` runs this mode
skills/quick-fix/SKILL.md|Step 2 does not run: the worktree is new
skills/quick-fix/SKILL.md|run `git -C <worktree> rev-parse HEAD` and keep the hash as the base
skills/quick-fix/SKILL.md|and the parameter `worktree` for every fixer
skills/quick-fix/SKILL.md|this mode has no fix branch
skills/quick-fix/SKILL.md|Step 9, with the parameter `worktree` for the implementer of its section `## After the comparison`
skills/quick-fix/SKILL.md|with `git -C <worktree>` or `cd <worktree> &&`
skills/quick-fix/SKILL.md|Do not run step 10, and offer no leftovers and no merge question
skills/quick-fix/SKILL.md|Return one of these to `sh:pr-review`
skills/quick-fix/SKILL.md|every rebuild and every test run of these steps runs in `<worktree>`
skills/quick-fix/SKILL.md|When they do not fit, make no commit
skills/quick-fix/SKILL.md|Ask no question about a choice between solutions: make the choice
skills/quick-fix/SKILL.md|the items followed by the intent, and the parameter `worktree`
skills/quick-fix/SKILL.md|the `deviated:` lines, the commits made after the review, and the new failures and the base failures
skills/quick-fix/SKILL.md|git -C <worktree> submodule update --init --recursive
skills/quick-fix/SKILL.md|each git-ignored file that the test command reads
skills/quick-fix/SKILL.md|before you check for uncommitted changes
skills/quick-fix/SKILL.md|Each runs this check before its check of uncommitted changes
skills/quick-fix/SKILL.md|the state of the main tree does not matter
skills/pr-review/SKILL.md|run only the section `## Fix named findings`
skills/pr-review/SKILL.md|exists, say so and fix nothing
skills/pr-review/SKILL.md|stop and propose an update review
skills/pr-review/SKILL.md|a number the record does not hold
skills/pr-review/SKILL.md|A finding whose state is resolved
skills/pr-review/SKILL.md|When no named finding and no `T` item is left, fix nothing
skills/pr-review/SKILL.md|--json title,body,baseRefName,headRefName,isCrossRepository
skills/pr-review/SKILL.md|say that the branch lies in a fork, and stop
skills/pr-review/SKILL.md|git worktree add --detach <that directory>/wt-fix <head>
skills/pr-review/SKILL.md|git -C <that directory>/wt-fix submodule update --init --recursive
skills/pr-review/SKILL.md|each git-ignored file that the test command reads
skills/pr-review/SKILL.md|section `## Pull request mode` of `${CLAUDE_PLUGIN_ROOT}/skills/quick-fix/SKILL.md`
skills/pr-review/SKILL.md|another session may work there
skills/pr-review/SKILL.md|no commit exists: remove the worktree
skills/pr-review/SKILL.md|offer no push and stop
skills/pr-review/SKILL.md|push to the branch of the pull request, or leave it
skills/pr-review/SKILL.md|git -C <worktree> push origin HEAD:<headRefName>
skills/pr-review/SKILL.md|Never force
skills/pr-review/SKILL.md|Git rejects the push when the branch moved
skills/pr-review/SKILL.md|except a finding that a `deviated:` line names
skills/pr-review/SKILL.md|git -C <worktree> switch -c pr-<number>-fixes
skills/pr-review/SKILL.md|names no branch, because no ref holds the commits. The user then has to save them
skills/pr-review/SKILL.md|The numbers are record numbers, as for posting
skills/pr-review/SKILL.md|Load `sh:quick-fix` with the Skill tool, and run the section `## Pull request mode`
skills/pr-review/SKILL.md|names in `<that directory>/wt-fix`, with `cd <that directory>/wt-fix &&` at its start
skills/pr-review/SKILL.md|Copy from the main working tree into `<that directory>/wt-fix`
skills/pr-review/SKILL.md|run the `git switch -c` command of step 11 when the head hash of the `stopped:` line, or else `git -C <worktree> rev-parse HEAD`, differs from `<head>`, with the hash of the line as the start point of the new branch
skills/quick-fix/SKILL.md|add `; head: <head hash>`, the head hash of its step 3
skills/pr-review/SKILL.md|The report gives the reason, the worktree'\''s path, the head hash and the branch that the command created
skills/pr-review/SKILL.md|Git rejects the push when the branch moved: run the `git switch -c` command of step 11, keep the worktree and stop
skills/pr-review/SKILL.md|The report gives the error of the push, the worktree'\''s path, the head hash and the branch that the command created
skills/pr-review/SKILL.md|Keep the worktree, and report its path, the branch and the head hash
agents/document-reviewer.md|`claims`, `reasoning`, `actionable` or `full`
agents/document-reviewer.md|when the document sets a task, that it does and for whom
agents/document-reviewer.md|can do the work without asking
agents/document-reviewer.md|Each criterion of done can be checked, each dependency on other work is named
agents/document-reviewer.md|A gap that would make the executor ask or guess is a blocking defect
agents/document-reviewer.md|and `actionable` too when `intent` says that the document sets a task
agents/document-reviewer.md|a wrong belief or a wrong decision
agents/document-reviewer.md|A false or unsupported statement is a blocking defect
agents/document-reviewer.md|A conclusion that does not follow, and a contradiction, are blocking defects
agents/document-reviewer.md|Report blocking defects only
agents/document-reviewer.md|Advice never makes the verdict blocking
agents/document-reviewer.md|When `intent` names no sources, say so under `## Intent`
agents/document-reviewer.md|that exists at `<head>`
agents/document-reviewer.md|model: opus
agents/document-reviewer.md|tools: Read, Grep, Glob, Bash, Write
agents/document-reviewer.md|Do not report a finding that `rejections_file` lists
agents/document-reviewer.md|Never change a file in the project
agents/document-reviewer.md|## Findings file
agents/document-reviewer.md|Line 1 is `VERDICT: clean` or `VERDICT: blocking defects found`
agents/document-reviewer.md|## Return
agents/document-reviewer.md|Return one line and nothing else: `VERDICT:
skills/review/SKILL.md|`sh:code-reviewer` and `sh:document-reviewer`
skills/review/SKILL.md|`spec`, `plan`, `code` or `document`
skills/review/SKILL.md|two full reads for `plan` and `document`
skills/review/SKILL.md|For `document` it is a document path or `<base>..<head>`
skills/review/SKILL.md|`claims`, `reasoning`
skills/review/SKILL.md|Any other document is `document`
skills/review/SKILL.md|never on your own initiative
skills/review/SKILL.md|take no part in `document`
skills/review/SKILL.md|`spec` and `document`: you are the fixer
skills/review/SKILL.md|the target of the next reader is `<base>..<new head>`
skills/review/SKILL.md|For `spec`, `plan` and `document` you commit the revised document
skills/review/SKILL.md|`plan` and `document`: round 1, fix
skills/review/SKILL.md|For `spec`, `plan` and `document`, add the advice you did not apply
skills/review/SKILL.md|or `kind` is `spec`, `plan` or `document`, offer no leftovers
skills/quick-fix/test-failures.md|only the tests that failed on the head, by the ids that `test-head.txt` names
skills/quick-fix/test-failures.md|git cat-file -e <base>:<file>
skills/quick-fix/test-failures.md|An id whose file does not exist at the base commit is a new failure
skills/quick-fix/test-failures.md|covers only the ids that no earlier base run of this skill covered
skills/quick-fix/test-failures.md|When no id is left, no checkout happens
skills/quick-fix/test-failures.md|A runner with no id to pass does not run on the base
skills/quick-fix/test-failures.md|uv run pytest <ids>
skills/quick-fix/test-failures.md|forge test --match-test <name>
skills/quick-fix/test-failures.md|When you cannot tell how to run single tests of a runner, run that runner
skills/quick-fix/test-failures.md|one command per test runner, each whatever the others exit with
skills/quick-fix/test-failures.md|pytest runs none of the ids when one is missing
skills/quick-fix/test-failures.md|`ERROR: file or directory not found` for such an id is this case, not a collection error
skills/quick-fix/test-failures.md|A test that passes alone on the base commit is a new failure
skills/quick-fix/test-failures.md|also after a reuse that covered new ids
skills/quick-fix/test-failures.md|when the base run did not reach all its commands
skills/quick-fix/test-failures.md|shows a build error or a collection error, as step 1 says for the head
skills/quick-fix/test-failures.md|the first command of the first base run with
skills/quick-fix/test-failures.md|does not show such an error
skills/backlog/backlog-format.md|; remains: <what remains>.
skills/backlog/backlog-format.md|is taken from `## Done when`
skills/backlog/SKILL.md|A `Partly done` line has the `remains` part of the format
skills/backlog/SKILL.md|Read a body only as step 4 says
skills/backlog/SKILL.md|the columns priority, date raised, H1, remains and file name
skills/backlog/SKILL.md|`not stated` when that line has none
skills/backlog/SKILL.md|For each item whose head has a `Partly done` line, read the whole item
skills/backlog/SKILL.md|the head line of that item is stale
skills/quick-fix/SKILL.md|in its `remains` part what of `## Done when` is not true yet
skills/quick-fix/SKILL.md|When step 10 wrote a `Partly done` line, or left one for step 13, repeat the line
skills/implement/SKILL.md|its `remains` part says what of `## Done when` is not true yet
skills/implement/SKILL.md|When step 3 wrote a `Partly done` line, or left one for step 6, repeat the line
skills/quick-fix/SKILL.md|a description and a slug in place of the item path
skills/quick-fix/SKILL.md|With it, the branch is `fix/<slug>`, step 10 does not run, and there is no `## Resolution`
skills/quick-fix/SKILL.md|Without a close commit, the condition on the close commit holds
skills/quick-fix/SKILL.md|or the slug of the input with a description
skills/quick-fix/SKILL.md|Step 10, only with an item path
skills/quick-fix/SKILL.md|with an item path in a git-ignored backlog, close the item
skills/backlog/SKILL.md|Run no leftovers and ask nothing
skills/backlog/SKILL.md|give the report of step 17
skills/backlog/SKILL.md|Sort each candidate on its own
skills/backlog/SKILL.md|the test of step 1 of `sh:quick-fix`
skills/backlog/SKILL.md|The last two name the branch they were found on
skills/backlog/SKILL.md|Before each **Write** of this step, run `git checkout <default branch>`
skills/backlog/SKILL.md|in place of an item path, the full text of each **fix** candidate
skills/backlog/SKILL.md|the slug `leftovers-<YYYYMMDD-HHMMSS>`, with the time at which this set starts
skills/backlog/SKILL.md|first run the check of step 14
skills/backlog/SKILL.md|listed as not handled
skills/backlog/SKILL.md|run one set per source review directory
skills/backlog/SKILL.md|as one backlog item `<date>-leftovers-<YYYYMMDD-HHMMSS>.md`
skills/backlog/SKILL.md|They are not candidates, and they start no further set
skills/backlog/SKILL.md|each dropped candidate, with its reason
skills/backlog/SKILL.md|When there is no candidate, go to step 17
skills/backlog/SKILL.md|come from one review directory, run no second set
skills/quick-fix/SKILL.md|## Peer sessions
skills/quick-fix/SKILL.md|When the session has a tool `ListAgents`, call it
skills/quick-fix/SKILL.md|or starts with that name and a hyphen
skills/quick-fix/SKILL.md|`ListAgents` does not list the current session
skills/quick-fix/SKILL.md|quote the line of the peer from `ListAgents`
skills/quick-fix/SKILL.md|say in the question that the changes may belong to the peer
skills/quick-fix/SKILL.md|Never poll for the peer
skills/quick-fix/SKILL.md|wait, work in a worktree without a merge, or work in the main tree anyway
skills/quick-fix/SKILL.md|Step 2, without the peer check
skills/quick-fix/SKILL.md|## Work in a worktree
skills/quick-fix/SKILL.md|git worktree add -b fix/<slug> <worktree> <default branch>
skills/quick-fix/SKILL.md|<scratch>/quick-fix-<YYYYMMDD-HHMMSS>
skills/quick-fix/SKILL.md|because the branch in the main tree belongs to the peer
skills/quick-fix/SKILL.md|so their commits land on `fix/<slug>`
skills/quick-fix/SKILL.md|git checkout <default branch> && git merge --ff-only fix/<slug>
skills/quick-fix/SKILL.md|The worktree stays
skills/quick-fix/SKILL.md|optionally the worktree of a normal run that works in one
skills/backlog/SKILL.md|and the worktree when the skill works in one
skills/backlog/SKILL.md|the worktree you were given, when there is one
skills/quick-fix/test-failures.md|and in a run of `sh:quick-fix` that works in a worktree
skills/quick-fix/SKILL.md|Without the tool, skip the check
skills/quick-fix/SKILL.md|ask the user for it when that command fails
skills/quick-fix/SKILL.md|so the item stays open, and the report says so
skills/quick-fix/SKILL.md|step 1 of `## Work in a worktree` takes the place of this step
skills/quick-fix/SKILL.md|In a worktree, the question offers what
skills/quick-fix/SKILL.md|pass `<worktree>` to **Leftovers**
skills/quick-fix/SKILL.md|every **Write** of this mode, with its commit, runs in it
skills/implement/SKILL.md|look for a peer session with `ListAgents`
skills/implement/SKILL.md|section `## Peer sessions` of `${CLAUDE_PLUGIN_ROOT}/skills/quick-fix/SKILL.md`
skills/implement/SKILL.md|also when the branch is already checked out
skills/implement/SKILL.md|step 4 applies and the check asks nothing
skills/implement/SKILL.md|wait, or work in the main tree anyway
skills/implement/SKILL.md|is not a statement that another session works in this repository
skills/backlog/SKILL.md|Look for a peer session with `ListAgents`
skills/backlog/SKILL.md|section `## Peer sessions` of `${CLAUDE_PLUGIN_ROOT}/skills/quick-fix/SKILL.md`
skills/backlog/SKILL.md|wait, or work in the main tree anyway
skills/backlog/SKILL.md|Look for peer sessions again as step 2 says
skills/backlog/SKILL.md|A peer that step 2 did not find stops the action
skills/backlog/SKILL.md|The unattended mode runs no check of its own
skills/pr-review/SKILL.md|after a summary of step 11 counts as
skills/pr-review/SKILL.md|each with a proposal, `post` or `skip`, and its reason in one clause
skills/pr-review/SKILL.md|A finding that a `Posted` line lists, and a resolved finding, get no proposal
skills/pr-review/SKILL.md|"ok" posts the findings proposed `post`, and numbers name the findings to post
skills/pr-review/SKILL.md|or answers "ok" to a summary of step 11
skills/pr-review/SKILL.md|and step 12 when the user names findings to post or answers "ok" to the summary
skills/pr-review/SKILL.md|Check the open review threads of others on a pull request against the head
skills/pr-review/SKILL.md|or to reply in their threads or resolve them, which step 1 handles
skills/pr-review/SKILL.md|then only the section `## Review threads`
skills/pr-review/SKILL.md|run the section `## Review threads` after this step, also when step 5 then stops
skills/pr-review/SKILL.md|list the threads of `## Review threads` as step 11 does
skills/pr-review/SKILL.md|each `T` number with its author, its verdict and its reason
skills/pr-review/SKILL.md|Give the user the list only for a separate request
skills/pr-review/SKILL.md|## Review threads
skills/pr-review/SKILL.md|gh api user --jq .login
skills/pr-review/SKILL.md|reviewThreads(first: 50, after: $endCursor)
skills/pr-review/SKILL.md|originalCommit { oid }
skills/pr-review/SKILL.md|node(id: $id)
skills/pr-review/SKILL.md|A bot counts like a person
skills/pr-review/SKILL.md|The verdict is `valid` when the remark holds at the head
skills/pr-review/SKILL.md|Give each remark in them that has no thread a verdict in the same way
skills/pr-review/SKILL.md|.claude/reviews/pr-<number>-threads.md
skills/pr-review/SKILL.md|Checked head: <head hash>
skills/pr-review/SKILL.md|### T<n>. <verdict>: <title>
skills/pr-review/SKILL.md|Quote: <the first sentence of the remark>
skills/pr-review/SKILL.md|A later check keeps each earlier `T` number
skills/pr-review/SKILL.md|State: resolved on GitHub
skills/pr-review/SKILL.md|State: gone
skills/pr-review/SKILL.md|so the check never writes the review record
skills/pr-review/SKILL.md|For an outdated thread, read the code
skills/pr-review/SKILL.md|`wrong` when it does not apply
skills/pr-review/SKILL.md|`fixed` when the head does not have the problem
skills/pr-review/SKILL.md|whose first comment is not by the login of step 1
skills/pr-review/SKILL.md|Reply in those threads or resolve them only when the user names them in this session
skills/pr-review/SKILL.md|then only the section `## Replies in threads`
skills/pr-review/SKILL.md|A `T` item of the threads file is never posted
skills/pr-review/SKILL.md|## Replies in threads
skills/pr-review/SKILL.md|a reply on GitHub cannot be taken back
skills/pr-review/SKILL.md|Reply and resolve nothing until the user names `T` numbers from that list
skills/pr-review/SKILL.md|except those with `State: resolved on GitHub` or `State: gone`
skills/pr-review/SKILL.md|An item with `Review:` has no thread
skills/pr-review/SKILL.md|for `valid` with `State: open`, that it is not fixed yet
skills/pr-review/SKILL.md|the number after `discussion_r` in the `Thread:` URL
skills/pr-review/SKILL.md|pulls/<number>/comments/<databaseId>/replies -X POST -f body=<text>
skills/pr-review/SKILL.md|Resolving skips a `valid` item with `State: open`
skills/pr-review/SKILL.md|resolveReviewThread
skills/pr-review/SKILL.md|Replied <YYYY-MM-DD>: <url>
skills/pr-review/SKILL.md|`T` numbers need only the threads file
skills/pr-review/SKILL.md|differs from `Checked head:` of the threads file
skills/pr-review/SKILL.md|A request with both kinds stops when the two heads differ
skills/pr-review/SKILL.md|Only an item with the verdict `valid` and `State: open` is fixed
skills/pr-review/SKILL.md|the full text of the named findings and `T` items
skills/pr-review/SKILL.md|for each fixed `T` item in the threads file
skills/pr-review/SKILL.md|take the id from its `Thread id:` line
skills/pr-review/SKILL.md|the line `Thread id: <id>`
skills/pr-review/SKILL.md|Resolved <YYYY-MM-DD>
skills/pr-review/SKILL.md|apply the rule of step 9 of `## Steps` for `git check-ignore` and `info/exclude` to this file
skills/review/SKILL.md|and `actionable` when the document sets a task for an executor, such as a ticket, a brief or a runbook
skills/review/SKILL.md|write into `intent` that the document sets a task and for whom
skills/review/SKILL.md|A ticket that exists only in Jira is written to a file in the scratchpad first
skills/review/SKILL.md|`git check-ignore` exits 128 for such a path
skills/review/SKILL.md|For `document`, name the aspects that round 1 ran
skills/review/SKILL.md|so they check `actionable` too
README.md|the leftovers that fit `sh:quick-fix`
README.md|with the aspect `actionable`
README.md|on the base commit only the tests that failed
README.md|another Claude Code session in the same repository
README.md|"ok" posts the proposed ones
README.md|review threads of colleagues and bots
README.md|what remains of a partly done item
README.md|`document-reviewer`
README.md|in three groups
README.md|A document other than a spec
README.md|also fails on the base commit
README.md|asks one question: whether to push
README.md|**Fix small items** may ask Codex about a choice
README.md|Plan reviews and document reviews do not use Codex
README.md|Fix small items
README.md|--sandbox workspace-write'

# Text that must stand on exactly the given number of lines of a file, one
# "<file>|<number>|<string>" per line. It covers lines that two sections repeat
# on purpose, and a heading that a reference to it also contains. The check runs
# on the repository only.
REQUIRED_COUNTS='skills/quick-fix/SKILL.md|2|- `done` when step 9 left no new failure.
skills/quick-fix/SKILL.md|2|- `stopped: size: <reason>` when step 1 found the items too large. No commit was made.
skills/quick-fix/SKILL.md|2|- `stopped: <reason>` when the mode stopped after it started work
skills/quick-fix/SKILL.md|2|new failures remaining after the second run
skills/quick-fix/SKILL.md|2|the exit status is that of `tee`
skills/pr-review/SKILL.md|2|## Fix named findings
skills/pr-review/SKILL.md|2|When the command fails, the report says what step 11 says of that failure.'

# Prints the frontmatter description of a file. Prints nothing when the file or
# the description is missing.
frontmatter_description() {
  python3 -I - "$1" <<'PY' 2>/dev/null
import sys
import yaml

lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
if lines[0].rstrip() != "---":
    sys.exit()
end = next((i for i in range(1, len(lines)) if lines[i].rstrip() == "---"), None)
if end is None:
    sys.exit()
data = yaml.safe_load("\n".join(lines[1:end]))
if isinstance(data, dict) and isinstance(data.get("description"), str):
    print(data["description"])
PY
}

check_required_text() {
  local root=$1 file string
  while IFS='|' read -r file string; do
    if [[ $file == description:* ]]; then
      file=${file#description:}
      grep -qF -- "$string" <<<"$(frontmatter_description "$root/$file")" ||
        fail "required text" "$file: description lacks: $string"
    else
      grep -qF -- "$string" "$root/$file" 2>/dev/null ||
        fail "required text" "$file: $string"
    fi
  done <<<"$REQUIRED_TEXT"
  [ "$failures" -eq 0 ]
}

check_required_counts() {
  local root=$1 file count string found
  while IFS='|' read -r file count string; do
    found=$(grep -cF -- "$string" "$root/$file" 2>/dev/null)
    [ "$found" = "$count" ] ||
      fail "required count" "$file: $count lines with: $string (found ${found:-0})"
  done <<<"$REQUIRED_COUNTS"
  [ "$failures" -eq 0 ]
}

check_layout() {
  local root=$1 path
  while IFS= read -r path; do
    [ -f "$root/$path" ] || fail "$path" "is part of the repository layout but does not exist"
  done <<<"$LAYOUT_FILES"
  [ "$failures" -eq 0 ]
}

check_manifests() {
  local root=$1 plugin marketplace field
  plugin=$root/.claude-plugin/plugin.json
  marketplace=$root/.claude-plugin/marketplace.json

  if ! jq empty "$plugin" >/dev/null 2>&1; then
    fail ".claude-plugin/plugin.json" "is not valid JSON"
  else
    [ "$(jq -r '.name' "$plugin")" = "sh" ] ||
      fail ".claude-plugin/plugin.json" "plugin name must be sh"
    [ "$(jq -r '.license' "$plugin")" = "MIT" ] ||
      fail ".claude-plugin/plugin.json" "license must be MIT"
    for field in homepage repository; do
      [ "$(jq -r --arg f "$field" '.[$f] | if type == "string" then . else "" end' "$plugin")" != "" ] ||
        fail ".claude-plugin/plugin.json" "$field must be set"
    done
  fi

  if ! jq empty "$marketplace" >/dev/null 2>&1; then
    fail ".claude-plugin/marketplace.json" "is not valid JSON"
  else
    [ "$(jq -r '.name' "$marketplace")" = "ship-happens" ] ||
      fail ".claude-plugin/marketplace.json" "marketplace name must be ship-happens"
    [ "$(jq -r '[.plugins[]? | select(.name == "sh" and .source == "./")] | length' "$marketplace")" -ge 1 ] ||
      fail ".claude-plugin/marketplace.json" "must list plugin sh with source ./"
  fi
}

check_manifests_with_claude() {
  local root=$1 manifest out
  for manifest in plugin marketplace; do
    if ! out=$(claude plugin validate --strict "$root/.claude-plugin/$manifest.json" 2>&1); then
      fail ".claude-plugin/$manifest.json" "claude plugin validate --strict failed: $(tr -s "[:space:]" " " <<<"$out")"
    fi
  done
}

check_frontmatter() {
  local root=$1 file kind expected output problem
  for file in "$root"/skills/*/SKILL.md "$root"/agents/*.md; do
    [ -f "$file" ] || continue
    if [[ $file == */SKILL.md ]]; then
      kind=skill
      expected=$(basename "$(dirname "$file")")
    else
      kind=agent
      expected=$(basename "$file" .md)
    fi
    if ! output=$(frontmatter_problems "$file" "$kind" "$expected" 2>&1); then
      fail "${file#"$root"/}" "frontmatter could not be checked: $(tail -n 1 <<<"$output")"
      continue
    fi
    [ -n "$output" ] || continue
    while IFS= read -r problem; do
      fail "${file#"$root"/}" "$problem"
    done <<<"$output"
  done
}

check_unique_names() {
  local root=$1 skill name
  for skill in "$root"/skills/*/SKILL.md; do
    [ -f "$skill" ] || continue
    name=$(basename "$(dirname "$skill")")
    [ -f "$root/agents/$name.md" ] &&
      fail "agents/$name.md" "$name is both a skill and an agent"
  done
}

check_content() {
  local root=$1 file rel name path key keys
  keys=$(jq -r '.userConfig // {} | keys[]' "$root/.claude-plugin/plugin.json" 2>/dev/null)
  while IFS= read -r file; do
    rel=${file#"$root"/}

    if grep -q 'superpowers:' "$file"; then
      fail "$rel" "must not contain superpowers:"
    fi

    if grep -qi 'Viktor' "$file"; then
      fail "$rel" "must not name Viktor"
    fi

    while IFS= read -r name; do
      if [ ! -f "$root/agents/$name.md" ] && [ ! -f "$root/skills/$name/SKILL.md" ]; then
        fail "$rel" "sh:$name does not resolve to an agent or a skill"
      fi
    done < <(grep -oE '(^|[^A-Za-z0-9_-])sh:[a-z][a-z0-9-]*' "$file" | sed -E 's/.*sh://' | sort -u)

    while IFS= read -r path; do
      if [ ! -f "$root/$path" ]; then
        fail "$rel" "\${CLAUDE_PLUGIN_ROOT}/$path does not exist"
      fi
    done < <(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9_./-]+' "$file" |
      sed -E 's#^\$\{CLAUDE_PLUGIN_ROOT\}/##; s#\.+$##' | sort -u)

    while IFS='|' read -r heading path; do
      grep -qxF -- "## $heading" "$root/$path" 2>/dev/null ||
        fail "$rel" "section \`## $heading\` does not exist in $path"
    done < <(grep -oE 'section `## [^`]+` of `\$\{CLAUDE_PLUGIN_ROOT\}/[^`]+`' "$file" |
      sed -E 's~^section `## ([^`]+)` of `\$\{CLAUDE_PLUGIN_ROOT\}/([^`]+)`$~\1|\2~' | sort -u)

    while IFS= read -r key; do
      grep -qxF -- "$key" <<<"$keys" ||
        fail "$rel" "\${user_config.$key} is not a key of userConfig in plugin.json"
    done < <(grep -oE '\$\{user_config\.[A-Za-z0-9_]+\}' "$file" | sed -E 's/^\$\{user_config\.//; s/\}$//' | sort -u)
  done < <(find "$root/skills" "$root/agents" -type f 2>/dev/null | sort)
}

# Prints one line per failed rule. Returns non-zero when any rule failed.
# The second argument is "real" for the repository and "fixture" for test trees.
check_tree() {
  local root=$1 kind=$2
  failures=0
  check_manifests "$root"
  if [ "$kind" = real ]; then
    check_manifests_with_claude "$root"
    check_layout "$root"
    check_required_text "$root"
    check_required_counts "$root"
  fi
  check_frontmatter "$root"
  check_unique_names "$root"
  check_content "$root"
  [ "$failures" -eq 0 ]
}

# ---- self-tests --------------------------------------------------------------

write_manifests() {
  local dir=$1
  mkdir -p "$dir/.claude-plugin"
  cat >"$dir/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "sh",
  "description": "Fixture plugin",
  "version": "0.1.0",
  "homepage": "https://example.com/fixture",
  "repository": "https://example.com/fixture",
  "license": "MIT",
  "userConfig": { "codex_review": { "title": "Codex review", "type": "boolean" } }
}
JSON
  cat >"$dir/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "ship-happens",
  "owner": { "name": "Fixture owner" },
  "plugins": [ { "name": "sh", "source": "./" } ]
}
JSON
}

new_fixture() {
  local dir
  dir=$(mktemp -d "$SCRATCH/fixture.XXXXXX")
  write_manifests "$dir"
  echo "$dir"
}

write_skill() {
  local dir=$1 name=$2
  mkdir -p "$dir/skills/$name"
  cat >"$dir/skills/$name/SKILL.md" <<SKILL
---
name: $name
description: Fixture skill.
---
Dispatch sh:helper and read \${CLAUDE_PLUGIN_ROOT}/skills/$name/notes.md.
SKILL
  echo "Notes." >"$dir/skills/$name/notes.md"
}

write_agent() {
  local dir=$1 name=$2
  mkdir -p "$dir/agents"
  cat >"$dir/agents/$name.md" <<AGENT
---
name: $name
description: Fixture agent.
model: sonnet
tools: Read, Grep
---
Do the work.
AGENT
}

# A fixture with one skill that names one agent.
new_valid_fixture() {
  local dir
  dir=$(new_fixture)
  write_skill "$dir" demo
  write_agent "$dir" helper
  echo "$dir"
}

# A fixture holding every file of the repository layout.
new_layout_fixture() {
  local dir path
  dir=$(new_fixture)
  while IFS= read -r path; do
    mkdir -p "$dir/$(dirname "$path")"
    touch "$dir/$path"
  done <<<"$LAYOUT_FILES"
  echo "$dir"
}

# A fixture whose files hold every string of REQUIRED_TEXT. A file with
# description strings starts with one frontmatter that holds all of them, so the
# entries of that kind are written first.
new_required_text_fixture() {
  local dir file string strings
  dir=$(new_fixture)
  while IFS= read -r file; do
    strings=$(grep -F "$file|" <<<"$REQUIRED_TEXT" | cut -d'|' -f2- | paste -sd';' -)
    file=${file#description:}
    mkdir -p "$dir/$(dirname "$file")"
    printf -- '---\nname: fixture\ndescription: Use when asked (%s).\n---\n' "$strings" >"$dir/$file"
  done < <(grep '^description:' <<<"$REQUIRED_TEXT" | cut -d'|' -f1 | sort -u)
  while IFS='|' read -r file string; do
    [[ $file == description:* ]] && continue
    mkdir -p "$dir/$(dirname "$file")"
    printf '%s\n' "$string" >>"$dir/$file"
  done <<<"$REQUIRED_TEXT"
  echo "$dir"
}

SELF_TEST_FAILURES=0

self_test_pass() {
  local label=$1 dir=$2 out rc
  out=$(check_tree "$dir" fixture)
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "pass: self-test: $label"
  else
    echo "FAIL: self-test: $label should pass but failed:"
    echo "$out"
    SELF_TEST_FAILURES=$((SELF_TEST_FAILURES + 1))
  fi
}

self_test_fail() {
  local label=$1 dir=$2 expected=$3 kind=${4:-fixture} out rc
  out=$(check_tree "$dir" "$kind")
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "FAIL: self-test: $label should fail but passed"
    SELF_TEST_FAILURES=$((SELF_TEST_FAILURES + 1))
  elif ! grep -qF -- "$expected" <<<"$out"; then
    echo "FAIL: self-test: $label failed without the message '$expected':"
    echo "$out"
    SELF_TEST_FAILURES=$((SELF_TEST_FAILURES + 1))
  else
    echo "pass: self-test: $label"
  fi
}

# Runs one check function on a fixture, which must pass.
self_test_function_pass() {
  local label=$1 dir=$2 check=$3 out
  failures=0
  if out=$("$check" "$dir"); then
    echo "pass: self-test: $label"
  else
    echo "FAIL: self-test: $label should pass but failed:"
    echo "$out"
    SELF_TEST_FAILURES=$((SELF_TEST_FAILURES + 1))
  fi
}

# Runs one check function on a fixture, which must fail with the expected message.
self_test_function_fail() {
  local label=$1 dir=$2 expected=$3 check=$4 out
  failures=0
  if out=$("$check" "$dir"); then
    echo "FAIL: self-test: $label should fail but passed"
    SELF_TEST_FAILURES=$((SELF_TEST_FAILURES + 1))
  elif ! grep -qF -- "$expected" <<<"$out"; then
    echo "FAIL: self-test: $label failed without the message '$expected':"
    echo "$out"
    SELF_TEST_FAILURES=$((SELF_TEST_FAILURES + 1))
  else
    echo "pass: self-test: $label"
  fi
}

run_self_tests() {
  local dir two_triggers counts

  self_test_pass "manifests alone" "$(new_fixture)"
  self_test_pass "valid skill naming a valid agent" "$(new_valid_fixture)"

  dir=$(new_fixture)
  echo '{ "name": ' >"$dir/.claude-plugin/plugin.json"
  self_test_fail "invalid manifest JSON" "$dir" "is not valid JSON"

  dir=$(new_fixture)
  sed -i '/"license"/d' "$dir/.claude-plugin/plugin.json"
  self_test_fail "plugin.json without license" "$dir" "license must be MIT"

  dir=$(new_fixture)
  sed -i 's/"license": "MIT"/"license": "GPL-3.0"/' "$dir/.claude-plugin/plugin.json"
  self_test_fail "plugin.json with another license" "$dir" "license must be MIT"

  dir=$(new_fixture)
  sed -i '/"homepage"/d' "$dir/.claude-plugin/plugin.json"
  self_test_fail "plugin.json without homepage" "$dir" "homepage must be set"

  dir=$(new_fixture)
  sed -i '/"repository"/d' "$dir/.claude-plugin/plugin.json"
  self_test_fail "plugin.json without repository" "$dir" "repository must be set"

  dir=$(new_fixture)
  sed -i 's/"name": "sh"/"name": "other"/' "$dir/.claude-plugin/plugin.json"
  self_test_fail "wrong plugin name" "$dir" "plugin name must be sh"

  dir=$(new_fixture)
  sed -i 's/"name": "ship-happens"/"name": "other"/' "$dir/.claude-plugin/marketplace.json"
  self_test_fail "wrong marketplace name" "$dir" "marketplace name must be ship-happens"

  dir=$(new_fixture)
  sed -i 's#"source": "./"#"source": "./sh"#' "$dir/.claude-plugin/marketplace.json"
  self_test_fail "marketplace entry without source ./" "$dir" "must list plugin sh with source ./"

  dir=$(new_valid_fixture)
  printf -- '---\nname: demo\ndescription: Fixture skill.\nBody without a closing line.\n' >"$dir/skills/demo/SKILL.md"
  self_test_fail "unclosed frontmatter" "$dir" "frontmatter is not closed"

  dir=$(new_valid_fixture)
  printf -- '---\nname: demo\ndescription: a: b\n---\nBody.\n' >"$dir/skills/demo/SKILL.md"
  self_test_fail "invalid YAML" "$dir" "frontmatter is not valid YAML"

  dir=$(new_valid_fixture)
  printf -- '---\nname: other\ndescription: Fixture skill.\n---\n\xff\n' >"$dir/skills/demo/SKILL.md"
  self_test_fail "frontmatter helper crash on invalid UTF-8" "$dir" "frontmatter could not be checked"

  dir=$(new_valid_fixture)
  printf -- '---\nname:\ndescription: Fixture skill.\n---\nBody.\n' >"$dir/skills/demo/SKILL.md"
  self_test_fail "empty name" "$dir" "name is missing or empty"

  dir=$(new_valid_fixture)
  printf -- '---\nname: demo\ndescription: ""\n---\nBody.\n' >"$dir/skills/demo/SKILL.md"
  self_test_fail "empty description" "$dir" "description is missing or empty"

  dir=$(new_valid_fixture)
  sed -i 's/^name: demo/name: other/' "$dir/skills/demo/SKILL.md"
  self_test_fail "skill name differs from directory" "$dir" "name must be demo"

  dir=$(new_valid_fixture)
  sed -i 's/^name: helper/name: other/' "$dir/agents/helper.md"
  self_test_fail "agent name differs from file" "$dir" "name must be helper"

  dir=$(new_valid_fixture)
  sed -i '/^model:/d' "$dir/agents/helper.md"
  self_test_fail "agent without model" "$dir" "model must be opus or sonnet"

  dir=$(new_valid_fixture)
  sed -i '/^tools:/d' "$dir/agents/helper.md"
  self_test_fail "agent without tools" "$dir" "tools is missing or empty"

  dir=$(new_valid_fixture)
  rm "$dir/agents/helper.md"
  self_test_fail "sh: reference to a missing file" "$dir" "sh:helper does not resolve"

  dir=$(new_valid_fixture)
  rm "$dir/skills/demo/notes.md"
  self_test_fail "missing CLAUDE_PLUGIN_ROOT file" "$dir" "skills/demo/notes.md does not exist"

  dir=$(new_valid_fixture)
  echo "Use superpowers:brainstorming first." >>"$dir/skills/demo/SKILL.md"
  self_test_fail "superpowers: reference" "$dir" "must not contain superpowers:"

  dir=$(new_valid_fixture)
  echo "Use when Viktor asks for a review." >>"$dir/skills/demo/SKILL.md"
  self_test_fail "personal name in a skill" "$dir" "must not name Viktor"

  dir=$(new_valid_fixture)
  echo "Read /home/viktor/notes before starting." >>"$dir/skills/demo/SKILL.md"
  self_test_fail "lowercase personal name in a skill" "$dir" "must not name Viktor"

  dir=$(new_valid_fixture)
  mkdir -p "$dir/skills/helper"
  printf -- '---\nname: helper\ndescription: Fixture skill.\n---\nBody.\n' >"$dir/skills/helper/SKILL.md"
  self_test_fail "skill and agent sharing a name" "$dir" "both a skill and an agent"

  dir=$(new_valid_fixture)
  echo "Codex is enabled when \${user_config.codex_review} is true." >>"$dir/skills/demo/SKILL.md"
  self_test_pass "user_config key declared in plugin.json" "$dir"

  dir=$(new_valid_fixture)
  echo "Codex is enabled when \${user_config.other_key} is true." >>"$dir/skills/demo/SKILL.md"
  self_test_fail "user_config key missing from plugin.json" "$dir" "user_config.other_key} is not a key of userConfig"

  dir=$(new_valid_fixture)
  printf '%s\n' '## Mode' 'Body.' >"$dir/skills/demo/notes.md"
  echo "Run the section \`## Mode\` of \`\${CLAUDE_PLUGIN_ROOT}/skills/demo/notes.md\`." >>"$dir/skills/demo/SKILL.md"
  self_test_pass "section reference to an existing heading" "$dir"

  dir=$(new_valid_fixture)
  printf '%s\n' '## Mode' 'Body.' >"$dir/skills/demo/notes.md"
  echo "Run it in the section \`## Mode\` of \`\${CLAUDE_PLUGIN_ROOT}/skills/demo/notes.md\`." >>"$dir/skills/demo/SKILL.md"
  self_test_pass "section reference with a leading preposition" "$dir"

  dir=$(new_valid_fixture)
  printf '%s\n' '## Other' 'Body.' >"$dir/skills/demo/notes.md"
  echo "Run the section \`## Mode\` of \`\${CLAUDE_PLUGIN_ROOT}/skills/demo/notes.md\`." >>"$dir/skills/demo/SKILL.md"
  self_test_fail "section reference to a missing heading" "$dir" "section \`## Mode\` does not exist in skills/demo/notes.md"

  dir=$(new_valid_fixture)
  printf '%s\n' '## Modes' 'Body.' >"$dir/skills/demo/notes.md"
  echo "Run the section \`## Mode\` of \`\${CLAUDE_PLUGIN_ROOT}/skills/demo/notes.md\`." >>"$dir/skills/demo/SKILL.md"
  self_test_fail "section reference to a heading that only starts alike" "$dir" "section \`## Mode\` does not exist in skills/demo/notes.md"

  dir=$(new_required_text_fixture)
  self_test_function_pass "required text present" "$dir" check_required_text

  dir=$(new_required_text_fixture)
  sed -i 's/--sandbox read-only//' "$dir/skills/review/SKILL.md"
  self_test_function_fail "required text missing" "$dir" \
    "FAIL: required text: skills/review/SKILL.md: --sandbox read-only" check_required_text

  dir=$(new_required_text_fixture)
  sed -i 's/Fix small items//' "$dir/skills/backlog/SKILL.md"
  self_test_function_fail "description trigger missing" "$dir" \
    "FAIL: required text: skills/backlog/SKILL.md: description lacks: Fix small items" check_required_text

  dir=$(new_required_text_fixture)
  sed -i '/^description:/d' "$dir/skills/pr-review/SKILL.md"
  echo "post named findings" >>"$dir/skills/pr-review/SKILL.md"
  self_test_function_fail "description trigger only in the body" "$dir" \
    "FAIL: required text: skills/pr-review/SKILL.md: description lacks: post named findings" check_required_text

  dir=$(new_required_text_fixture)
  sed -i 's/^description:.*/description: Use when asked./' "$dir/skills/pr-review/SKILL.md"
  echo "post named findings" >>"$dir/skills/pr-review/SKILL.md"
  self_test_function_fail "description present without the trigger, trigger in the body" "$dir" \
    "FAIL: required text: skills/pr-review/SKILL.md: description lacks: post named findings" check_required_text

  dir=$(new_required_text_fixture)
  rm "$dir/skills/review/SKILL.md"
  self_test_function_fail "file of a required text missing" "$dir" \
    "FAIL: required text: skills/review/SKILL.md: --sandbox read-only" check_required_text

  dir=$(new_required_text_fixture)
  rm "$dir/skills/backlog/SKILL.md"
  self_test_function_fail "file of a description trigger missing" "$dir" \
    "FAIL: required text: skills/backlog/SKILL.md: description lacks: Fix small items" check_required_text

  two_triggers=$'description:skills/demo/SKILL.md|first trigger\ndescription:skills/demo/SKILL.md|second trigger'

  dir=$(REQUIRED_TEXT=$two_triggers new_required_text_fixture)
  REQUIRED_TEXT=$two_triggers self_test_function_pass "two description triggers of one file" "$dir" check_required_text

  dir=$(REQUIRED_TEXT=$two_triggers new_required_text_fixture)
  sed -i 's/first trigger//' "$dir/skills/demo/SKILL.md"
  REQUIRED_TEXT=$two_triggers self_test_function_fail "first of two description triggers missing" "$dir" \
    "FAIL: required text: skills/demo/SKILL.md: description lacks: first trigger" check_required_text

  dir=$(REQUIRED_TEXT=$two_triggers new_required_text_fixture)
  sed -i 's/second trigger//' "$dir/skills/demo/SKILL.md"
  REQUIRED_TEXT=$two_triggers self_test_function_fail "second of two description triggers missing" "$dir" \
    "FAIL: required text: skills/demo/SKILL.md: description lacks: second trigger" check_required_text

  dir=$(new_layout_fixture)
  self_test_fail "repository check applies the required text" "$dir" \
    "required text: skills/pr-review/SKILL.md: gh pr checks" real

  dir=$(new_layout_fixture)
  self_test_fail "repository check applies the required counts" "$dir" \
    "required count: skills/pr-review/SKILL.md: 2 lines with: ## Fix named findings (found 0)" real

  counts=$'skills/demo/SKILL.md|2|repeated line\nskills/demo/SKILL.md|1|single line'

  dir=$(new_valid_fixture)
  printf '%s\n' "repeated line" "repeated line" "single line" >>"$dir/skills/demo/SKILL.md"
  REQUIRED_COUNTS=$counts self_test_function_pass "required counts met" "$dir" check_required_counts

  dir=$(new_valid_fixture)
  printf '%s\n' "repeated line" "single line" >>"$dir/skills/demo/SKILL.md"
  REQUIRED_COUNTS=$counts self_test_function_fail "line repeated on purpose stands once" "$dir" \
    "FAIL: required count: skills/demo/SKILL.md: 2 lines with: repeated line (found 1)" check_required_counts

  dir=$(new_valid_fixture)
  printf '%s\n' "repeated line" "repeated line" >>"$dir/skills/demo/SKILL.md"
  REQUIRED_COUNTS=$counts self_test_function_fail "line missing" "$dir" \
    "FAIL: required count: skills/demo/SKILL.md: 1 lines with: single line (found 0)" check_required_counts

  dir=$(new_layout_fixture)
  self_test_function_pass "complete layout" "$dir" check_layout

  dir=$(new_layout_fixture)
  rm "$dir/agents/advisor.md"
  self_test_function_fail "layout without agents/advisor.md" "$dir" "agents/advisor.md" check_layout

  dir=$(new_layout_fixture)
  rm "$dir/LICENSE"
  self_test_fail "layout without LICENSE" "$dir" "LICENSE: is part of the repository layout" real

  dir=$(new_layout_fixture)
  rm "$dir/README.md"
  self_test_fail "layout without README.md" "$dir" "README.md: is part of the repository layout" real

  dir=$(new_layout_fixture)
  rm "$dir/agents/advisor.md"
  self_test_fail "repository check applies the layout" "$dir" "agents/advisor.md: is part of the repository layout" real

  [ "$SELF_TEST_FAILURES" -eq 0 ]
}

# ---- main --------------------------------------------------------------------

require_tools || exit 1
run_self_tests || exit 1
check_tree "$ROOT" real || exit 1
echo "pass: repository structure"
