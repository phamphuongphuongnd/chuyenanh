---
name: project-map-detail
description: Alias for the project-map skill with its mode preselected. The trigger is a literal string match only — the user must type "project-map-detail", as a slash command or as plain text. Never select this skill from the meaning of a request. Any request phrased in natural language, in any language, however thorough or exhaustive it asks the analysis to be, goes to the project-map skill instead, which chooses its own mode.
---

# project-map-detail

This is a shortcut, not a separate skill. It exists so that typing
`/project-map-detail` selects detail mode without having to phrase the request.

**Do this:** read `../project-map/SKILL.md` and follow it, running **detail
mode** — the three-document output (`index.md`, `technical.md`, `business.md`)
under `docs/project-map/`. Skip the mode-detection step; the mode is already
decided. Everything else in that skill applies unchanged, including the
permission question asked once before reading environment files or connecting to
a database, and the rebuild bar applied to the pair of documents.

If the invocation names a specific feature or flow, scope the detail work to it
rather than cataloguing the whole project, as described under "Two modes" there.

Still announce the mode in one sentence before starting, so the user sees that a
long job is beginning and can stop it if they meant the overview.
