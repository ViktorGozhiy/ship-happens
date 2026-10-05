---
name: debugging
description: Use when a bug, a failing test or unexpected behaviour needs its root cause found before any fix.
---

# Debugging

Find the root cause of a failure and hand it over. You write no test and no fix. Propose no fix before the root cause is known.

## Steps

1. Reproduce the failure. Note the exact steps. When you cannot reproduce it reliably, gather more data.
2. Read the whole error text, the stack trace and the logs. Note file paths, line numbers and error codes.
3. Check what changed recently: commits, dependencies, configuration and environment.
4. When the system has several components, find where it breaks. Log or print what enters and leaves each component, run once, and read the result. Trace a bad value backward through its callers to its source.
5. Find similar code that works and list every difference from the code that fails.
6. State one hypothesis: "I think X is the cause because Y". Test it with the smallest possible change, one variable at a time. When the test disproves it, discard that change and form a new hypothesis. Never stack changes.
7. When three hypotheses have failed, or each one exposes a new problem elsewhere, stop and tell Viktor that the design may be wrong. When you do not understand something, say so and ask.

## Handover

End with a statement of three parts: the root cause, the evidence for it, and a description of the test that fails because of the root cause. Remove any diagnostic output you added.

Pass the statement as the description of the change to `sh:quick-fix`, where `sh:implementer` writes the failing test first. When the fix changes a design, pass it as the idea to `sh:design`.
