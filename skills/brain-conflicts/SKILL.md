---
name: brain-conflicts
description: Review and resolve unresolved brain merge conflicts.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

The user wants to resolve pending brain merge conflicts.

## Steps

1. Read the conflicts file:
   ```bash
   cat ~/.claude/brain-conflicts.json 2>/dev/null || echo '{"conflicts":[]}'
   ```

2. Filter to unresolved conflicts (where `resolved` is not `true`).

3. If no unresolved conflicts, tell the user: "No pending conflicts. Brain is fully synced."

4. For each unresolved conflict, present:
   - The topic
   - What Machine A says
   - What Machine B says
   - The AI's suggestion and confidence level

   Ask the user to choose:
   - **Accept AI suggestion**: Apply the suggestion
   - **Keep Machine A's version**: Use A's content
   - **Keep Machine B's version**: Use B's content
   - **Keep both (machine-specific)**: Tag each with its machine name
   - **Custom**: Let the user type their own resolution

5. After each resolution:
   - Mark the conflict as `resolved: true` with the chosen resolution in brain-conflicts.json
   - Apply the resolution to the appropriate brain file (CLAUDE.md, memory, etc.)

6. After all conflicts are resolved:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/push.sh"
   ```

7. Show summary: "X conflicts resolved. Brain is now fully synced."
