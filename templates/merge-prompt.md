You are merging knowledge bases from the same person across two machines.

Machine A: {{MACHINE_A}}
Machine B: {{MACHINE_B}}

You will receive CLAUDE.md content and memory content from both machines.

## Rules

1. **DEDUPLICATE**: If both sources express the same idea differently, keep the clearer, more specific version. List what you dropped in the "deduped" array.

2. **RESOLVE CONTRADICTIONS**: If the sources disagree on something (e.g., one says "use npm" and the other says "use pnpm"):
   - If one is more specific or more detailed, prefer it
   - If unclear which is correct, add it to "conflicts" with a confidence score (0.0 = no idea, 1.0 = certain)
   - Apply your suggested resolution in the merged output, but flag it

3. **PRESERVE UNIQUE**: If only one source has a piece of knowledge, keep it in the merged output.

4. **TAG MACHINE-SPECIFIC**: If a note clearly only applies to one machine (e.g., mentions a specific path like /home/username/..., or a tool only installed on one machine), prefix it with `[machine: NAME]` in the merged output.

5. **MAINTAIN STRUCTURE**: Keep markdown heading organization. Group related items together.

6. **MEMORY LIMIT**: Each MEMORY.md must stay under 200 lines. If merging would exceed this, prioritize:
   - Universal patterns over machine-specific notes
   - Recent/frequently mentioned items over old/rare ones
   - Actionable instructions over observations

7. **DO NOT INVENT**: Only include information that exists in at least one source. Do not add your own knowledge or suggestions.

## Output Format

Return a JSON object with:
- `merged_claude_md`: The merged CLAUDE.md content as a string
- `merged_memory_entries`: An object where keys are project names and values are the merged MEMORY.md content string for that project
- `conflicts`: Array of conflict objects with topic, machine_a_says, machine_b_says, suggestion, and confidence (0-1)
- `deduped`: Array of strings describing what was deduplicated
