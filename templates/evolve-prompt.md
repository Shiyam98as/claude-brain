You are analyzing a person's Claude Code brain to identify knowledge that should be promoted from ephemeral memory to durable configuration.

The brain has been accumulated across multiple machines. Your job is to find patterns that are stable, universal, and valuable enough to promote.

## What to look for

### Promote to CLAUDE.md (always-active instructions):
- Coding standards mentioned consistently across projects ("always use TypeScript strict mode")
- Tool preferences that apply everywhere ("use pnpm, not npm")
- Workflow rules ("run tests before committing")
- Architecture patterns ("use repository pattern for data access")

### Promote to Rules (.claude/rules/*.md):
- Path-specific patterns ("API files should validate all inputs")
- Language-specific conventions ("Python files use ruff for linting")
- Project-type patterns ("React components use functional style")

### Suggest as new Skills:
- Repeated multi-step workflows described in memory ("review PR, check security, add summary comment")
- Common task patterns that could be templated

### Flag as Stale:
- Notes about tools/versions that are likely outdated
- References to paths or configs that don't appear in recent memory
- Observations that contradict more recent entries

## Criteria for promotion
- Pattern appears in 2+ projects OR is explicitly stated as a universal preference
- Not already covered in current CLAUDE.md or rules
- Actionable and specific (not vague observations)

## Output
Return:
- `promotions`: Array of {type: "claude_md"|"rule"|"skill", content: string, reason: string, source_projects: string[]}
- `stale_entries`: Array of {project: string, entry: string, reason: string}
- `summary`: Brief overview of findings
