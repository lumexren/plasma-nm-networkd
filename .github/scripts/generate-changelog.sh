#!/usr/bin/env bash

# SPDX-License-Identifier: GPL-3.0-only
#
# Copyright (c) 2026 lumexren
#
# Changelog generator script for Forgejo/Gitea release workflows.
# Categorizes conventional commits, removes release bumps/merges,
# and compares against the appropriate reference tag.

set -euo pipefail

MODE="stable"
FROM_REF=""
TO_REF="HEAD"
OUTPUT=""
CURRENT_VERSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --from)
      FROM_REF="$2"
      shift 2
      ;;
    --to)
      TO_REF="$2"
      shift 2
      ;;
    --version)
      CURRENT_VERSION="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# If FROM_REF is not explicitly given, automatically resolve it
if [[ -z "$FROM_REF" ]]; then
  if [[ "$MODE" == "stable" ]]; then
    # In stable mode, find the most recent stable ancestor tag
    EXCLUDE_ARGS=(--exclude='*-*' --exclude='pre-*' --exclude='staging-*')
    if [[ -n "$CURRENT_VERSION" ]]; then
      EXCLUDE_ARGS+=(--exclude="$CURRENT_VERSION" --exclude="v$CURRENT_VERSION")
    fi

    FROM_REF=$(git describe --tags --abbrev=0 "${EXCLUDE_ARGS[@]}" "$TO_REF" 2>/dev/null || echo "")

    # If the tag points to the same commit as TO_REF, look at the parent commit
    if [[ -n "$FROM_REF" ]] && [[ "$(git rev-parse "$FROM_REF^{commit}")" == "$(git rev-parse "$TO_REF^{commit}")" ]]; then
      FROM_REF=$(git describe --tags --abbrev=0 "${EXCLUDE_ARGS[@]}" "${FROM_REF}^" 2>/dev/null || echo "")
    fi
  else
    # In staging / pre-release mode, find immediate preceding tag
    EXCLUDE_ARGS=()
    if [[ -n "$CURRENT_VERSION" ]]; then
      EXCLUDE_ARGS+=(--exclude="$CURRENT_VERSION" --exclude="v$CURRENT_VERSION")
    fi

    FROM_REF=$(git describe --tags --abbrev=0 "${EXCLUDE_ARGS[@]}" "$TO_REF" 2>/dev/null || echo "")

    if [[ -n "$FROM_REF" ]] && [[ "$(git rev-parse "$FROM_REF^{commit}")" == "$(git rev-parse "$TO_REF^{commit}")" ]]; then
      FROM_REF=$(git describe --tags --abbrev=0 "${EXCLUDE_ARGS[@]}" "${FROM_REF}^" 2>/dev/null || echo "")
    fi
  fi
fi

generate() {
  if [[ -n "$FROM_REF" ]]; then
    echo "### Changes since $FROM_REF"
    COMMITS_RAW=$(git log "${FROM_REF}..${TO_REF}" --no-merges --format="%H%x09%s" || true)
  else
    echo "### Initial release"
    COMMITS_RAW=$(git log "${TO_REF}" --no-merges --format="%H%x09%s" || true)
  fi

  FEATS=()
  FIXES=()
  PERFS=()
  REFACTORS=()
  DOCS=()
  BUILDS=()
  OTHERS=()

  while IFS=$'\t' read -r hash subject; do
    [[ -z "$hash" || -z "$subject" ]] && continue

    # Filter out release bump and tagging commits
    if [[ "$subject" =~ ^chore\(release\):|^chore\(release-bump\):|^bump\ version\ to ]]; then
      continue
    fi

    short_hash="${hash:0:7}"
    entry="- ${subject} (${short_hash})"

    case "$subject" in
      feat*|Feat*)
        FEATS+=("$entry") ;;
      fix*|Fix*)
        FIXES+=("$entry") ;;
      perf*|Perf*)
        PERFS+=("$entry") ;;
      refactor*|Refactor*|style*|Style*)
        REFACTORS+=("$entry") ;;
      docs*|Docs*)
        DOCS+=("$entry") ;;
      ci*|CI*|build*|Build*)
        BUILDS+=("$entry") ;;
      *)
        OTHERS+=("$entry") ;;
    esac
  done <<< "$COMMITS_RAW"

  total_count=$(( ${#FEATS[@]} + ${#FIXES[@]} + ${#PERFS[@]} + ${#REFACTORS[@]} + ${#DOCS[@]} + ${#BUILDS[@]} + ${#OTHERS[@]} ))

  if [[ $total_count -eq 0 ]]; then
    echo -e "\nNo significant changes."
  else
    print_sec() {
      local title="$1"
      shift
      local items=("$@")
      if [[ ${#items[@]} -gt 0 ]]; then
        echo -e "\n#### $title"
        for item in "${items[@]}"; do
          echo "$item"
        done
      fi
    }

    print_sec "🚀 Features" "${FEATS[@]+"${FEATS[@]}"}"
    print_sec "🐛 Bug Fixes" "${FIXES[@]+"${FIXES[@]}"}"
    print_sec "⚡ Performance" "${PERFS[@]+"${PERFS[@]}"}"
    print_sec "♻️ Refactoring" "${REFACTORS[@]+"${REFACTORS[@]}"}"
    print_sec "📝 Documentation" "${DOCS[@]+"${DOCS[@]}"}"
    print_sec "🔧 Build & CI" "${BUILDS[@]+"${BUILDS[@]}"}"
    print_sec "📦 Other Changes" "${OTHERS[@]+"${OTHERS[@]}"}"
  fi
}

if [[ -n "$OUTPUT" ]]; then
  generate > "$OUTPUT"
else
  generate
fi
