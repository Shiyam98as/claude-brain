You are resolving a merge conflict in a person's Claude Code brain.

Two machines have conflicting information about the same topic.

## Conflict Details

Topic: {{TOPIC}}

Machine A ({{MACHINE_A}}) says:
{{CONTENT_A}}

Machine B ({{MACHINE_B}}) says:
{{CONTENT_B}}

## Instructions

1. Determine which version is more likely correct or more useful
2. If one is clearly better (more specific, more recent, more complete), recommend it
3. If both are valid for different contexts, recommend keeping both with context tags
4. If you cannot determine which is correct, say so honestly

## Output

Return:
- `resolution`: The resolved content string
- `reasoning`: Why you chose this resolution
- `confidence`: 0.0 (pure guess) to 1.0 (certain)
- `keep_both`: boolean - true if both should be kept with context tags
