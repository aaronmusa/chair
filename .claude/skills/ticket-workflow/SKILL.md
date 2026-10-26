---
name: ticket-workflow
description: File an epic's tickets as GitHub issues and build them one pull request at a time, the PicklGo way. Use for "/ticket-workflow file <epic doc link>", "/ticket-workflow next", "/ticket-workflow start E0-5" or "#12", or any request to file tickets, pick the next ticket, open a PR for a ticket, or merge it.
---

# Ticket workflow

Epics and ticket text are written in the Claude app with the `epic-tickets` skill and live in a Claude doc. This skill turns that doc into GitHub issues and then builds each ticket as one branch, one PR, squash-merged into `main`.

The repo is the one `gh` infers from `git remote -v`. The test commands are the ones `CLAUDE.md` names under Testing: a scoped run per ticket, the full suite at the end of an epic.

## Conventions

| Thing | Format | Example |
|---|---|---|
| Epic | No epic issue. An `epic-<N>` label groups its tickets; the doc and `docs/EPICS/EPIC-<N>.md` hold the rest | `epic-0` |
| Ticket issue title | `E<N>-<k> <Title>` | `E0-5 Colour tokens` |
| Ticket labels | `epic-<N>` plus `ready-for-agent` (Claude Code builds it) or `ready-for-human` (portal or device work) | |
| Ticket body | `## What to build`, `## Acceptance criteria` (checkboxes), `## Blocked by` (issue numbers) | |
| Branch | `<type>/E<N>-<k>-<slug>`; type is `feat`, `fix`, `docs` or `build`. Work with no ticket: `<type>/<slug>` | `feat/E0-5-colour-tokens` |
| Commit | `[<scope>] <imperative summary>`, under 72 characters; the body says why. No AI attribution trailers | `[design] Add colour tokens and contrast test` |
| PR title | `[E<N>-<k>] <summary>`; no ticket: `[<scope>] <summary>` | `[E0-5] Add colour tokens and contrast test` |
| Merge | Squash, delete the branch | `gh pr merge <n> --squash --delete-branch` |

## `file <epic doc link>`

1. Read the whole doc with the Claude Docs tools (never web-fetch it). Take ticket text verbatim.
2. Draft every issue, one per `E<N>-<k>` heading:
   - Title `E<N>-<k> <Title>` (drop a `(human)` marker from the title).
   - Body: the ticket's lead sentence and bullets under `## What to build`, its acceptance checklist under `## Acceptance criteria`, and `## Blocked by` listing the blockers (filled with issue numbers once they exist; omit the section when nothing blocks it).
   - Labels: `epic-<N>` and `ready-for-human` when marked `(human)`, else `ready-for-agent`.
3. Show the drafts as a short table (ticket, title, labels, blocked by) and wait for a go-ahead before creating anything.
4. Create missing labels, then the issues in ticket order. Rewrite each `## Blocked by` with the real issue numbers, and add GitHub's native blocked-by links: `gh api --method POST repos/<owner>/<repo>/issues/<n>/dependencies/blocked_by -F issue_id=<blocker database id>` (`gh api repos/<owner>/<repo>/issues/<m> --jq .id`).
5. Mirror the doc into `docs/EPICS/EPIC-<N>.md` with each ticket heading followed by its issue number, and commit it on a `docs/E<N>-epic` branch through a PR.

## `next`

List open issues labelled `epic-<N>` and `ready-for-agent` with no open blockers (`issue_dependencies_summary.blocked_by == 0`) and no assignee. The lowest ticket number wins. Say which one and why the others are waiting.

## `start <ticket>`

1. `git checkout main && git pull --ff-only`, then branch `<type>/E<N>-<k>-<slug>`. Never start from another ticket's branch.
2. `gh issue view <n> --comments`. Plan against its acceptance criteria; if one cannot be met as written, stop and say so before coding.
3. Build it. Commit in small `[scope]` commits as you go. Before the last commit run the test command with only the UI suites the ticket touches; run the full suite once at the end of the epic. `git push` runs the fast suite through the pre-push hook. Never `--no-verify`.
4. Check every acceptance criterion yourself: run the command, open the simulator, render the preview. Keep notes of what you saw.

## Opening the PR

`gh pr create --title "[E<N>-<k>] <summary>" --body-file <file>`, writing the body to a file first. The body, in first person as the author:

```
Closes #<issue>

<One or two sentences: what this does and why, in plain words.>

**What's in here**

- <file or type> — <what changed and any decision a reviewer should know>

**Verification**

- <each acceptance criterion and exactly how it was checked, with test counts>

**Still needs a human**

- <anything not verified here: real devices, portals, purchases>. Omit the section when there is nothing.
```

Use `Closes #<issue>` only when every acceptance criterion is met. When part of a ticket needs a human, write `Part of #<issue>` instead, and after merging comment on the issue with the remaining steps as a checklist.

## Merging

1. The scoped test command passes on the branch (the full one for the last ticket of an epic), and every criterion in the PR body is either verified or listed under "Still needs a human".
2. `gh pr merge <n> --squash --delete-branch`, then `git checkout main && git pull --ff-only`.
3. Tick the acceptance checkboxes on the issue that were verified. `Closes` closes the issue; otherwise leave it open with the checklist comment.
4. Move to `next` only when asked to keep going.

## Closing issues

- A ticket that involves code closes only when a merged PR says `Closes #<issue>`. Never close it with `gh issue close`, and never close it from a commit pushed to `main`.
- A ticket that is split across PRs uses `Part of #<issue>` on each and `Closes #<issue>` on the last one.
- A ticket with no code at all (portal, console or device work) is closed by hand, with a comment saying what was done and how it was checked.

## Never

- Commit straight to `main`, or stack a ticket branch on another unmerged one.
- Close a code ticket any way other than a merged PR that references it.
- Edit the epic doc's ticket text to make a ticket easier; flag the mismatch instead.
- Close an issue whose acceptance criteria are not all met.
