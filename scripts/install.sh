#!/usr/bin/env bash
# Symlink skills from this repository into the agent skill directories.
#
#   bash scripts/install.sh                 link every skill
#   bash scripts/install.sh commit-message  link one skill
#   bash scripts/install.sh --uninstall x   remove the symlinks for one skill
#
# Skills are symlinked, not copied, so edits here take effect immediately.
# An existing real directory at a target path is never overwritten.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"
CANONICAL_DIR="$HOME/.agents/skills"
MIRROR_DIR="$HOME/.claude/skills"

uninstall=0
if [ "${1:-}" = "--uninstall" ]; then
  uninstall=1
  shift
fi

if [ ! -d "$SKILLS_DIR" ]; then
  echo "no skills directory at $SKILLS_DIR" >&2
  exit 1
fi

if [ "$#" -gt 0 ]; then
  names=("$@")
else
  names=()
  for path in "$SKILLS_DIR"/*/; do
    [ -d "$path" ] || continue
    names+=("$(basename "$path")")
  done
fi

if [ "${#names[@]}" -eq 0 ]; then
  echo "no skills found under $SKILLS_DIR" >&2
  exit 1
fi

link_skill() {
  local name="$1"
  local src="$SKILLS_DIR/$name"

  if [ ! -f "$src/SKILL.md" ]; then
    echo "skip  $name — no SKILL.md at $src" >&2
    return 1
  fi

  mkdir -p "$CANONICAL_DIR" "$MIRROR_DIR"

  local canonical="$CANONICAL_DIR/$name"
  if [ -e "$canonical" ] && [ ! -L "$canonical" ]; then
    echo "skip  $name — $canonical is a real directory, not touching it" >&2
    return 1
  fi
  ln -sfn "$src" "$canonical"

  local mirror="$MIRROR_DIR/$name"
  if [ -e "$mirror" ] && [ ! -L "$mirror" ]; then
    echo "skip  $name — $mirror is a real directory, not touching it" >&2
    return 1
  fi
  # Relative link, matching the existing layout on this machine.
  ln -sfn "../../.agents/skills/$name" "$mirror"

  echo "link  $name -> $src"
}

unlink_skill() {
  local name="$1"
  local removed=0

  for target in "$MIRROR_DIR/$name" "$CANONICAL_DIR/$name"; do
    if [ -L "$target" ]; then
      local dest
      dest="$(readlink "$target")"
      case "$dest" in
        "$REPO_ROOT"/*|../../.agents/skills/"$name")
          rm "$target"
          echo "unlink $target"
          removed=1
          ;;
        *)
          echo "skip  $target — points outside this repo ($dest)" >&2
          ;;
      esac
    elif [ -e "$target" ]; then
      echo "skip  $target — not a symlink" >&2
    fi
  done

  [ "$removed" -eq 1 ] || echo "nothing to remove for $name"
}

status=0
for name in "${names[@]}"; do
  if [ "$uninstall" -eq 1 ]; then
    unlink_skill "$name"
  else
    link_skill "$name" || status=1
  fi
done

exit "$status"
