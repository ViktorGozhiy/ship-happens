#!/usr/bin/env bash
# Runs the self-tests of the structure check on fixture trees, then checks the
# repository. Exits 0 only when both pass.
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

failures=0

fail() {
  echo "FAIL: $1: $2"
  failures=$((failures + 1))
}

require_tools() {
  local missing=0
  command -v jq >/dev/null 2>&1 || { echo "FAIL: missing tool: jq"; missing=1; }
  command -v claude >/dev/null 2>&1 || { echo "FAIL: missing tool: claude"; missing=1; }
  if ! command -v python3 >/dev/null 2>&1; then
    echo "FAIL: missing tool: python3"
    missing=1
  elif ! python3 -c 'import yaml' >/dev/null 2>&1; then
    echo "FAIL: missing tool: PyYAML for python3"
    missing=1
  fi
  return "$missing"
}

# Prints the problems of one frontmatter block, one per line.
# Arguments: file, kind (skill or agent), expected name.
frontmatter_problems() {
  python3 - "$1" "$2" "$3" <<'PY'
import sys
import yaml

path, kind, expected = sys.argv[1:4]
lines = open(path, encoding="utf-8").read().split("\n")
if lines[0].rstrip() != "---":
    print("frontmatter does not start with ---")
    sys.exit()
end = next((i for i in range(1, len(lines)) if lines[i].rstrip() == "---"), None)
if end is None:
    print("frontmatter is not closed")
    sys.exit()
try:
    data = yaml.safe_load("\n".join(lines[1:end]))
except yaml.YAMLError:
    print("frontmatter is not valid YAML")
    sys.exit()
if not isinstance(data, dict):
    print("frontmatter is not a YAML mapping")
    sys.exit()

def filled(value):
    if isinstance(value, list):
        return any(isinstance(v, str) and v.strip() for v in value)
    return isinstance(value, str) and value.strip() != ""

for key in ("name", "description"):
    if not filled(data.get(key)):
        print(f"{key} is missing or empty")
if filled(data.get("name")) and data["name"] != expected:
    print(f"name must be {expected}")
if kind == "agent":
    if data.get("model") not in ("opus", "sonnet"):
        print("model must be opus or sonnet")
    if not filled(data.get("tools")):
        print("tools is missing or empty")
PY
}

# The files of the spec's "Repository layout".
LAYOUT_FILES='.claude-plugin/plugin.json
.claude-plugin/marketplace.json
skills/design/SKILL.md
skills/review/SKILL.md
skills/plan/SKILL.md
skills/plan/plan-format.md
skills/implement/SKILL.md
skills/quick-fix/SKILL.md
skills/debugging/SKILL.md
skills/pr-review/SKILL.md
skills/backlog/SKILL.md
skills/backlog/backlog-format.md
agents/advisor.md
agents/spec-reviewer.md
agents/plan-writer.md
agents/plan-reviewer.md
agents/implementer.md
agents/code-reviewer.md
tests/check-structure.sh
LICENSE
README.md'

# Text that the specs rely on, one "<file>|<string>" per line. A file written as
# "description:<file>" must hold the string in its frontmatter description, which
# is the text that loads the skill. The check runs on the repository only.
REQUIRED_TEXT='description:skills/backlog/SKILL.md|Fix small items
description:skills/pr-review/SKILL.md|post named findings
skills/quick-fix/SKILL.md|git merge --ff-only fix/<slug>
skills/quick-fix/SKILL.md|## Unattended mode
skills/pr-review/SKILL.md|git merge-tree --write-tree
skills/pr-review/SKILL.md|gh pr checks
skills/pr-review/SKILL.md|"commit_id"
skills/review/SKILL.md|timeout 1800 env -u SSH_AUTH_SOCK
skills/review/SKILL.md|--sandbox workspace-write
skills/review/SKILL.md|--sandbox read-only'

# Prints the frontmatter description of a file. Prints nothing when the file or
# the description is missing.
frontmatter_description() {
  python3 -I - "$1" <<'PY' 2>/dev/null
import sys
import yaml

lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
if lines[0].rstrip() != "---":
    sys.exit()
end = next((i for i in range(1, len(lines)) if lines[i].rstrip() == "---"), None)
if end is None:
    sys.exit()
data = yaml.safe_load("\n".join(lines[1:end]))
if isinstance(data, dict) and isinstance(data.get("description"), str):
    print(data["description"])
PY
}

check_required_text() {
  local root=$1 file string
  while IFS='|' read -r file string; do
    if [[ $file == description:* ]]; then
      file=${file#description:}
      grep -qF -- "$string" <<<"$(frontmatter_description "$root/$file")" ||
        fail "required text" "$file: description lacks: $string"
    else
      grep -qF -- "$string" "$root/$file" 2>/dev/null ||
        fail "required text" "$file: $string"
    fi
  done <<<"$REQUIRED_TEXT"
  [ "$failures" -eq 0 ]
}

check_layout() {
  local root=$1 path
  while IFS= read -r path; do
    [ -f "$root/$path" ] || fail "$path" "is part of the repository layout but does not exist"
  done <<<"$LAYOUT_FILES"
  [ "$failures" -eq 0 ]
}

check_manifests() {
  local root=$1 plugin marketplace field
  plugin=$root/.claude-plugin/plugin.json
  marketplace=$root/.claude-plugin/marketplace.json

  if ! jq empty "$plugin" >/dev/null 2>&1; then
    fail ".claude-plugin/plugin.json" "is not valid JSON"
  else
    [ "$(jq -r '.name' "$plugin")" = "sh" ] ||
      fail ".claude-plugin/plugin.json" "plugin name must be sh"
    [ "$(jq -r '.license' "$plugin")" = "MIT" ] ||
      fail ".claude-plugin/plugin.json" "license must be MIT"
    for field in homepage repository; do
      [ "$(jq -r --arg f "$field" '.[$f] | if type == "string" then . else "" end' "$plugin")" != "" ] ||
        fail ".claude-plugin/plugin.json" "$field must be set"
    done
  fi

  if ! jq empty "$marketplace" >/dev/null 2>&1; then
    fail ".claude-plugin/marketplace.json" "is not valid JSON"
  else
    [ "$(jq -r '.name' "$marketplace")" = "ship-happens" ] ||
      fail ".claude-plugin/marketplace.json" "marketplace name must be ship-happens"
    [ "$(jq -r '[.plugins[]? | select(.name == "sh" and .source == "./")] | length' "$marketplace")" -ge 1 ] ||
      fail ".claude-plugin/marketplace.json" "must list plugin sh with source ./"
  fi
}

check_manifests_with_claude() {
  local root=$1 manifest out
  for manifest in plugin marketplace; do
    if ! out=$(claude plugin validate --strict "$root/.claude-plugin/$manifest.json" 2>&1); then
      fail ".claude-plugin/$manifest.json" "claude plugin validate --strict failed: $(tr -s "[:space:]" " " <<<"$out")"
    fi
  done
}

check_frontmatter() {
  local root=$1 file kind expected output problem
  for file in "$root"/skills/*/SKILL.md "$root"/agents/*.md; do
    [ -f "$file" ] || continue
    if [[ $file == */SKILL.md ]]; then
      kind=skill
      expected=$(basename "$(dirname "$file")")
    else
      kind=agent
      expected=$(basename "$file" .md)
    fi
    if ! output=$(frontmatter_problems "$file" "$kind" "$expected" 2>&1); then
      fail "${file#"$root"/}" "frontmatter could not be checked: $(tail -n 1 <<<"$output")"
      continue
    fi
    [ -n "$output" ] || continue
    while IFS= read -r problem; do
      fail "${file#"$root"/}" "$problem"
    done <<<"$output"
  done
}

check_unique_names() {
  local root=$1 skill name
  for skill in "$root"/skills/*/SKILL.md; do
    [ -f "$skill" ] || continue
    name=$(basename "$(dirname "$skill")")
    [ -f "$root/agents/$name.md" ] &&
      fail "agents/$name.md" "$name is both a skill and an agent"
  done
}

check_content() {
  local root=$1 file rel name path key keys
  keys=$(jq -r '.userConfig // {} | keys[]' "$root/.claude-plugin/plugin.json" 2>/dev/null)
  while IFS= read -r file; do
    rel=${file#"$root"/}

    if grep -q 'superpowers:' "$file"; then
      fail "$rel" "must not contain superpowers:"
    fi

    if grep -qi 'Viktor' "$file"; then
      fail "$rel" "must not name Viktor"
    fi

    while IFS= read -r name; do
      if [ ! -f "$root/agents/$name.md" ] && [ ! -f "$root/skills/$name/SKILL.md" ]; then
        fail "$rel" "sh:$name does not resolve to an agent or a skill"
      fi
    done < <(grep -oE '(^|[^A-Za-z0-9_-])sh:[a-z][a-z0-9-]*' "$file" | sed -E 's/.*sh://' | sort -u)

    while IFS= read -r path; do
      if [ ! -f "$root/$path" ]; then
        fail "$rel" "\${CLAUDE_PLUGIN_ROOT}/$path does not exist"
      fi
    done < <(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9_./-]+' "$file" |
      sed -E 's#^\$\{CLAUDE_PLUGIN_ROOT\}/##; s#\.+$##' | sort -u)

    while IFS='|' read -r heading path; do
      grep -qxF -- "## $heading" "$root/$path" 2>/dev/null ||
        fail "$rel" "section \`## $heading\` does not exist in $path"
    done < <(grep -oE 'section `## [^`]+` of `\$\{CLAUDE_PLUGIN_ROOT\}/[^`]+`' "$file" |
      sed -E 's~^section `## ([^`]+)` of `\$\{CLAUDE_PLUGIN_ROOT\}/([^`]+)`$~\1|\2~' | sort -u)

    while IFS= read -r key; do
      grep -qxF -- "$key" <<<"$keys" ||
        fail "$rel" "\${user_config.$key} is not a key of userConfig in plugin.json"
    done < <(grep -oE '\$\{user_config\.[A-Za-z0-9_]+\}' "$file" | sed -E 's/^\$\{user_config\.//; s/\}$//' | sort -u)
  done < <(find "$root/skills" "$root/agents" -type f 2>/dev/null | sort)
}

# Prints one line per failed rule. Returns non-zero when any rule failed.
# The second argument is "real" for the repository and "fixture" for test trees.
check_tree() {
  local root=$1 kind=$2
  failures=0
  check_manifests "$root"
  if [ "$kind" = real ]; then
    check_manifests_with_claude "$root"
    check_layout "$root"
    check_required_text "$root"
  fi
  check_frontmatter "$root"
  check_unique_names "$root"
  check_content "$root"
  [ "$failures" -eq 0 ]
}

# ---- self-tests --------------------------------------------------------------

write_manifests() {
  local dir=$1
  mkdir -p "$dir/.claude-plugin"
  cat >"$dir/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "sh",
  "description": "Fixture plugin",
  "version": "0.1.0",
  "homepage": "https://example.com/fixture",
  "repository": "https://example.com/fixture",
  "license": "MIT",
  "userConfig": { "codex_review": { "title": "Codex review", "type": "boolean" } }
}
JSON
  cat >"$dir/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "ship-happens",
  "owner": { "name": "Fixture owner" },
  "plugins": [ { "name": "sh", "source": "./" } ]
}
JSON
}

new_fixture() {
  local dir
  dir=$(mktemp -d "$SCRATCH/fixture.XXXXXX")
  write_manifests "$dir"
  echo "$dir"
}

write_skill() {
  local dir=$1 name=$2
  mkdir -p "$dir/skills/$name"
  cat >"$dir/skills/$name/SKILL.md" <<SKILL
---
name: $name
description: Fixture skill.
---
Dispatch sh:helper and read \${CLAUDE_PLUGIN_ROOT}/skills/$name/notes.md.
SKILL
  echo "Notes." >"$dir/skills/$name/notes.md"
}

write_agent() {
  local dir=$1 name=$2
  mkdir -p "$dir/agents"
  cat >"$dir/agents/$name.md" <<AGENT
---
name: $name
description: Fixture agent.
model: sonnet
tools: Read, Grep
---
Do the work.
AGENT
}

# A fixture with one skill that names one agent.
new_valid_fixture() {
  local dir
  dir=$(new_fixture)
  write_skill "$dir" demo
  write_agent "$dir" helper
  echo "$dir"
}

# A fixture holding every file of the repository layout.
new_layout_fixture() {
  local dir path
  dir=$(new_fixture)
  while IFS= read -r path; do
    mkdir -p "$dir/$(dirname "$path")"
    touch "$dir/$path"
  done <<<"$LAYOUT_FILES"
  echo "$dir"
}

# A fixture whose files hold every string of REQUIRED_TEXT. A file with a
# description string starts with a frontmatter that holds it, so the entries of
# that kind are written first.
new_required_text_fixture() {
  local dir file string
  dir=$(new_fixture)
  while IFS='|' read -r file string; do
    [[ $file == description:* ]] || continue
    file=${file#description:}
    mkdir -p "$dir/$(dirname "$file")"
    printf -- '---\nname: fixture\ndescription: Use when asked (%s).\n---\n' "$string" >"$dir/$file"
  done <<<"$REQUIRED_TEXT"
  while IFS='|' read -r file string; do
    [[ $file == description:* ]] && continue
    mkdir -p "$dir/$(dirname "$file")"
    printf '%s\n' "$string" >>"$dir/$file"
  done <<<"$REQUIRED_TEXT"
  echo "$dir"
}

SELF_TEST_FAILURES=0

self_test_pass() {
  local label=$1 dir=$2 out rc
  out=$(check_tree "$dir" fixture)
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "pass: self-test: $label"
  else
    echo "FAIL: self-test: $label should pass but failed:"
    echo "$out"
    SELF_TEST_FAILURES=$((SELF_TEST_FAILURES + 1))
  fi
}

self_test_fail() {
  local label=$1 dir=$2 expected=$3 kind=${4:-fixture} out rc
  out=$(check_tree "$dir" "$kind")
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "FAIL: self-test: $label should fail but passed"
    SELF_TEST_FAILURES=$((SELF_TEST_FAILURES + 1))
  elif ! grep -qF -- "$expected" <<<"$out"; then
    echo "FAIL: self-test: $label failed without the message '$expected':"
    echo "$out"
    SELF_TEST_FAILURES=$((SELF_TEST_FAILURES + 1))
  else
    echo "pass: self-test: $label"
  fi
}

# Runs one check function on a fixture, which must pass.
self_test_function_pass() {
  local label=$1 dir=$2 check=$3 out
  failures=0
  if out=$("$check" "$dir"); then
    echo "pass: self-test: $label"
  else
    echo "FAIL: self-test: $label should pass but failed:"
    echo "$out"
    SELF_TEST_FAILURES=$((SELF_TEST_FAILURES + 1))
  fi
}

# Runs one check function on a fixture, which must fail with the expected message.
self_test_function_fail() {
  local label=$1 dir=$2 expected=$3 check=$4 out
  failures=0
  if out=$("$check" "$dir"); then
    echo "FAIL: self-test: $label should fail but passed"
    SELF_TEST_FAILURES=$((SELF_TEST_FAILURES + 1))
  elif ! grep -qF -- "$expected" <<<"$out"; then
    echo "FAIL: self-test: $label failed without the message '$expected':"
    echo "$out"
    SELF_TEST_FAILURES=$((SELF_TEST_FAILURES + 1))
  else
    echo "pass: self-test: $label"
  fi
}

run_self_tests() {
  local dir

  self_test_pass "manifests alone" "$(new_fixture)"
  self_test_pass "valid skill naming a valid agent" "$(new_valid_fixture)"

  dir=$(new_fixture)
  echo '{ "name": ' >"$dir/.claude-plugin/plugin.json"
  self_test_fail "invalid manifest JSON" "$dir" "is not valid JSON"

  dir=$(new_fixture)
  sed -i '/"license"/d' "$dir/.claude-plugin/plugin.json"
  self_test_fail "plugin.json without license" "$dir" "license must be MIT"

  dir=$(new_fixture)
  sed -i 's/"license": "MIT"/"license": "GPL-3.0"/' "$dir/.claude-plugin/plugin.json"
  self_test_fail "plugin.json with another license" "$dir" "license must be MIT"

  dir=$(new_fixture)
  sed -i '/"homepage"/d' "$dir/.claude-plugin/plugin.json"
  self_test_fail "plugin.json without homepage" "$dir" "homepage must be set"

  dir=$(new_fixture)
  sed -i '/"repository"/d' "$dir/.claude-plugin/plugin.json"
  self_test_fail "plugin.json without repository" "$dir" "repository must be set"

  dir=$(new_fixture)
  sed -i 's/"name": "sh"/"name": "other"/' "$dir/.claude-plugin/plugin.json"
  self_test_fail "wrong plugin name" "$dir" "plugin name must be sh"

  dir=$(new_fixture)
  sed -i 's/"name": "ship-happens"/"name": "other"/' "$dir/.claude-plugin/marketplace.json"
  self_test_fail "wrong marketplace name" "$dir" "marketplace name must be ship-happens"

  dir=$(new_fixture)
  sed -i 's#"source": "./"#"source": "./sh"#' "$dir/.claude-plugin/marketplace.json"
  self_test_fail "marketplace entry without source ./" "$dir" "must list plugin sh with source ./"

  dir=$(new_valid_fixture)
  printf -- '---\nname: demo\ndescription: Fixture skill.\nBody without a closing line.\n' >"$dir/skills/demo/SKILL.md"
  self_test_fail "unclosed frontmatter" "$dir" "frontmatter is not closed"

  dir=$(new_valid_fixture)
  printf -- '---\nname: demo\ndescription: a: b\n---\nBody.\n' >"$dir/skills/demo/SKILL.md"
  self_test_fail "invalid YAML" "$dir" "frontmatter is not valid YAML"

  dir=$(new_valid_fixture)
  printf -- '---\nname: other\ndescription: Fixture skill.\n---\n\xff\n' >"$dir/skills/demo/SKILL.md"
  self_test_fail "frontmatter helper crash on invalid UTF-8" "$dir" "frontmatter could not be checked"

  dir=$(new_valid_fixture)
  printf -- '---\nname:\ndescription: Fixture skill.\n---\nBody.\n' >"$dir/skills/demo/SKILL.md"
  self_test_fail "empty name" "$dir" "name is missing or empty"

  dir=$(new_valid_fixture)
  printf -- '---\nname: demo\ndescription: ""\n---\nBody.\n' >"$dir/skills/demo/SKILL.md"
  self_test_fail "empty description" "$dir" "description is missing or empty"

  dir=$(new_valid_fixture)
  sed -i 's/^name: demo/name: other/' "$dir/skills/demo/SKILL.md"
  self_test_fail "skill name differs from directory" "$dir" "name must be demo"

  dir=$(new_valid_fixture)
  sed -i 's/^name: helper/name: other/' "$dir/agents/helper.md"
  self_test_fail "agent name differs from file" "$dir" "name must be helper"

  dir=$(new_valid_fixture)
  sed -i '/^model:/d' "$dir/agents/helper.md"
  self_test_fail "agent without model" "$dir" "model must be opus or sonnet"

  dir=$(new_valid_fixture)
  sed -i '/^tools:/d' "$dir/agents/helper.md"
  self_test_fail "agent without tools" "$dir" "tools is missing or empty"

  dir=$(new_valid_fixture)
  rm "$dir/agents/helper.md"
  self_test_fail "sh: reference to a missing file" "$dir" "sh:helper does not resolve"

  dir=$(new_valid_fixture)
  rm "$dir/skills/demo/notes.md"
  self_test_fail "missing CLAUDE_PLUGIN_ROOT file" "$dir" "skills/demo/notes.md does not exist"

  dir=$(new_valid_fixture)
  echo "Use superpowers:brainstorming first." >>"$dir/skills/demo/SKILL.md"
  self_test_fail "superpowers: reference" "$dir" "must not contain superpowers:"

  dir=$(new_valid_fixture)
  echo "Use when Viktor asks for a review." >>"$dir/skills/demo/SKILL.md"
  self_test_fail "personal name in a skill" "$dir" "must not name Viktor"

  dir=$(new_valid_fixture)
  echo "Read /home/viktor/notes before starting." >>"$dir/skills/demo/SKILL.md"
  self_test_fail "lowercase personal name in a skill" "$dir" "must not name Viktor"

  dir=$(new_valid_fixture)
  mkdir -p "$dir/skills/helper"
  printf -- '---\nname: helper\ndescription: Fixture skill.\n---\nBody.\n' >"$dir/skills/helper/SKILL.md"
  self_test_fail "skill and agent sharing a name" "$dir" "both a skill and an agent"

  dir=$(new_valid_fixture)
  echo "Codex is enabled when \${user_config.codex_review} is true." >>"$dir/skills/demo/SKILL.md"
  self_test_pass "user_config key declared in plugin.json" "$dir"

  dir=$(new_valid_fixture)
  echo "Codex is enabled when \${user_config.other_key} is true." >>"$dir/skills/demo/SKILL.md"
  self_test_fail "user_config key missing from plugin.json" "$dir" "user_config.other_key} is not a key of userConfig"

  dir=$(new_valid_fixture)
  printf '%s\n' '## Mode' 'Body.' >"$dir/skills/demo/notes.md"
  echo "Run the section \`## Mode\` of \`\${CLAUDE_PLUGIN_ROOT}/skills/demo/notes.md\`." >>"$dir/skills/demo/SKILL.md"
  self_test_pass "section reference to an existing heading" "$dir"

  dir=$(new_valid_fixture)
  printf '%s\n' '## Mode' 'Body.' >"$dir/skills/demo/notes.md"
  echo "Run it in the section \`## Mode\` of \`\${CLAUDE_PLUGIN_ROOT}/skills/demo/notes.md\`." >>"$dir/skills/demo/SKILL.md"
  self_test_pass "section reference with a leading preposition" "$dir"

  dir=$(new_valid_fixture)
  printf '%s\n' '## Other' 'Body.' >"$dir/skills/demo/notes.md"
  echo "Run the section \`## Mode\` of \`\${CLAUDE_PLUGIN_ROOT}/skills/demo/notes.md\`." >>"$dir/skills/demo/SKILL.md"
  self_test_fail "section reference to a missing heading" "$dir" "section \`## Mode\` does not exist in skills/demo/notes.md"

  dir=$(new_valid_fixture)
  printf '%s\n' '## Modes' 'Body.' >"$dir/skills/demo/notes.md"
  echo "Run the section \`## Mode\` of \`\${CLAUDE_PLUGIN_ROOT}/skills/demo/notes.md\`." >>"$dir/skills/demo/SKILL.md"
  self_test_fail "section reference to a heading that only starts alike" "$dir" "section \`## Mode\` does not exist in skills/demo/notes.md"

  dir=$(new_required_text_fixture)
  self_test_function_pass "required text present" "$dir" check_required_text

  dir=$(new_required_text_fixture)
  sed -i 's/--sandbox read-only//' "$dir/skills/review/SKILL.md"
  self_test_function_fail "required text missing" "$dir" \
    "FAIL: required text: skills/review/SKILL.md: --sandbox read-only" check_required_text

  dir=$(new_required_text_fixture)
  sed -i 's/Fix small items//' "$dir/skills/backlog/SKILL.md"
  self_test_function_fail "description trigger missing" "$dir" \
    "FAIL: required text: skills/backlog/SKILL.md: description lacks: Fix small items" check_required_text

  dir=$(new_required_text_fixture)
  sed -i '/^description:/d' "$dir/skills/pr-review/SKILL.md"
  echo "post named findings" >>"$dir/skills/pr-review/SKILL.md"
  self_test_function_fail "description trigger only in the body" "$dir" \
    "FAIL: required text: skills/pr-review/SKILL.md: description lacks: post named findings" check_required_text

  dir=$(new_required_text_fixture)
  rm "$dir/skills/review/SKILL.md"
  self_test_function_fail "file of a required text missing" "$dir" \
    "FAIL: required text: skills/review/SKILL.md: --sandbox read-only" check_required_text

  dir=$(new_required_text_fixture)
  rm "$dir/skills/backlog/SKILL.md"
  self_test_function_fail "file of a description trigger missing" "$dir" \
    "FAIL: required text: skills/backlog/SKILL.md: description lacks: Fix small items" check_required_text

  dir=$(new_layout_fixture)
  self_test_fail "repository check applies the required text" "$dir" \
    "required text: skills/pr-review/SKILL.md: gh pr checks" real

  dir=$(new_layout_fixture)
  self_test_function_pass "complete layout" "$dir" check_layout

  dir=$(new_layout_fixture)
  rm "$dir/agents/advisor.md"
  self_test_function_fail "layout without agents/advisor.md" "$dir" "agents/advisor.md" check_layout

  dir=$(new_layout_fixture)
  rm "$dir/LICENSE"
  self_test_fail "layout without LICENSE" "$dir" "LICENSE: is part of the repository layout" real

  dir=$(new_layout_fixture)
  rm "$dir/README.md"
  self_test_fail "layout without README.md" "$dir" "README.md: is part of the repository layout" real

  dir=$(new_layout_fixture)
  rm "$dir/agents/advisor.md"
  self_test_fail "repository check applies the layout" "$dir" "agents/advisor.md: is part of the repository layout" real

  [ "$SELF_TEST_FAILURES" -eq 0 ]
}

# ---- main --------------------------------------------------------------------

require_tools || exit 1
run_self_tests || exit 1
check_tree "$ROOT" real || exit 1
echo "pass: repository structure"
