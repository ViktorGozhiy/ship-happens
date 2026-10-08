# Plan format

An implementation plan is one Markdown file. It carries decisions, interfaces, tests and code. The implementer reads the whole plan and carries out its steps in order.

## Header

The header comes first and holds:

- the goal, in one or two sentences;
- the path of the spec;
- the constraints that apply to every task, such as rules from the project's `CLAUDE.md`, the commit message style, and files that must not change;
- the project's full test command, written out in full;
- the interfaces that more than one task uses, with names and types.

## File Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are more reliable when files are focused. Prefer smaller, focused files over large ones that do too much.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large files, don't unilaterally restructure - but if a file you're modifying has grown unwieldy, including a split in the plan is reasonable.

This structure informs the task decomposition. Each task should produce self-contained changes that make sense independently.

## Task Right-Sizing

A task is the smallest unit that carries its own test cycle. When drawing task boundaries: fold setup, configuration, scaffolding, and documentation steps into the task whose deliverable needs them; split only where each part leaves the tests green on its own. Each task ends with an independently testable deliverable. Order the tasks so that each one needs only the tasks before it.

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Task Structure

Each task has its own section in this form:

````markdown
### Task <n>: <title>

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

**Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

**Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

**Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

**Step 5: Commit**

Add: `tests/path/test.py`, `src/path/file.py`

- [ ] Task <n> done
````

- Number the steps and give them no checkbox. Each step is one action.
- Write test code and production code out in full.
- The commit step lists the files to add and nothing else. The implementer writes the commit message by its own rules and adds the plan file itself.
- The line `- [ ] Task <n> done` is the last line of the section and the only checkbox of the task. An unchecked task is one whose `- [ ] Task <n> done` line is unticked.
- A task whose deliverable is a document or a measurement writes its commands and its text in fenced blocks too. A slot for a value that the run produces, such as `<measured count>`, is not a placeholder. A task with no fenced block in any step is a plan failure.

## No Placeholders

Every step must contain the actual content an engineer needs. These are **plan failures** — never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code — the engineer may be reading tasks out of order)
- Steps that describe what to do without showing how (code blocks required for code steps)
- References to types, functions or methods not defined in the tree or in any task

## Size Check

A plan has at most 12 tasks. Count the tasks before you write the plan. When the spec needs more, write no plan, and return `blocked: the spec needs <n> tasks; split point: <after which requirement the code is working and tested>`. Viktor chooses where to split. The requirements after the split point move out of the spec body into a `## Deferred` section of the spec, and the plan covers what remains in the body. A requirement under `## Deferred` is not a requirement of the plan.

## Deliverable names

Never name a file `report.md`, `findings.md` or `summary.md`. Name a document deliverable by its subject, for example `attempt-cost.md`.

## Open choices

When the spec leaves a choice open, make the choice in the plan. Start the line that states it with `Decided in plan:`, so that a reviewer can find every choice the spec did not make.

## Finishing

The last section is `## Finishing (main session)`. It lists the branch review, the full test run, the push and the pull request. The implementer never runs this section. The push and the pull request happen only if Viktor chooses them in the final question of the implementation run.
