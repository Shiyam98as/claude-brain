---
name: brain-join
description: Join an existing brain sync network from another machine. Pulls the consolidated brain and merges with any local state.
user-invocable: true
disable-model-invocation: true
argument-hint: "<git-remote-url>"
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

The user wants to join an existing brain network from this machine.

The Git remote URL is provided as: $ARGUMENTS

## Steps

1. Check dependencies (git, jq or python3).

2. Show current local brain inventory:
   ```
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"
   ```

3. Clone the brain repo:
   ```bash
   git clone "$ARGUMENTS" ~/.claude/brain-repo
   ```
   If the directory exists, do `git -C ~/.claude/brain-repo pull origin main` instead.

4. Register this machine:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/register-machine.sh" "$ARGUMENTS"
   ```

5. Show what's in the consolidated brain vs what's local. Run export first:
   ```bash
   MACHINE_ID=$(cat ~/.claude/brain-config.json | jq -r '.machine_id')
   mkdir -p ~/.claude/brain-repo/machines/${MACHINE_ID}
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/export.sh" --output ~/.claude/brain-repo/machines/${MACHINE_ID}/brain-snapshot.json
   ```

6. Ask the user how to handle existing local data:
   - **Merge** (recommended): Merge local brain into consolidated
   - **Overwrite**: Replace local with consolidated brain
   - **Keep local**: Keep local as-is, only add new items from consolidated

7. Based on choice:
   - **Merge**: Run merge-structured.sh then merge-semantic.sh between local snapshot and consolidated
   - **Overwrite**: Run import.sh directly with consolidated brain
   - **Keep local**: Run import.sh but skip files that already exist locally

8. Push the updated state:
   ```bash
   cd ~/.claude/brain-repo
   git add -A
   git commit -m "Join: $(hostname) joined brain network"
   git push origin main
   ```

9. Confirm success:
   - Show how many machines are now in the network
   - Show what was imported/merged
   - Note: "Auto-sync is now enabled. Your brain syncs on every Claude Code session start/end."
