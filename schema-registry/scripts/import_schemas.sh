#!/usr/bin/env bash
# Imports all schemas from the output directory into Schema Registry
# preserving the original schema IDs (subject-level IMPORT mode migration).
#
# Usage:
#   SR_URL=https://<your-schema-registry-url> ./import_schemas.sh
#
# Prerequisites:
#   - curl
#   - jq
#
# The script expects the exported schemas to be laid out as produced by the
# companion export script:
#
#   schema-export/
#     <subject-name>/
#       v1.json
#       v2.json
#       ...
#
# Each JSON file must contain at least the following fields (as exported):
#   { "subject": "...", "version": <n>, "id": <n>, "schema": "...", "schemaType": "..." }
#
# WARNING: This script does not handle cross-schema references.
# If your schemas contain a non empty "references" array, import
# in dependency order manually as described in the import ordering section.

set -euo pipefail

SR_URL="${SR_URL:-https://<confluent-sr>}"
OUT_DIR="${OUT_DIR:-./schema-export}"

if [[ ! -d "$OUT_DIR" ]]; then
  echo "ERROR: Export directory not found: $OUT_DIR" >&2
  exit 1
fi

# Tracks the subject currently being imported. Used by the EXIT trap to ensure
# the subject is never left stuck in IMPORT mode if the script exits early.
current_subject=""

restore_mode() {
  if [[ -n "$current_subject" ]]; then
    echo "  restoring $current_subject to READWRITE mode..." >&2
    curl -f -s -X PUT "$SR_URL/mode/$current_subject" \
      -H "Content-Type: application/vnd.schemaregistry.v1+json" \
      -d '{"mode": "READWRITE"}' || echo "  WARNING: failed to restore READWRITE mode for $current_subject" >&2
  fi
}
trap restore_mode EXIT

for subject_dir in "$OUT_DIR"/*/; do
  current_subject=$(jq -r '.subject' "$subject_dir/v1.json")
  echo "==> $current_subject"

  curl -f -s -X PUT "$SR_URL/mode/$current_subject" \
    -H "Content-Type: application/vnd.schemaregistry.v1+json" \
    -d '{"mode": "IMPORT"}'

  for file in $(ls "$subject_dir"/v*.json | sort -V); do
    version=$(jq -r '.version' "$file")
    echo -n "  v$version..."
    curl -f -s -X POST "$SR_URL/subjects/$current_subject/versions" \
      -H "Content-Type: application/vnd.schemaregistry.v1+json" \
      -d @"$file" || { echo " FAILED"; exit 1; }
    echo " ok"
  done

  curl -f -s -X PUT "$SR_URL/mode/$current_subject" \
    -H "Content-Type: application/vnd.schemaregistry.v1+json" \
    -d '{"mode": "READWRITE"}'

  echo "  mode restored to READWRITE"
  current_subject=""   # clear so the trap is a no-op between subjects
done

echo "Done."
