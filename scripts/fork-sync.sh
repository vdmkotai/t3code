#!/usr/bin/env bash
#
# fork-sync.sh — pull the latest upstream (pingdotgg/t3code) into your personal
# fork's integration branch (`fork-build`), verify the carried changes still
# build, and push. Run it whenever you want to catch up — daily or every few
# days. The daily CI does the same thing automatically; this is the manual path.
#
#   ./scripts/fork-sync.sh
#
# Model: `fork-build` is the ONE branch that accumulates all your local changes
# (the #3604 OpenCode resume fix, sub-agent visibility, …). We MERGE upstream in
# (never rebase), so the branch only moves forward and your own commits are safe.
# Conflicts are recorded by `git rerere` and replayed automatically next time.

set -euo pipefail

INTEGRATION_BRANCH="fork-build"

say() { printf '\033[1;36m▸ %s\033[0m\n' "$*"; }
die() { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# --- Locate remotes by URL so this works from a fork clone OR the dev worktrees.
upstream_remote=""
fork_remote=""
for r in $(git remote); do
  url="$(git remote get-url "$r")"
  case "$url" in
    *pingdotgg/t3code*) upstream_remote="$r" ;;
    *vdmkotai/t3code*)  fork_remote="$r" ;;
  esac
done
[ -n "$upstream_remote" ] || die "No remote points at pingdotgg/t3code (upstream). Add one: git remote add upstream https://github.com/pingdotgg/t3code.git"
[ -n "$fork_remote" ]     || die "No remote points at vdmkotai/t3code (your fork)."
say "upstream = $upstream_remote, fork = $fork_remote"

# --- Make conflict resolutions sticky across syncs.
git config rerere.enabled true

# --- Refuse to run on a dirty tree (a half-done merge would be a mess).
git diff --quiet && git diff --cached --quiet || die "Working tree is dirty — commit or stash first."

current_branch="$(git rev-parse --abbrev-ref HEAD)"
[ "$current_branch" = "$INTEGRATION_BRANCH" ] || die "Switch to $INTEGRATION_BRANCH first (you are on $current_branch)."

say "Fetching $upstream_remote/main …"
git fetch --no-tags "$upstream_remote" main

say "Merging $upstream_remote/main into $INTEGRATION_BRANCH …"
if ! git merge --no-edit "$upstream_remote/main"; then
  cat >&2 <<EOF

  ⚠ Merge hit a conflict (usually in the files our patches touch:
    apps/server/src/provider/Layers/OpenCodeAdapter.ts, the timeline/session-logic UI).

  Resolve the marked files, then:
    git add -A && git commit       # finish the merge
    ./scripts/fork-sync.sh         # re-run to verify + push
EOF
  exit 1
fi

say "Verifying the carried changes (typecheck + key tests) …"
corepack pnpm install --frozen-lockfile --prefer-offline >/dev/null
corepack pnpm --filter t3 run typecheck
corepack pnpm --filter @t3tools/web run typecheck
corepack pnpm --filter t3 exec vp test run \
  src/provider/Layers/OpenCodeAdapter.test.ts \
  src/orchestration/Layers/ProviderRuntimeIngestion.test.ts
corepack pnpm --filter @t3tools/web exec vp test run \
  src/session-logic.test.ts \
  src/components/chat/MessagesTimeline.logic.test.ts

say "Pushing $INTEGRATION_BRANCH to $fork_remote …"
git push "$fork_remote" "$INTEGRATION_BRANCH"

say "Done. fork-build is current with upstream and pushed."
