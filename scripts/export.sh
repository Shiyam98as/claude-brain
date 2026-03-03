#!/usr/bin/env bash
# export.sh — Serialize local brain state to a JSON snapshot
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

MEMORY_ONLY=false
OUTPUT=""
QUIET=false

while [ $# -gt 0 ]; do
  case "$1" in
    --memory-only) MEMORY_ONLY=true; shift ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --quiet) QUIET=true; BRAIN_QUIET=true; shift ;;
    *) shift ;;
  esac
done

# ── Helper: read file content and hash ─────────────────────────────────────────
file_entry() {
  local filepath="$1"
  if [ ! -f "$filepath" ]; then
    echo "null"
    return
  fi
  local content hash
  content=$(cat "$filepath")
  hash=$(file_hash "$filepath")

  if $_has_jq; then
    jq -n --arg content "$content" --arg hash "sha256:${hash}" \
      '{"content": $content, "hash": $hash}'
  elif $_has_python3; then
    python3 -c "
import json, sys
print(json.dumps({'content': '''$(cat "$filepath")''', 'hash': 'sha256:${hash}'}))
"
  fi
}

# ── Helper: scan directory for files ───────────────────────────────────────────
scan_dir_entries() {
  local dir="$1"
  local result="{}"

  if [ ! -d "$dir" ]; then
    echo "{}"
    return
  fi

  if $_has_jq; then
    result=$(find "$dir" -type f -name "*.md" 2>/dev/null | sort | while read -r f; do
      local relpath
      relpath=$(realpath --relative-to="$dir" "$f" 2>/dev/null || echo "$(basename "$f")")
      local content hash
      content=$(cat "$f")
      hash=$(file_hash "$f")
      jq -n --arg key "$relpath" --arg content "$content" --arg hash "sha256:${hash}" \
        '{($key): {"content": $content, "hash": $hash}}'
    done | jq -s 'add // {}')
  elif $_has_python3; then
    result=$(python3 -c "
import os, json, hashlib
d = '${dir}'
result = {}
for root, dirs, files in os.walk(d):
    for f in sorted(files):
        if f.endswith('.md'):
            path = os.path.join(root, f)
            relpath = os.path.relpath(path, d)
            with open(path) as fh:
                content = fh.read()
            h = hashlib.sha256(content.encode()).hexdigest()
            result[relpath] = {'content': content, 'hash': f'sha256:{h}'}
print(json.dumps(result))
")
  fi
  echo "$result"
}

# ── Build snapshot ─────────────────────────────────────────────────────────────
build_snapshot() {
  local machine_id machine_name os_type timestamp
  machine_id=$(get_machine_id)
  [ -z "$machine_id" ] && machine_id="unregistered"
  machine_name=$(get_machine_name)
  os_type=$(detect_os)
  timestamp=$(now_iso)

  # Declarative
  local claude_md="null"
  if [ -f "${CLAUDE_DIR}/CLAUDE.md" ]; then
    claude_md=$(file_entry "${CLAUDE_DIR}/CLAUDE.md")
  fi

  local rules="{}"
  if [ -d "${CLAUDE_DIR}/rules" ]; then
    rules=$(scan_dir_entries "${CLAUDE_DIR}/rules")
  fi

  # Procedural
  local skills="{}"
  if [ -d "${CLAUDE_DIR}/skills" ]; then
    skills=$(scan_dir_entries "${CLAUDE_DIR}/skills")
  fi

  local agents="{}"
  if [ -d "${CLAUDE_DIR}/agents" ]; then
    agents=$(scan_dir_entries "${CLAUDE_DIR}/agents")
  fi

  local output_styles="{}"
  if [ -d "${CLAUDE_DIR}/output-styles" ]; then
    output_styles=$(scan_dir_entries "${CLAUDE_DIR}/output-styles")
  fi

  # Experiential: auto memory
  local auto_memory="{}"
  if [ -d "${CLAUDE_DIR}/projects" ]; then
    if $_has_jq; then
      auto_memory=$(find "${CLAUDE_DIR}/projects" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | while read -r proj_dir; do
        local mem_dir="${proj_dir}/memory"
        if [ -d "$mem_dir" ] && [ "$(ls -A "$mem_dir" 2>/dev/null)" ]; then
          local encoded
          encoded=$(basename "$proj_dir")
          local name
          name=$(project_name_from_encoded "$encoded")
          local entries
          entries=$(scan_dir_entries "$mem_dir")
          jq -n --arg key "$name" --argjson val "$entries" '{($key): $val}'
        fi
      done | jq -s 'add // {}')
    elif $_has_python3; then
      auto_memory=$(python3 -c "
import os, json, hashlib
projects_dir = '${CLAUDE_DIR}/projects'
result = {}
if os.path.isdir(projects_dir):
    for encoded in sorted(os.listdir(projects_dir)):
        mem_dir = os.path.join(projects_dir, encoded, 'memory')
        if os.path.isdir(mem_dir) and os.listdir(mem_dir):
            name = encoded.lstrip('-').replace('-', '/')
            name = os.path.basename(name) if '/' in name else name
            entries = {}
            for f in sorted(os.listdir(mem_dir)):
                fp = os.path.join(mem_dir, f)
                if os.path.isfile(fp):
                    with open(fp) as fh:
                        content = fh.read()
                    h = hashlib.sha256(content.encode()).hexdigest()
                    entries[f] = {'content': content, 'hash': f'sha256:{h}'}
            if entries:
                result[name] = entries
print(json.dumps(result))
")
    fi
  fi

  # Experiential: agent memory
  local agent_memory="{}"
  if [ -d "${CLAUDE_DIR}/agent-memory" ]; then
    if $_has_jq; then
      agent_memory=$(find "${CLAUDE_DIR}/agent-memory" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | while read -r agent_dir; do
        local agent_name
        agent_name=$(basename "$agent_dir")
        local entries
        entries=$(scan_dir_entries "$agent_dir")
        if [ "$entries" != "{}" ]; then
          jq -n --arg key "$agent_name" --argjson val "$entries" '{($key): $val}'
        fi
      done | jq -s 'add // {}')
    else
      agent_memory="{}"
    fi
  fi

  # Environmental: settings (strip env vars)
  local settings="null"
  if [ -f "${CLAUDE_DIR}/settings.json" ]; then
    if $_has_jq; then
      settings=$(jq 'del(.env)' "${CLAUDE_DIR}/settings.json")
    elif $_has_python3; then
      settings=$(python3 -c "
import json
with open('${CLAUDE_DIR}/settings.json') as f:
    data = json.load(f)
data.pop('env', None)
print(json.dumps(data))
")
    fi
  fi

  local settings_hash="null"
  if [ "$settings" != "null" ]; then
    settings_hash=$(echo "$settings" | compute_hash)
  fi

  # Environmental: keybindings
  local keybindings="null"
  local keybindings_hash="null"
  if [ -f "${CLAUDE_DIR}/keybindings.json" ]; then
    keybindings=$(cat "${CLAUDE_DIR}/keybindings.json")
    keybindings_hash=$(file_hash "${CLAUDE_DIR}/keybindings.json")
  fi

  # Environmental: MCP servers (from settings.json mcpServers field)
  local mcp_servers="{}"
  if [ -f "${CLAUDE_DIR}/settings.json" ] && $_has_jq; then
    mcp_servers=$(jq '.mcpServers // {}' "${CLAUDE_DIR}/settings.json" 2>/dev/null || echo "{}")
    # Rewrite absolute home paths to ${HOME}
    mcp_servers=$(echo "$mcp_servers" | sed "s|${HOME}|\${HOME}|g")
  fi

  # Assemble full snapshot
  if $_has_jq; then
    jq -n \
      --arg schema_ver "1.0.0" \
      --arg ts "$timestamp" \
      --arg mid "$machine_id" \
      --arg mn "$machine_name" \
      --arg os "$os_type" \
      --argjson claude_md "${claude_md:-null}" \
      --argjson rules "$rules" \
      --argjson skills "$skills" \
      --argjson agents "$agents" \
      --argjson output_styles "$output_styles" \
      --argjson auto_memory "$auto_memory" \
      --argjson agent_memory "$agent_memory" \
      --argjson settings "${settings:-null}" \
      --arg settings_hash "${settings_hash}" \
      --argjson keybindings "${keybindings:-null}" \
      --arg keybindings_hash "${keybindings_hash}" \
      --argjson mcp_servers "$mcp_servers" \
      '{
        schema_version: $schema_ver,
        exported_at: $ts,
        machine: { id: $mid, name: $mn, os: $os },
        declarative: {
          claude_md: $claude_md,
          rules: $rules
        },
        procedural: {
          skills: $skills,
          agents: $agents,
          output_styles: $output_styles
        },
        experiential: {
          auto_memory: $auto_memory,
          agent_memory: $agent_memory
        },
        environmental: {
          settings: { content: $settings, hash: ("sha256:" + $settings_hash) },
          keybindings: { content: $keybindings, hash: ("sha256:" + $keybindings_hash) },
          mcp_servers: $mcp_servers
        }
      }'
  elif $_has_python3; then
    python3 -c "
import json
snapshot = {
    'schema_version': '1.0.0',
    'exported_at': '${timestamp}',
    'machine': {'id': '${machine_id}', 'name': '${machine_name}', 'os': '${os_type}'},
    'declarative': {
        'claude_md': json.loads('${claude_md:-null}'),
        'rules': json.loads('''${rules}''')
    },
    'procedural': {
        'skills': json.loads('''${skills}'''),
        'agents': json.loads('''${agents}'''),
        'output_styles': json.loads('''${output_styles}''')
    },
    'experiential': {
        'auto_memory': json.loads('''${auto_memory}'''),
        'agent_memory': json.loads('''${agent_memory}''')
    },
    'environmental': {
        'settings': {'content': json.loads('${settings:-null}'), 'hash': 'sha256:${settings_hash}'},
        'keybindings': {'content': json.loads('${keybindings:-null}'), 'hash': 'sha256:${keybindings_hash}'},
        'mcp_servers': json.loads('''${mcp_servers}''')
    }
}
print(json.dumps(snapshot, indent=2))
"
  fi
}

# ── Main ───────────────────────────────────────────────────────────────────────
snapshot=$(build_snapshot)

# Compute top-level hash for quick change detection
snapshot_hash=$(echo "$snapshot" | compute_hash)

if $_has_jq; then
  snapshot=$(echo "$snapshot" | jq --arg h "sha256:${snapshot_hash}" '. + {snapshot_hash: $h}')
fi

if [ -n "$OUTPUT" ]; then
  echo "$snapshot" > "$OUTPUT"
  log_info "Brain snapshot exported to ${OUTPUT}"
else
  echo "$snapshot"
fi
