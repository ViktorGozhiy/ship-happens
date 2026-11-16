# Test failures on the base commit

This is the rule for a test that fails on the head and also on the base commit. Such a failure exists before the change, the user accepted that it does not block a merge, and it is always shown to the user.

Read this file only after a test run exits non-zero. The output of that run is in `test-head.txt`. `test-base.txt` and `test-comparison.md` go into the same directory.

The base commit of the comparison is:

- in a normal run of `sh:quick-fix`, `<base>`;
- in the fix-now mode, the fix-now base;
- in the unattended mode, `<base>`;
- in the pull request mode, the head of the pull request, and the report says "on the head of the pull request";
- in `sh:implement`, the branch base.

"Void" means that the comparison cannot be made, and every failure counts as new. A void result counts as a failure of the command, also when it names no test, and it never satisfies "no new failure". After a void result, go to step 9.

In the pull request mode, and in a run of `sh:quick-fix` that works in a worktree, every git command, every rebuild and every test run of these steps runs in the worktree, so that the main working tree stays untouched.

1. Read `test-head.txt`. The result is void when any of these holds, and no base run happens: the output names no failing test; it shows a build error, a collection error, a lint error or a timeout; the command exited non-zero with all tests passing; the run stopped before all its suites ran, as `uv run pytest && forge test` does after a failing pytest, as `mvn test` does at the first failed module, and as `cargo test` does at the first failing test binary.
2. Run `git status --short`. When it prints anything, the result is void. Stash nothing and discard nothing.
3. Keep `git rev-parse HEAD` as the head hash and `git branch --show-current` as the branch. When the branch is empty, the tree is on a detached HEAD.
4. Run `git diff --name-only <base> HEAD`. When it lists a lock file, a package manifest, a submodule pointer or compiled source, the project needs a rebuild after each checkout. Take the rebuild command from the project's `CLAUDE.md`, then the README. When neither names one, the result is void. A plain dependency sync may leave a compiled part of the head in place, so the rebuild command has to rebuild it.
5. The base run runs on the base commit only the tests that failed on the head, by the ids that `test-head.txt` names.
   - Pass only the ids whose file exists at the base commit, which `git cat-file -e <base>:<file>` shows. An id whose file does not exist at the base commit is a new failure.
   - When `test-base.txt` exists and this run of the skill already made it at the same base hash, the base run covers only the ids that no earlier base run of this skill covered, and appends its output to `test-base.txt`. When no id is left, no checkout happens: go to step 7.
   - Derive one command per test runner from the full test command, each with the ids of its runner, for example `uv run pytest <ids>` from `uv run pytest`, or `forge test --match-test <name>` from `forge test`. When you cannot tell how to run single tests of a runner, run that runner's full command, as the full test command runs it.
   - Run `git checkout --detach <base>`, the rebuild when step 4 asks for it, and the commands of the base run. Run one command per test runner, each whatever the others exit with, because `uv run pytest <ids> && forge test` stops after a failing pytest. Each command writes its output into `test-base.txt` by a plain redirect, because with `| tee` the exit status is that of `tee`: the first command of the first base run with `>`, every later command with `>>`.
   - When a runner reports an id it was given as not found, such as pytest with `ERROR: not found` and exit code 4, that id is a new failure. Run that runner once more without it, because pytest runs none of the ids when one is missing. `ERROR: file or directory not found` for such an id is this case, not a collection error.
   - A test that passes alone on the base commit is a new failure, also when it would fail there in the full run, because an earlier test may make it fail.
   - A failed checkout or a failed rebuild counts as a base run that could not start, and step 6 still runs.
6. After every base run that ran `git checkout --detach <base>`, also after a reuse that covered new ids and after a failed checkout, return: `git checkout <branch>`, or `git checkout --detach <head hash>` on a detached HEAD, then the rebuild when step 4 asks for it. It does not run only when no checkout happened. When the checkout or the rebuild fails, stop and report the branch and the head hash. In the unattended mode that is the line `stopped: tree: <error>`, followed by `; branch:`, `; base:` and `; review:` as the mode's `stopped:` line says.
7. The result is void when the base run could not start, when the base run did not reach all its commands, or when `test-base.txt` shows a build error or a collection error, as step 1 says for the head. A runner that reports an id as not found, as step 5 says, does not show such an error.
8. Compare the failures. A failure is a base failure only when all of these hold; otherwise it is new:
   - the same test fails in `test-base.txt`;
   - its error text is the same, apart from addresses, hashes, times, durations, ports, block numbers and request ids. A number that the test compares, such as `expected 10, got 9`, or a status code, stays part of the text;
   - the source of the change does not name the test or its file. The source is the description in a normal run and in the unattended mode, the items in the fix-now mode, the findings in the pull request mode, and the spec and the plan in `sh:implement`;
   - the diff from the base commit does not change the file of the test.
9. Write `test-comparison.md` in the same directory, also for a void result: the base commit, the reason when the result is void, the new failures by name, and one line per base failure with its test and error text.

## After the comparison

The skill that ran the test command follows this section after step 9, when new failures remain. The unattended mode does not follow it, because it dispatches no implementer.

Dispatch `sh:implementer` in change mode with `change` set to the names of the new failures, how to run them, their output, the instruction to make them pass, and the list of base failures. After a void result `change` holds the test command, its output and that instruction, because there may be no test name. Then run the command again. When it exits 0, delete `test-comparison.md`, because its failures are gone. When it exits non-zero, follow the steps above again: step 5 reuses `test-base.txt` when it exists. When the implementer returns `blocked: ` or new failures remain a second time, stop and report to the user.
