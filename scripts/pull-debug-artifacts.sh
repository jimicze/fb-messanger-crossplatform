#!/usr/bin/env bash
# Downloads all debug artifacts from the latest completed Test Build CI run
# that used actions/upload-artifact (i.e. has Actions artifacts, not release assets).
# Output goes to dist/debug/ (already gitignored via dist/).
#
# Usage:
#   npm run artifacts:pull          # latest completed run with artifacts
#   npm run artifacts:pull -- 12345 # specific run ID
#
# Requires: gh CLI (https://cli.github.com) authenticated with repo access.

set -euo pipefail

WORKFLOW="Test Build"
OUT_DIR="dist/debug"

# Resolve owner/repo from gh context so this script works on any fork.
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')

# ── Find run ID ────────────────────────────────────────────────────────────
if [ "${1-}" != "" ]; then
    RUN_ID="$1"
    echo "Using run ID: ${RUN_ID}"
else
    echo "Looking for the latest completed '${WORKFLOW}' run with Actions artifacts..."

    RUN_ID=""
    # Iterate recent completed runs; stop at the first one that has artifacts.
    while IFS= read -r id; do
        ARTIFACT_COUNT=$(gh api "repos/${REPO}/actions/runs/${id}/artifacts" \
            --jq '.total_count' 2>/dev/null || echo 0)
        if [ "${ARTIFACT_COUNT}" -gt "0" ]; then
            RUN_ID="${id}"
            break
        fi
    done < <(gh run list \
        --workflow="${WORKFLOW}" \
        --json databaseId,status \
        --jq '[.[] | select(.status=="completed")] | .[].databaseId')

    if [ -z "${RUN_ID}" ]; then
        echo ""
        echo "ERROR: No completed '${WORKFLOW}' run with Actions artifacts found." >&2
        echo ""
        echo "  This can happen if all recent runs used the old public-release upload" >&2
        echo "  (softprops/action-gh-release) instead of actions/upload-artifact." >&2
        echo ""
        echo "  Trigger a new run and wait for it to finish:" >&2
        echo "    gh workflow run 'Test Build' --ref \$(git branch --show-current)" >&2
        exit 1
    fi

    # Print a summary line about the chosen run.
    gh run list \
        --workflow="${WORKFLOW}" \
        --json databaseId,status,headBranch,createdAt \
        --jq "[.[] | select(.databaseId==${RUN_ID})][0] \
              | \"Run #\(.databaseId) — branch=\(.headBranch) created=\(.createdAt)\""
fi

# ── Download ───────────────────────────────────────────────────────────────
echo ""
echo "Downloading artifacts → ${OUT_DIR}/"
rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"

gh run download "${RUN_ID}" --dir "${OUT_DIR}"

echo ""
echo "Done. Contents of ${OUT_DIR}/:"
find "${OUT_DIR}" -maxdepth 2 | sort
