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

In the pull request mode every git command and every test run of these steps runs in the worktree, so that the main working tree stays untouched.

1. Read `test-head.txt`. The result is void when any of these holds, and no base run happens: the output names no failing test; it shows a build error, a collection error, a lint error or a timeout; the command exited non-zero with all tests passing; the run stopped before all its suites ran, as `uv run pytest && forge test` does after a failing pytest, as `mvn test` does at the first failed module, and as `cargo test` does at the first failing test binary.
2. Run `git status --short`. When it prints anything, the result is void. Stash nothing and discard nothing.
3. Keep `git rev-parse HEAD` as the head hash and `git branch --show-current` as the branch. When the branch is empty, the tree is on a detached HEAD.
4. Run `git diff --name-only <base> HEAD`. When it lists a lock file, a package manifest, a submodule pointer or compiled source, the project needs a rebuild after each checkout. Take the rebuild command from the project's `CLAUDE.md`, then the README. When neither names one, the result is void. A plain dependency sync may leave a compiled part of the head in place: in route-aggregator `uv sync` keeps the extension built from `rust/`, and only `uv sync --reinstall-package route-aggregator` rebuilds it.
5. Reuse `test-base.txt` when this run of the skill already made it at the same base hash, and go to step 7. Otherwise run `git checkout --detach <base>`, the rebuild when step 4 asks for it, and the test command with its output in `test-base.txt`. A failed checkout or a failed rebuild counts as a base run that could not start, and step 6 still runs.
6. After a base run, return: `git checkout <branch>`, or `git checkout --detach <head hash>` on a detached HEAD, then the rebuild when step 4 asks for it. After a reused `test-base.txt` this step does not run, because no checkout happened. When the checkout or the rebuild fails, stop and report the branch and the head hash. In the unattended mode that is the line `stopped: tree: <error>`, followed by `; branch:`, `; base:` and `; review:` as the mode's `stopped:` line says.
7. The result is void when the base run could not start, when it did not reach all its suites, or when it ran fewer tests than the head run by more than the branch added.
8. Compare the failures. A failure is a base failure only when all of these hold; otherwise it is new:
   - the same test fails in `test-base.txt`;
   - its error text is the same, apart from addresses, hashes, times, durations, ports, block numbers and request ids. A number that the test compares, such as `expected 10, got 9`, or a status code, stays part of the text;
   - the source of the change does not name the test or its file. The source is the description in a normal run and in the unattended mode, the items in the fix-now mode, the findings in the pull request mode, and the spec and the plan in `sh:implement`;
   - the diff from the base commit does not change the file of the test.
9. Write `test-comparison.md` in the same directory, also for a void result: the base commit, the reason when the result is void, the new failures by name, and one line per base failure with its test and error text.
