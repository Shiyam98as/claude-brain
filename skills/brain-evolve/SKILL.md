---
name: brain-evolve
description: Analyze accumulated brain memory and propose promotions to CLAUDE.md, rules, or new skills. Makes your brain smarter over time.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

The user wants to evolve their brain by promoting stable patterns from memory.

## Steps

1. Run the evolution analysis:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/evolve.sh"
   ```

2. Read the analysis results from `~/.claude/brain-repo/meta/last-evolve.json`.

3. For each recommendation in `promotions`, present it to the user:

   **For claude_md promotions:**
   - Show the proposed addition
   - Show the reason
   - Ask: Accept / Skip / Edit first
   - If accepted, append to ~/.claude/CLAUDE.md

   **For rule promotions:**
   - Show the proposed rule content
   - Ask: Accept / Skip / Edit first
   - If accepted, write to ~/.claude/rules/<appropriate-name>.md

   **For skill suggestions:**
   - Show the proposed skill
   - Ask: Accept / Skip / Edit first
   - If accepted, create in ~/.claude/skills/<name>/SKILL.md

4. For each entry in `stale_entries`, ask:
   - Archive (remove from memory) / Keep
   - If archived, note in the memory file that it was archived

5. After all changes are applied:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/push.sh"
   ```

6. Show summary: "Brain evolved: X promotions accepted, Y stale entries archived."
