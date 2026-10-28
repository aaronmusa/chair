# Contributing to Chair

Chair is built one ticket at a time: each GitHub issue is one branch and one pull
request, squash-merged into `main`. There is no hosted CI; the checks run on your
machine, before you commit and before you push.

## First time after cloning

```
make hooks
```

This installs two git hooks:

- `pre-commit` runs SwiftLint and SwiftFormat on the staged Swift files.
- `pre-push` runs ChairKit's tests.

Never bypass them with `--no-verify`. If a hook is slow or wrong, fix the hook.

If `core.hooksPath` is set globally, git stops looking in `.git/hooks`, so the
global hooks have to chain to the repo's own. `make hooks` warns when it sees one.

Build with the Xcode named in `.xcode-version`; `make build` warns when the
installed one differs.

## Tickets and branches

Tickets come from the epic docs and are mirrored in `docs/EPICS/`. Each issue is
titled `E<N>-<k> <Title>` and labelled `epic-<N>` plus `ready-for-agent` or
`ready-for-human`.

- One ticket per branch, always from an up-to-date `main`: `<type>/E<N>-<k>-<slug>`,
  where `<type>` is `feat`, `fix`, `docs` or `build`. Example: `feat/E0-2-lint`.
- Work with no ticket: `<type>/<slug>`.
- Never commit straight to `main`, and never start a branch from another
  unmerged one.

## Commits

```
[<scope>] <imperative summary under 72 characters>
```

The body says why. No AI attribution trailers. Examples:

```
[design] Add colour tokens with light and dark values
[db] Add core schema with RLS and pgTAP tests
```

## Pull requests

- Title: `[E<N>-<k>] <summary>`, or `[<scope>] <summary>` with no ticket.
- The body opens with `Closes #<issue>` when every acceptance criterion is met.
  When a human step remains, it opens with `Part of #<issue>` instead.
- Then the body has three parts:
  - What's in it.
  - How each criterion was verified.
  - What still needs a human.
- Squash-merge and delete the branch.
- A ticket with code closes only through a merged PR that says `Closes #<issue>`.
  Tickets with no code (portal, console or device work) are closed by hand, with
  a comment saying what was done.

## Checks before the last commit

| When | Command |
|---|---|
| Every ticket | `make lint`, and `make test UI=<Suites>` naming only the UI suites the change touches |
| Backend tickets | `make test-db` and `make test-functions` too |
| End of an epic | `make test-all` and `make test-db` |

`make test-kit` runs ChairKit alone, with no simulator. `make coverage` runs it with coverage and fails if any file in `ChairKit/Engine` is below 100 %. To re-record the announcement golden file after an intended change, run `CHAIR_RECORD_GOLDEN=1 make test-kit`.

## Releases

Build numbers change only through `make bump`, committed in a PR. To ship to
TestFlight, run `make testflight` on an up-to-date `main`; it moves the
`xcbuild/testflight` tag that Xcode Cloud watches. Run through
`docs/RELEASE_CHECKLIST.md` before every upload.
