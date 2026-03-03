---
name: brain-sync
description: Manually sync brain with remote. Exports local state, pushes to remote, pulls updates from other machines, merges, and applies.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit
---

The user wants to manually trigger a full brain sync cycle.

## Steps

1. Check that brain is initialized:
   ```bash
   if [ ! -f ~/.claude/brain-config.json ]; then
     echo "Brain not initialized. Run /brain-init first."
     exit 1
   fi
   ```

2. Push local changes:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/push.sh"
   ```

3. Pull and merge remote changes:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/pull.sh" --auto-merge
   ```

4. Show the sync result summary. Check:
   - What changed (new skills, merged memory, updated settings)
   - Any conflicts that need resolution
   - Updated sync timestamps

5. If there are conflicts, suggest: "Run /brain-conflicts to review and resolve."
