#!/bin/bash
# PostToolUse hook: runs helm lint and yamllint after every file write.
# Triggered for: replace_string_in_file, create_file, multi_replace_string_in_file
#
# Exit 0  → success (silent)
# Exit 2  → lint failure (blocking — agent must acknowledge and fix)
# Stdout  → JSON { "systemMessage": "..." } shown to the agent

set -uo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# Collect file paths to validate
declare -a FILES=()
case "$TOOL" in
  replace_string_in_file|create_file)
    FILE=$(echo "$INPUT" | jq -r '.tool_input.filePath // empty')
    [[ -n "$FILE" ]] && FILES+=("$FILE")
    ;;
  multi_replace_string_in_file)
    while IFS= read -r f; do
      [[ -n "$f" ]] && FILES+=("$f")
    done < <(echo "$INPUT" | jq -r '.tool_input.replacements[].filePath' 2>/dev/null | sort -u)
    ;;
  *)
    exit 0
    ;;
esac

[[ ${#FILES[@]} -eq 0 ]] && exit 0

ERRORS=""
OK=""
LINTED_CHARTS=""  # track charts already linted to avoid duplicates

for FILE in "${FILES[@]}"; do
  # Normalise path: strip leading slash if absolute so we can find the chart root
  REL_FILE="${FILE#/}"
  REL_FILE="${REL_FILE#$(pwd)/}"  # strip cwd prefix if present

  # ── yamllint ────────────────────────────────────────────────────────────────
  if [[ "$FILE" =~ \.(yaml|yml)$ ]] && command -v yamllint &>/dev/null; then
    RESULT=$(yamllint -d '{extends: relaxed, rules: {line-length: disable, truthy: disable}}' "$FILE" 2>&1) && RC=0 || RC=$?
    if [[ $RC -ne 0 ]]; then
      ERRORS+="yamllint ${FILE}:\n${RESULT}\n\n"
    else
      OK+="✓ yamllint ${FILE}\n"
    fi
  fi

  # ── helm lint ────────────────────────────────────────────────────────────────
  if command -v helm &>/dev/null && [[ "$REL_FILE" == k8s/charts/* || "$FILE" == */k8s/charts/* ]]; then
    # Walk up from file's directory to find the Chart.yaml
    CHART_ROOT=""
    SEARCH="$(dirname "$FILE")"
    for _ in 1 2 3 4 5; do
      if [[ -f "${SEARCH}/Chart.yaml" ]]; then
        CHART_ROOT="$SEARCH"
        break
      fi
      SEARCH="$(dirname "$SEARCH")"
    done

    if [[ -n "$CHART_ROOT" ]] && ! grep -qF "$CHART_ROOT" <<<"$LINTED_CHARTS"; then
      LINTED_CHARTS+="$CHART_ROOT "
      RESULT=$(helm lint "$CHART_ROOT" 2>&1) && RC=0 || RC=$?
      if [[ $RC -ne 0 ]]; then
        ERRORS+="helm lint ${CHART_ROOT}:\n${RESULT}\n\n"
      else
        OK+="✓ helm lint ${CHART_ROOT}\n"
      fi
    fi
  fi
done

if [[ -n "$ERRORS" ]]; then
  MSG="🔴 Lint errors detected — fix before continuing:\n\n${ERRORS}"
  [[ -n "$OK" ]] && MSG+="(Passed: ${OK})"
  printf '{"decision":"block","reason":%s}\n' "$(printf '%s' "$MSG" | jq -Rs .)"
  exit 2
fi

# All passed — silent success (no noise when everything is fine)
exit 0
