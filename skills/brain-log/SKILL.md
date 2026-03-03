---
name: brain-log
description: Show brain sync and evolution history.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read
---

Show the user their brain's sync history.

## Steps

1. Read the merge log:
   ```bash
   cat ~/.claude/brain-repo/meta/merge-log.json 2>/dev/null
   ```

2. If the file doesn't exist or is empty, tell the user: "No sync history yet."

3. Otherwise, display the most recent entries in reverse chronological order. Default to 20 entries, but if $ARGUMENTS is a number, use that instead.

   Format each entry as:
   ```
   [timestamp] machine_name (action): summary
   ```

   Example:
   ```
   [2026-03-03T12:05:00Z] work-laptop (pull+merge): Merged 3 machine snapshots
   [2026-03-03T11:00:00Z] home-desktop (push): Exported brain snapshot
   [2026-03-02T09:30:00Z] work-laptop (evolve): Promoted 2 patterns to CLAUDE.md
   ```
