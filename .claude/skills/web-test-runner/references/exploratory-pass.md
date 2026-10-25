# Exploratory Pass

Read when: the scripted suite (the cases the user gave you, or that were
generated and approved) has finished running, and there's remaining budget
for an unscripted look at the app.

## Purpose

The scripted suite only checks what someone thought to write down. An
exploratory pass looks for problems nobody wrote a case for: broken states
reachable by combining actions in an order the suite didn't try, console
errors that never surfaced as a UI failure, dead links, obviously broken
layouts.

This is **supplementary**, not a replacement for the scripted suite, and it
runs only after the scripted suite is done — don't let exploration eat the
budget meant for the cases the user actually asked for.

## What counts as a finding here (and the Red Line it interacts with)

An exploratory finding is a candidate bug report, **not** a new test case
added to `results.json` as if it were part of the requested suite (SKILL.md
§7 Red Lines: never fabricate a case for something found during
exploration). Keep exploratory findings in a separate section of the
summary/report — clearly labeled as exploratory, with enough evidence
(screenshot, console log, steps to reproduce) that the user can decide
whether it's worth a real test case later.

## How to explore

- Pick a time/action budget up front (e.g. "10 more actions" or "5
  minutes") and stick to it — exploration can expand indefinitely
  otherwise.
- Prioritize paths adjacent to what the suite already covered: edge values
  the suite didn't try, error states the suite didn't trigger, navigation
  sequences the suite didn't chain together.
- Watch the console and network panel passively while exploring — a lot of
  real findings surface there even when the UI looks fine.
- Same Token Discipline rules apply: one snapshot per new screen, artifacts
  to files, don't narrate every click.

## Reporting

Add an "Exploratory findings" section to the summary, separate from the
case-by-case results, with: what you tried, what went wrong, evidence, and
(if you have a guess) which of the 6 triage groups it looks like it'd fall
into. Never mark these `passed`/`failed` in the formal sense — they're
observations for a human to triage, not verified test results.
