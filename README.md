# al23-patching-script

Patching setup for Amazon Linux 2023 instances using AWS Systems Manager Patch Manager, plus helper scripts to manually retry patching.

Patching runs through `AWS-RunPatchBaselineWithHooks`, which installs patches according to the patch baseline, reports patch compliance to Patch Manager, and handles reboots. A pre-install hook takes EBS snapshots of every attached volume before any patch is installed. If the snapshot hook fails, patches are not installed.

Use the retry scripts when one or more instances timed out or failed during the normal Maintenance Window, and you do not want to rerun the full batch.

## Files

- patching/prepatch-snapshot-document.json: SSM Command document (`PrePatch-Snapshot`) that snapshots the instance's EBS volumes. Used as the pre-install hook.
- patching/params.json: Parameters for `AWS-RunPatchBaselineWithHooks` (install, reboot if needed, run the snapshot hook). Used by both retry scripts.
- patching/patching.sh: Retries patching for one or more specific instance IDs.
- patching/patching_per_tag_group.sh: Retries patching for every instance in a Patch Group.
- patching/cleanup_prepatch_snapshots.sh: Deletes old pre-patch snapshots.

## One-time setup

### 1. Create the snapshot hook document

Run in each region where you patch:

```bash
aws ssm create-document \
  --profile "your-aws-profile" \
  --name "PrePatch-Snapshot" \
  --document-type "Command" \
  --document-format "JSON" \
  --content file://patching/prepatch-snapshot-document.json
```

After changing the JSON file, publish the new version and make it the default:

```bash
aws ssm update-document \
  --profile "your-aws-profile" \
  --name "PrePatch-Snapshot" \
  --document-version '$LATEST' \
  --content file://patching/prepatch-snapshot-document.json

aws ssm update-document-default-version \
  --profile "your-aws-profile" \
  --name "PrePatch-Snapshot" \
  --document-version <new-version-number>
```

### 2. Instance role permissions

The hook runs on the instance, so the instance profile role (not your local AWS profile) needs:

- `ec2:DescribeTags`
- `ec2:CreateSnapshots` (snapshots all attached volumes at the same point in time)
- `ec2:CreateTags` (to tag the snapshots on creation)

It also needs the usual `AmazonSSMManagedInstanceCore` policy.

### 3. Maintenance Window task

In the console: Systems Manager → Maintenance Windows → your window → Tasks → edit the patching task (or register a new Run Command task):

- Document: `AWS-RunPatchBaselineWithHooks`
- Parameters:
  - Operation: `Install`
  - RebootOption: `RebootIfNeeded`
  - PreInstallHookDocName: `PrePatch-Snapshot`
- Concurrency / error threshold: keep these low (for example 1 or 10%) so instances are not all rebooted at the same time.

### 4. Patch baseline

Patch Manager decides what to install from the patch baseline registered for the instance's `Patch Group` tag. If no baseline is registered for the group, the default AL2023 baseline (`AWS-AmazonLinux2023DefaultPatchBaseline`) is used. It only approves Security and Bugfix updates, 7 days after release. To install all updates immediately, create a custom baseline and register it for the patch group.

## Retry specific instances

Run from anywhere; the script finds params.json next to itself.

```bash
./patching/patching.sh your-aws-profile i-0123456789abcdef0 i-0fedcba9876543210
```

## Retry a whole Patch Group

Patches instances with the tag `Patch Group=<value>`. By default one instance at a time, stopping after 1 error.

```bash
./patching/patching_per_tag_group.sh your-aws-profile linux-aws
# optional: max-concurrency and max-errors
./patching/patching_per_tag_group.sh your-aws-profile linux-aws 10% 1
```

Both scripts print the command ID and the command to check its status. Results also show up in Systems Manager → Run Command → Command history, and patch compliance in Patch Manager.

## Clean up old snapshots

Pre-patch snapshots are not deleted automatically. The `Retention=30` tag is only a label, and Data Lifecycle Manager only deletes snapshots it created itself, so it does not remove these.

The cleanup script finds snapshots tagged `Purpose=Patching` older than the given number of days (default 30). It only lists them unless you add `--delete`:

```bash
# list what would be deleted
./patching/cleanup_prepatch_snapshots.sh your-aws-profile
# delete snapshots older than 30 days
./patching/cleanup_prepatch_snapshots.sh your-aws-profile 30 --delete
```

It works in the region of your AWS profile; set `AWS_REGION=<region>` in front of the command to clean up another region. Snapshots still used by an AMI cannot be deleted and are reported as warnings. Your AWS profile needs `ec2:DescribeSnapshots` and `ec2:DeleteSnapshot`.

## Notes

- Your AWS profile needs permission to run `ssm:SendCommand` and read command results.
- Each run (including retries) creates a new set of snapshots.
- Both retry scripts allow up to 24 hours (`--timeout-seconds 86400`) for an instance to start. With low concurrency, instances wait in a queue, and the 1-hour default would make the later ones fail with `DeliveryTimedOut`.
