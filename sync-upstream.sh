#!/bin/bash
# Refresh the bundled copies of Claude Squad and OpenHands from upstream.
# Usage: bash sync-upstream.sh            # both
#        bash sync-upstream.sh claude-squad
#        bash sync-upstream.sh openhands
# Review with `git diff --stat`, then commit. Local edits inside the folders are overwritten.

set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

sync_one() {
  local folder="$1" url="$2" license="$3"
  echo "▶ Fetching $url"
  git clone -q --depth 1 "$url" "$TMP/$folder"
  local sha date
  sha=$(git -C "$TMP/$folder" rev-parse HEAD)
  date=$(git -C "$TMP/$folder" log -1 --format=%cs)
  rm -rf "${DIR:?}/$folder"
  mkdir -p "$DIR/$folder"
  git -C "$TMP/$folder" ls-files -z | rsync -a -0 --files-from=- "$TMP/$folder/" "$DIR/$folder/"
  git -C "$DIR" add -A -f "$folder"
  sed -i.bak "s#^| $folder | .*#| $folder | $url | \`$sha\` | $date | $license |#" "$DIR/UPSTREAM.md"
  rm -f "$DIR/UPSTREAM.md.bak"
  echo "✓ $folder → $sha ($date)"
}

case "${1:-all}" in
  claude-squad) sync_one claude-squad https://github.com/smtg-ai/claude-squad.git AGPL-3.0 ;;
  openhands)    sync_one openhands https://github.com/OpenHands/OpenHands.git MIT ;;
  all)
    sync_one claude-squad https://github.com/smtg-ai/claude-squad.git AGPL-3.0
    sync_one openhands https://github.com/OpenHands/OpenHands.git MIT ;;
  *) echo "Unknown target: $1 (use claude-squad, openhands, or nothing for both)"; exit 1 ;;
esac

echo "Done. Review: git diff --cached --stat"
