#!/bin/zsh
# Build the latest upstream pi-ui plus every committed local customization.
# The customization checkout is never rebased, reset, or modified here.

set -uo pipefail

readonly REPO="/Users/sunithv/Developer/pi-ui"
readonly BRANCH="sunithv/custom"
readonly APP="/Users/sunithv/Applications/Pi UI Local.app"
readonly LOG_DIR="/Users/sunithv/Library/Logs/pi-ui-local"
readonly STATE_DIR="/Users/sunithv/Library/Application Support/pi-ui-local"
readonly LOCK_DIR="${TMPDIR:-/tmp}/pi-ui-local-update-${UID}.lock"

mkdir -p "$LOG_DIR" "$STATE_DIR"
exec >>"$LOG_DIR/update.log" 2>&1

notify_error() {
  /usr/bin/osascript -e 'display notification "error" with title "pi-ui update"' >/dev/null 2>&1 || true
}

fail() {
  print -r -- "$(date '+%Y-%m-%d %H:%M:%S') error"
  notify_error
  exit 1
}

# Do not run concurrent builds. A missed interval is harmless: the next one
# will pick up the latest upstream revision.
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  exit 0
fi

WORKTREE=""
cleanup() {
  if [[ -n "$WORKTREE" && -d "$WORKTREE" ]]; then
    git -C "$REPO" worktree remove --force "$WORKTREE" >/dev/null 2>&1 || true
  fi
  rmdir "$LOCK_DIR" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

cd "$REPO" || fail

# Never auto-update on top of edits Pi or you have not committed. That is how
# changes stay recoverable even when upstream makes an incompatible change.
git diff --quiet || fail
git diff --cached --quiet || fail
[[ -z "$(git ls-files --others --exclude-standard)" ]] || fail

git fetch --quiet upstream main || fail

BASE="$(git merge-base "upstream/main" "$BRANCH")" || fail
WORKTREE="$(mktemp -d "${TMPDIR:-/tmp}/pi-ui-local-build.XXXXXX")" || fail
git -C "$REPO" worktree add --detach "$WORKTREE" upstream/main >/dev/null || fail

# Replay the user's commits in a disposable worktree. A cherry-pick conflict
# leaves both the development branch and installed app unchanged.
while IFS= read -r commit; do
  [[ -z "$commit" ]] && continue
  git -C "$WORKTREE" cherry-pick --no-edit "$commit" >/dev/null 2>&1 || {
    git -C "$WORKTREE" cherry-pick --abort >/dev/null 2>&1 || true
    fail
  }
done < <(git rev-list --reverse "$BASE..$BRANCH")

TARGET_REVISION="$(git -C "$WORKTREE" rev-parse HEAD)" || fail
if [[ -f "$STATE_DIR/last-successful-revision" && "$(<"$STATE_DIR/last-successful-revision")" == "$TARGET_REVISION" ]]; then
  exit 0
fi

cd "$WORKTREE" || fail
/opt/homebrew/bin/deno task build || fail
[[ -d "$WORKTREE/dist/macos/pi-ui.app" ]] || fail

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pi-ui-local-app.XXXXXX")" || fail
/usr/bin/ditto "$WORKTREE/dist/macos/pi-ui.app" "$STAGING_DIR/Pi UI Local.app" || fail

# Swap only after a complete build exists. Keep the last good bundle if the
# final move fails; no partial build ever replaces the usable app.
BACKUP="${APP}.previous"
rm -rf "$BACKUP"
if [[ -d "$APP" ]]; then
  mv "$APP" "$BACKUP" || fail
fi
if ! mv "$STAGING_DIR/Pi UI Local.app" "$APP"; then
  [[ -d "$BACKUP" ]] && mv "$BACKUP" "$APP" || true
  fail
fi
rm -rf "$BACKUP" "$STAGING_DIR"
print -r -- "$TARGET_REVISION" > "$STATE_DIR/last-successful-revision"
print -r -- "$(date '+%Y-%m-%d %H:%M:%S') updated $TARGET_REVISION"
