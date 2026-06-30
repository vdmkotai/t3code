# Maintaining this fork

This is a personal fork of [`pingdotgg/t3code`](https://github.com/pingdotgg/t3code).
It carries local changes that aren't (yet) upstream, while staying current with
upstream's daily nightlies.

## Branch model

| Branch | Role |
|---|---|
| **`fork-build`** | **The branch.** A single integration branch that *accumulates every local change* — the #3604 OpenCode resume fix, the sub-agent visibility feature, the parallel-install build patches, and anything added later. This is what the CI builds and what you install. Kept current by **merging** upstream into it. |
| `fix/3604-opencode-session-resume` | Clean mirror of the #3604 fix, used only for the upstream PR (#3617). Don't develop on it day to day. |
| `feature/subagent-visibility` | Clean feature branch for the sub-agent work (handy for a tidy record / future review). New work merges into `fork-build`. |
| `main` | Untouched mirror of upstream `main`. |

Why **merge**, not rebase: `fork-build` is long-lived and you keep appending your
own commits to it, so it must only ever move *forward*. Merging upstream in never
rewrites history and never needs a force-push. (Rebase is reserved for the clean
PR branch, which must stay linear for review.)

## Keeping current with upstream

Two equivalent paths — pick either:

- **Automatic:** the `Fork sync + build` GitHub Action runs daily (06:00 UTC). It
  merges upstream into `fork-build`, runs the typecheck + the #3604 and sub-agent
  test suites, builds an unsigned arm64 DMG, and publishes it to the rolling
  `fork-build-latest` prerelease. On a conflict or build failure it opens an issue
  and changes nothing. You can also trigger it by hand ("Run workflow").

- **Manual:** from a checkout on `fork-build`:
  ```sh
  ./scripts/fork-sync.sh
  ```
  Fetches upstream, merges it in, verifies, and pushes. On a conflict it tells you
  exactly which files to resolve, then re-run it.

Run `git config --global rerere.enabled true` once: git then *remembers* how you
resolved a conflict and replays it automatically on the next sync, so the same
upstream churn doesn't bite you twice.

## Adding a new local change

1. Branch from `fork-build` (so you build on top of everything you already carry):
   `git switch -c feature/<name> fork-build`.
2. Build + verify it.
3. Land it on `fork-build`: `git switch fork-build && git merge --no-edit feature/<name>`.
4. `./scripts/fork-sync.sh` (or just push) — the next CI build includes it.

If a change is also worth sending upstream, additionally keep a clean topic branch
off `main` for the PR (like `fix/3604-opencode-session-resume`). When/if it merges
upstream, it arrives via the normal sync and you can drop the local copy.

## The installable build

The DMG installs **alongside** your primary T3 Code — separate bundle id
(`com.t3tools.t3code.fork3604`), app name "T3 Code (Fork 3604)", isolated data dir
`~/.t3-fork3604` — so it never touches your main install's state. Grab the latest
from the `fork-build-latest` release. First launch (unsigned): right-click → Open,
or `xattr -dr com.apple.quarantine "/Applications/T3 Code (Fork 3604).app"`.
