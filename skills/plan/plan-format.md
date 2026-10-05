# Plan format

An implementation plan is one Markdown file of at most 15 KB. It carries decisions, interfaces and acceptance criteria. It does not carry code.

## Header

The header comes first and holds:

- the goal, in one or two sentences;
- the path of the spec;
- the constraints that apply to every task, such as rules from the project's `CLAUDE.md`, the commit message style, and files that must not change;
- the project's full test command, written out in full;
- the interfaces that more than one task uses, with names and types.

## Tasks

A task is the smallest unit of work that leaves the test suite green and can be reviewed alone. Order the tasks so that each one needs only the tasks before it.

Each task has its own section with a heading `### Task <n>: <title>` and these parts in order:

- what the task delivers;
- the files to create or change;
- the signatures and types that other tasks depend on;
- the acceptance criteria, each one checkable by running something or reading a named file;
- the tests to write, named by the behaviour they check;
- the checkbox `- [ ] Task <n> done`, as the last line of the section.

## No function bodies

Do not write function bodies or test bodies. Write signatures, types, file paths and behaviour.

The exception is text that is itself the decision, such as an SQL migration, a configuration key, a command line or a regular expression. Write that text exactly.

## Open choices

When the spec leaves a choice open, make the choice in the plan. Start the line that states it with `Decided in plan:`, so that a reviewer can find every choice the spec did not make.

## Finishing

The last section is `## Finishing (main session)`. It lists the branch review, the full test run, the push and the pull request. The implementer never runs this section. The push and the pull request happen only after Viktor has answered the final question of the implementation run.
