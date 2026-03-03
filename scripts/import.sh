#!/usr/bin/env bash
# import.sh — Apply consolidated brain state to local machine
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

INPUT="${1:-${BRAIN_REPO}/consolidated/brain.json}"
QUIET="${BRAIN_QUIET:-false}"

if [ ! -f "$INPUT" ]; then
  log_error "Consolidated brain not found: ${INPUT}"
  exit 1
fi

# ── Helper: write file if content differs ──────────────────────────────────────
write_if_changed() {
  local target="$1" content="$2"
  if [ -z "$content" ] || [ "$content" = "null" ]; then
    return 0
  fi
  mkdir -p "$(dirname "$target")"
  if [ -f "$target" ]; then
    local existing_hash new_hash
    existing_hash=$(file_hash "$target")
    new_hash=$(echo "$content" | compute_hash)
    if [ "$existing_hash" = "$new_hash" ]; then
      return 0  # No change
    fi
  fi
  echo "$content" > "$target"
  log_info "Updated: $target"
}

# ── Helper: import directory entries ───────────────────────────────────────────
import_dir_entries() {
  local base_dir="$1" json_entries="$2"
  if [ "$json_entries" = "{}" ] || [ "$json_entries" = "null" ]; then
    return 0
  fi

  if $_has_jq; then
    echo "$json_entries" | jq -r 'keys[]' | while read -r key; do
      local content
      content=$(echo "$json_entries" | jq -r --arg k "$key" '.[$k].content // empty')
      if [ -n "$content" ]; then
        write_if_changed "${base_dir}/${key}" "$content"
      fi
    done
  elif $_has_python3; then
    python3 -c "
import json, os
entries = json.loads('''${json_entries}''')
base = '${base_dir}'
for key, val in entries.items():
    content = val.get('content', '')
    if content:
        path = os.path.join(base, key)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if os.path.exists(path):
            with open(path) as f:
                if f.read() == content:
                    continue
        with open(path, 'w') as f:
            f.write(content)
        print(f'Updated: {path}')
"
  fi
}

# ── Import brain ───────────────────────────────────────────────────────────────
import_brain() {
  local brain
  brain=$(cat "$INPUT")

  log_info "Importing consolidated brain..."

  # Declarative: CLAUDE.md
  if $_has_jq; then
    local claude_md_content
    claude_md_content=$(echo "$brain" | jq -r '.declarative.claude_md.content // empty')
    if [ -n "$claude_md_content" ]; then
      write_if_changed "${CLAUDE_DIR}/CLAUDE.md" "$claude_md_content"
    fi
  fi

  # Declarative: rules
  if $_has_jq; then
    local rules
    rules=$(echo "$brain" | jq '.declarative.rules // {}')
    import_dir_entries "${CLAUDE_DIR}/rules" "$rules"
  fi

  # Procedural: skills
  if $_has_jq; then
    local skills
    skills=$(echo "$brain" | jq '.procedural.skills // {}')
    import_dir_entries "${CLAUDE_DIR}/skills" "$skills"
  fi

  # Procedural: agents
  if $_has_jq; then
    local agents
    agents=$(echo "$brain" | jq '.procedural.agents // {}')
    import_dir_entries "${CLAUDE_DIR}/agents" "$agents"
  fi

  # Procedural: output styles
  if $_has_jq; then
    local output_styles
    output_styles=$(echo "$brain" | jq '.procedural.output_styles // {}')
    import_dir_entries "${CLAUDE_DIR}/output-styles" "$output_styles"
  fi

  # Experiential: auto memory
  if $_has_jq; then
    echo "$brain" | jq -r '.experiential.auto_memory // {} | keys[]' 2>/dev/null | while read -r project; do
      local entries
      entries=$(echo "$brain" | jq --arg p "$project" '.experiential.auto_memory[$p] // {}')
      # Find matching project dir
      local target_dir=""
      if [ -d "${CLAUDE_DIR}/projects" ]; then
        for proj_dir in "${CLAUDE_DIR}"/projects/*/; do
          local name
          name=$(project_name_from_encoded "$(basename "$proj_dir")")
          if [ "$name" = "$project" ]; then
            target_dir="${proj_dir}memory"
            break
          fi
        done
      fi
      if [ -n "$target_dir" ]; then
        import_dir_entries "$target_dir" "$entries"
      fi
    done
  fi

  # Experiential: agent memory
  if $_has_jq; then
    echo "$brain" | jq -r '.experiential.agent_memory // {} | keys[]' 2>/dev/null | while read -r agent; do
      local entries
      entries=$(echo "$brain" | jq --arg a "$agent" '.experiential.agent_memory[$a] // {}')
      import_dir_entries "${CLAUDE_DIR}/agent-memory/${agent}" "$entries"
    done
  fi

  # Environmental: settings (deep merge, preserve local env)
  if $_has_jq; then
    local new_settings
    new_settings=$(echo "$brain" | jq '.environmental.settings.content // null')
    if [ "$new_settings" != "null" ] && [ -f "${CLAUDE_DIR}/settings.json" ]; then
      local tmp
      tmp=$(mktemp)
      # Merge: keep local env, merge everything else from consolidated
      jq -s '.[0] as $local | .[1] as $remote |
        ($local.env // {}) as $local_env |
        ($remote // {}) * $local | .env = $local_env' \
        "${CLAUDE_DIR}/settings.json" <(echo "$new_settings") > "$tmp"
      mv "$tmp" "${CLAUDE_DIR}/settings.json"
      log_info "Updated: settings.json (merged, local env preserved)"
    elif [ "$new_settings" != "null" ] && [ ! -f "${CLAUDE_DIR}/settings.json" ]; then
      echo "$new_settings" > "${CLAUDE_DIR}/settings.json"
      log_info "Created: settings.json"
    fi
  fi

  # Environmental: keybindings (union)
  if $_has_jq; then
    local new_keybindings
    new_keybindings=$(echo "$brain" | jq '.environmental.keybindings.content // null')
    if [ "$new_keybindings" != "null" ]; then
      if [ -f "${CLAUDE_DIR}/keybindings.json" ]; then
        local tmp
        tmp=$(mktemp)
        # Deep merge keybindings
        jq -s '.[0] * .[1]' "${CLAUDE_DIR}/keybindings.json" <(echo "$new_keybindings") > "$tmp"
        mv "$tmp" "${CLAUDE_DIR}/keybindings.json"
        log_info "Updated: keybindings.json (merged)"
      else
        echo "$new_keybindings" > "${CLAUDE_DIR}/keybindings.json"
        log_info "Created: keybindings.json"
      fi
    fi
  fi

  log_info "Brain import complete."
}

import_brain
