# al23-patching-script

This repository contains helper scripts to manually trigger patching on AWS instances.

Use these scripts when one or more instances timed out or failed during the normal patching window, and you do not want to rerun the full batch from Windows Maintenance.

## What this is for

- Retry patching for specific instance IDs.
- Retry patching for a full tag-based target group.
- Run AWS SSM send-command from your local machine.

## Files

- patching/patching.sh: Triggers patching for one or more specific instance IDs.
- patching/patching_per_tag_group.sh: Triggers patching for a tag-based target group.
- patching/params.json: JSON string version of the shell commands executed by SSM. This file is passed in the --parameters option.

## Use patching.sh (specific instances)

Set these values before running:

- --profile: Your AWS CLI profile.
- --instance-ids: Instance ID(s) to patch.

You can include multiple instance IDs inside double quotes, separated by spaces.

Example:

aws ssm send-command \
	--profile "your-aws-profile" \
	--instance-ids "i-0123456789abcdef0 i-0fedcba9876543210" \
	--document-name "AWS-RunShellScript" \
	--parameters file://params.json \
	--comment "Retry patch for failed instances"

## Use patching_per_tag_group.sh (target group)

If you want to patch all instances in a target group (instead of listing instance IDs), use:

- --targets: Defines the tag key/value group to trigger.

Example:

aws ssm send-command \
	--profile "your-aws-profile" \
	--targets "Key=tag:Patch Group,Values=linux-aws" \
	--document-name "AWS-RunShellScript" \
	--parameters file://params.json \
	--comment "Retry patch for target group"

## Notes

- Make sure your AWS profile has permission to run SSM commands and read EC2 metadata/tags.
- Run from the patching directory, or update the params.json path accordingly.
