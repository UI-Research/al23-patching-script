#!/bin/bash
# Delete pre-patch snapshots (tag Purpose=Patching) older than a number of days.
# Without --delete it only lists what would be deleted.
# Usage: ./cleanup_prepatch_snapshots.sh <aws-profile> [days] [--delete]
set -euo pipefail

usage() {
  echo "Usage: $0 <aws-profile> [days] [--delete]" >&2
  exit 1
}

if [ "$#" -lt 1 ]; then
  usage
fi

PROFILE="$1"
DAYS="${2:-30}"
MODE="${3:-}"

if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
  echo "ERROR: days must be a whole number." >&2
  usage
fi
if [ -n "$MODE" ] && [ "$MODE" != "--delete" ]; then
  usage
fi

# GNU date (Linux) first, BSD date (macOS) as fallback.
CUTOFF=$(date -u -d "$DAYS days ago" +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -v-"${DAYS}"d +%Y-%m-%dT%H:%M:%S)

SNAPSHOTS=$(aws ec2 describe-snapshots \
  --profile "$PROFILE" \
  --owner-ids self \
  --filters "Name=tag:Purpose,Values=Patching" \
  --query "Snapshots[].[SnapshotId,StartTime]" \
  --output text)

echo "Pre-patch snapshots older than $DAYS days (before $CUTOFF UTC):"

COUNT=0
FAILED=0
while read -r SNAPSHOT_ID START_TIME; do
  [ -z "$SNAPSHOT_ID" ] && continue
  # Timestamps are ISO 8601, so comparing the first 19 characters as text compares the dates.
  if [[ "${START_TIME:0:19}" < "$CUTOFF" ]]; then
    if [ "$MODE" = "--delete" ]; then
      if aws ec2 delete-snapshot --profile "$PROFILE" --snapshot-id "$SNAPSHOT_ID" < /dev/null; then
        echo "  Deleted $SNAPSHOT_ID ($START_TIME)"
      else
        echo "  WARNING: Could not delete $SNAPSHOT_ID (it may be used by an AMI)." >&2
        FAILED=$((FAILED + 1))
        continue
      fi
    else
      echo "  Would delete $SNAPSHOT_ID ($START_TIME)"
    fi
    COUNT=$((COUNT + 1))
  fi
done <<< "$SNAPSHOTS"

if [ "$MODE" = "--delete" ]; then
  echo "Deleted $COUNT snapshot(s), $FAILED failed."
else
  echo "$COUNT snapshot(s) would be deleted. Run again with --delete to delete them."
fi

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
