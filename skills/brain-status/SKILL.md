---
name: brain-status
description: Show brain inventory, sync status, and network info across all machines.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read
---

Show the user their brain status.

Run:
```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"
```

Display the output to the user as-is. The script shows:
- Machine identity and sync status
- Network info (all machines in the brain network)
- Full brain inventory (CLAUDE.md, rules, skills, agents, memory, settings)
- Any pending conflicts
