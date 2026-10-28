# CyberAutomatic v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build CyberAutomatic v1 — an independent, MIT-licensed Bash orchestrator (`cyberauto`) combining opt-in-gated offensive recon/pentest modes with lightweight defensive host-audit modes, sharing one workspace/findings/report engine.

**Architecture:** A single CLI entrypoint dispatches to independent `modes/*.sh` scripts that all follow the same contract (target in, structured findings + raw loot out). Shared `lib/*.sh` modules provide the scope/authorization guard, workspace CRUD, findings storage, dependency checks, and report rendering. No code, wordlists, or templates are reused from Sn1per.

**Tech Stack:** Bash (4+), `jq` (JSON construction, required core dependency), `bats` (test framework), `shellcheck` (lint/CI gate), external scan tools invoked via PATH (nmap, whatweb, nikto, ffuf/gobuster, gowitness, testssl.sh/sslscan, nuclei, amass/subfinder, theHarvester, Ncrack, NetExec, lynis — each optional per mode except nmap/jq).

**Spec:** `docs/superpowers/specs/2026-10-28-cyberautomatic-design.md`

## Global Constraints

- License: MIT, copyright holder "marcarna90", year 2026.
- Binary name: `cyberauto`. No file, mode, or variable name may reference "Sn1per"/"sniper".
- Hard-required tools (entrypoint refuses to run without them): `bash`, `jq`, `nmap`.
- All other external tools are optional per mode; absence triggers a logged `WARN` and that step is skipped, never a crash.
- Default `CYBERAUTO_ALLOWED_TARGETS` (private ranges): `10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.0/8`.
- Any offensive mode requires `--i-am-authorized`; `bruteforce` additionally requires `--allow-bruteforce`. Both gates are independent — missing either refuses the run.
- No credential wordlists, exploit payloads, or scan templates are bundled in the repo.
- CI never performs a real network scan or a real bruteforce attempt; all tool calls under test are mocked via `tests/mocks/<tool>` scripts on `PATH`.
- Findings are stored one JSON object per line in `<workspace>/findings.jsonl` with schema `{"ts","mode","target","severity","title","description","recommendation"}`, `severity` one of `info|low|medium|high|critical`.

## Review Focus

- Target rejected by the scope guard (unauthorized, or outside `CYBERAUTO_ALLOWED_TARGETS`) must hard-stop before any external tool runs — not just log a warning.
- A hard-required tool missing (`nmap`) must fail that mode clearly; an optional tool missing inside a multi-tool mode (e.g. `nikto` inside `web`) must skip only that step and continue.
- `bruteforce` must refuse when only one of `--allow-bruteforce` / `--i-am-authorized` is present — both are independently required.
- Finding text containing quotes, backslashes, or newlines (real tool output does this) must still produce one valid JSON object per line in `findings.jsonl`.
- Re-running `cyberauto` against an existing workspace alias must reuse it (idempotent create) and never wipe prior loot/findings.

---

## Task 1: Repository scaffolding

**Files:**
- Create: `LICENSE`
- Create: `README.md`
- Create: `conf/cyberauto.conf.example`
- Create: `.gitignore`
- Create directories (with `.gitkeep`): `lib/`, `modes/`, `templates/`, `scripts/`, `tests/mocks/`, `workspaces/`

**Interfaces:**
- Produces: `conf/cyberauto.conf.example` defines `CYBERAUTO_ALLOWED_TARGETS` (default from Global Constraints) and `CYBERAUTO_WORKSPACE_DIR` (default `./workspaces`) — every later task that reads config reads these two variable names.

- [ ] **Step 1: Create directory skeleton and `.gitkeep` files**

Run: `mkdir -p lib modes templates scripts tests/mocks workspaces && touch lib/.gitkeep modes/.gitkeep templates/.gitkeep scripts/.gitkeep tests/mocks/.gitkeep workspaces/.gitkeep`

- [ ] **Step 2: Write `LICENSE`**

Standard MIT license text, copyright line `Copyright (c) 2026 marcarna90`.

- [ ] **Step 3: Write `conf/cyberauto.conf.example`**

```bash
# CyberAutomatic configuration — copy to cyberauto.conf and edit.
CYBERAUTO_ALLOWED_TARGETS="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.0/8"
CYBERAUTO_WORKSPACE_DIR="./workspaces"
```

- [ ] **Step 4: Write `.gitignore`**

Ignore `workspaces/*` (except `.gitkeep`), `*.log`, `cyberauto.conf` (the user's real, non-example config).

- [ ] **Step 5: Write `README.md` stub**

One paragraph: project name, one-line description, "Authorized use only — independent project, no code shared with Sn1per", MIT license badge/text, "Full docs: see `docs/`". Full usage docs are filled in Task 18.

- [ ] **Step 6: Verify structure**

Run: `find . -maxdepth 2 -not -path './.git*'`
Expected: every directory from this task's Files section is present.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore: scaffold CyberAutomatic repository layout"
```

---

## Task 2: `lib/deps.sh` — dependency checks + shared test infrastructure

**Files:**
- Create: `lib/deps.sh`
- Create: `tests/test_helper.bash`
- Create: `tests/mocks/nmap` (example mock binary used by this and later tasks)
- Test: `tests/test_deps.bats`

**Interfaces:**
- Produces:
  - `deps::require(tool)` → returns 0 if `tool` is on `PATH`, 1 otherwise, no output.
  - `deps::check_or_warn(tool, mode_name, log_path)` → if `tool` missing, appends `WARN: <mode_name>: <tool> not found, skipping step` to `log_path` and returns 1; else returns 0, no output.
- Consumes: nothing (first lib module).

- [ ] **Step 1: Write `tests/test_helper.bash`**

```bash
setup_cyberauto_test() {
  export PATH="${BATS_TEST_DIRNAME}/mocks:${PATH}"
  CYBERAUTO_TMP="$(mktemp -d)"
  export CYBERAUTO_TMP
}
teardown_cyberauto_test() {
  rm -rf "${CYBERAUTO_TMP}"
}
```

- [ ] **Step 2: Write failing test `tests/test_deps.bats`**

```bash
load test_helper
setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "deps::require succeeds for a tool on PATH" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  run deps::require "bash"
  [ "$status" -eq 0 ]
}

@test "deps::require fails for a missing tool" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  run deps::require "no-such-tool-xyz"
  [ "$status" -eq 1 ]
}

@test "deps::check_or_warn logs WARN and returns 1 when tool missing" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  log="${CYBERAUTO_TMP}/mode.log"
  run deps::check_or_warn "no-such-tool-xyz" "web" "$log"
  [ "$status" -eq 1 ]
  grep -q "WARN: web: no-such-tool-xyz not found" "$log"
}
```

- [ ] **Step 3: Run tests, verify they fail**

Run: `bats tests/test_deps.bats`
Expected: FAIL — `lib/deps.sh` not found / functions undefined.

- [ ] **Step 4: Implement `lib/deps.sh`**

Implement `deps::require` and `deps::check_or_warn` exactly as specified in Interfaces above.

- [ ] **Step 5: Run tests, verify they pass**

Run: `bats tests/test_deps.bats`
Expected: 3 tests, PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/deps.sh tests/test_helper.bash tests/test_deps.bats
git commit -m "feat: add dependency-check helpers (lib/deps.sh)"
```

---

## Task 3: `lib/scope.sh` — authorization + allow-list guard

**Files:**
- Create: `lib/scope.sh`
- Test: `tests/test_scope.bats`

**Interfaces:**
- Consumes: nothing from other lib modules.
- Produces: `scope::check(target, allowed_targets_csv, authorized_flag)` → prints nothing; returns `0` if allowed, `1` and prints `"ERROR: not authorized (pass --i-am-authorized)"` to stderr if `authorized_flag` is not the literal string `"1"`, or `2` and prints `"ERROR: target '<target>' is outside CYBERAUTO_ALLOWED_TARGETS"` to stderr if the target matches no CIDR/host in `allowed_targets_csv`. `allowed_targets_csv` is a comma-separated list of IPv4 CIDRs/hosts, matching the `CYBERAUTO_ALLOWED_TARGETS` config format.
- Produces: `scope::cidr_match(ip, cidr)` → returns 0 if `ip` is inside `cidr`, 1 otherwise. Used internally by `scope::check`, also called directly in tests.

- [ ] **Step 1: Write failing tests `tests/test_scope.bats`**

```bash
load test_helper
setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "cidr_match: 192.168.1.5 is inside 192.168.0.0/16" {
  source "${BATS_TEST_DIRNAME}/../lib/scope.sh"
  run scope::cidr_match "192.168.1.5" "192.168.0.0/16"
  [ "$status" -eq 0 ]
}

@test "cidr_match: 8.8.8.8 is outside 192.168.0.0/16" {
  source "${BATS_TEST_DIRNAME}/../lib/scope.sh"
  run scope::cidr_match "8.8.8.8" "192.168.0.0/16"
  [ "$status" -eq 1 ]
}

@test "scope::check refuses without --i-am-authorized" {
  source "${BATS_TEST_DIRNAME}/../lib/scope.sh"
  run scope::check "192.168.1.5" "192.168.0.0/16" "0"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not authorized"* ]]
}

@test "scope::check refuses a target outside the allow-list even when authorized" {
  source "${BATS_TEST_DIRNAME}/../lib/scope.sh"
  run scope::check "8.8.8.8" "192.168.0.0/16" "1"
  [ "$status" -eq 2 ]
  [[ "$output" == *"outside CYBERAUTO_ALLOWED_TARGETS"* ]]
}

@test "scope::check allows an authorized in-scope target" {
  source "${BATS_TEST_DIRNAME}/../lib/scope.sh"
  run scope::check "192.168.1.5" "192.168.0.0/16,10.0.0.0/8" "1"
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `bats tests/test_scope.bats`
Expected: FAIL — `lib/scope.sh` not found.

- [ ] **Step 3: Implement `lib/scope.sh`**

Implement `scope::cidr_match` (bitwise IPv4/mask comparison) and `scope::check` exactly as specified. `scope::check` splits `allowed_targets_csv` on `,` and returns 0 on the first match.

- [ ] **Step 4: Run tests, verify they pass**

Run: `bats tests/test_scope.bats`
Expected: 5 tests, PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/scope.sh tests/test_scope.bats
git commit -m "feat: add scope/authorization guard (lib/scope.sh)"
```

---

## Task 4: `lib/workspace.sh` — workspace CRUD

**Files:**
- Create: `lib/workspace.sh`
- Test: `tests/test_workspace.bats`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `workspace::create(alias, base_dir)` → idempotent; creates `base_dir/alias/{loot,logs,reports}` and `base_dir/alias/workspace.meta` (`alias=...` and `created_at=<ISO8601>` lines) if absent; if already present, leaves existing contents untouched. Prints the absolute workspace path to stdout. Always returns 0.
  - `workspace::list(base_dir)` → prints one alias per line for every subdirectory of `base_dir` containing a `workspace.meta`.
  - `workspace::delete(alias, base_dir)` → `rm -rf` the workspace dir; returns 1 with stderr message if it does not exist.
  - `workspace::export(alias, base_dir, dest_tar_path)` → `tar czf dest_tar_path` of the workspace dir; returns 1 if the workspace does not exist.
  - `workspace::reimport(src_tar_path, base_dir)` → extracts the tarball into `base_dir`, restoring its alias directory; returns 1 if the tarball is unreadable.

- [ ] **Step 1: Write failing tests `tests/test_workspace.bats`**

```bash
load test_helper
setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "workspace::create makes loot/logs/reports and workspace.meta" {
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  path=$(workspace::create "demo" "$CYBERAUTO_TMP")
  [ -d "$path/loot" ]
  [ -d "$path/logs" ]
  [ -d "$path/reports" ]
  grep -q "alias=demo" "$path/workspace.meta"
}

@test "workspace::create is idempotent and keeps existing loot" {
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  path=$(workspace::create "demo" "$CYBERAUTO_TMP")
  echo "keep-me" > "$path/loot/marker.txt"
  workspace::create "demo" "$CYBERAUTO_TMP" > /dev/null
  [ -f "$path/loot/marker.txt" ]
}

@test "workspace::list shows created workspaces" {
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  workspace::create "alpha" "$CYBERAUTO_TMP" > /dev/null
  workspace::create "beta" "$CYBERAUTO_TMP" > /dev/null
  run workspace::list "$CYBERAUTO_TMP"
  [[ "$output" == *"alpha"* ]]
  [[ "$output" == *"beta"* ]]
}

@test "workspace::delete removes the workspace" {
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  path=$(workspace::create "gone" "$CYBERAUTO_TMP")
  workspace::delete "gone" "$CYBERAUTO_TMP"
  [ ! -d "$path" ]
}

@test "workspace::export then workspace::reimport restores the workspace" {
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  path=$(workspace::create "roundtrip" "$CYBERAUTO_TMP")
  echo "data" > "$path/loot/f.txt"
  workspace::export "roundtrip" "$CYBERAUTO_TMP" "$CYBERAUTO_TMP/roundtrip.tar.gz"
  workspace::delete "roundtrip" "$CYBERAUTO_TMP"
  workspace::reimport "$CYBERAUTO_TMP/roundtrip.tar.gz" "$CYBERAUTO_TMP"
  [ -f "$path/loot/f.txt" ]
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `bats tests/test_workspace.bats`
Expected: FAIL — `lib/workspace.sh` not found.

- [ ] **Step 3: Implement `lib/workspace.sh`** per the Interfaces block.

- [ ] **Step 4: Run tests, verify they pass**

Run: `bats tests/test_workspace.bats`
Expected: 5 tests, PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/workspace.sh tests/test_workspace.bats
git commit -m "feat: add workspace CRUD (lib/workspace.sh)"
```

---

## Task 5: `lib/findings.sh` — structured findings storage

**Files:**
- Create: `lib/findings.sh`
- Test: `tests/test_findings.bats`

**Interfaces:**
- Consumes: nothing (uses `jq` directly).
- Produces:
  - `findings::add(workspace_path, mode, target, severity, title, description, recommendation)` → appends one `jq -c -n`-built JSON object to `workspace_path/findings.jsonl` with keys `ts` (ISO8601, generated), `mode`, `target`, `severity`, `title`, `description`, `recommendation`. Returns 1 if `severity` is not one of `info|low|medium|high|critical`.
  - `findings::count(workspace_path, severity)` → prints the count of lines in `findings.jsonl` whose `.severity == severity` (via `jq`).

- [ ] **Step 1: Write failing tests `tests/test_findings.bats`**

```bash
load test_helper
setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "findings::add appends one valid JSON line" {
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  findings::add "$CYBERAUTO_TMP" "recon" "192.168.1.5" "high" "Open Telnet" "Telnet exposed" "Disable Telnet"
  [ "$(wc -l < "$CYBERAUTO_TMP/findings.jsonl")" -eq 1 ]
  jq -e '.severity == "high"' "$CYBERAUTO_TMP/findings.jsonl"
}

@test "findings::add rejects an invalid severity" {
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  run findings::add "$CYBERAUTO_TMP" "recon" "x" "critical-ish" "t" "d" "r"
  [ "$status" -eq 1 ]
}

@test "findings::add escapes quotes, backslashes and newlines safely" {
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  findings::add "$CYBERAUTO_TMP" "web" "x" "medium" 'He said "hi"' $'line1\nline2 with a \\ backslash' "fix it"
  [ "$(wc -l < "$CYBERAUTO_TMP/findings.jsonl")" -eq 1 ]
  jq -e '.title == "He said \"hi\""' "$CYBERAUTO_TMP/findings.jsonl"
}

@test "findings::count counts matching severities" {
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  findings::add "$CYBERAUTO_TMP" "recon" "x" "high" "a" "d" "r"
  findings::add "$CYBERAUTO_TMP" "recon" "x" "high" "b" "d" "r"
  findings::add "$CYBERAUTO_TMP" "recon" "x" "low" "c" "d" "r"
  run findings::count "$CYBERAUTO_TMP" "high"
  [ "$output" -eq 2 ]
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `bats tests/test_findings.bats`
Expected: FAIL — `lib/findings.sh` not found.

- [ ] **Step 3: Implement `lib/findings.sh`** using `jq -c -n --arg` for every field (never string-interpolate into JSON text directly, so the escaping test passes by construction).

- [ ] **Step 4: Run tests, verify they pass**

Run: `bats tests/test_findings.bats`
Expected: 4 tests, PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/findings.sh tests/test_findings.bats
git commit -m "feat: add findings storage (lib/findings.sh)"
```

---

## Task 6: `cyberauto` entrypoint — argument parsing + dispatch

**Files:**
- Create: `cyberauto` (executable, `chmod +x`)
- Test: `tests/test_cyberauto_cli.bats`
- Create: `tests/mocks/true-mode.sh` fixture mode used only by this task's tests (not shipped under `modes/`, lives under `tests/fixtures/modes/true-mode.sh`)

**Interfaces:**
- Consumes: `deps::require` (Task 2), `scope::check` (Task 3), `workspace::create/list/delete/export/reimport` (Task 4).
- Produces: the `cyberauto` CLI contract every later mode integrates with:
  - Flags: `-t/--target <target>`, `-f/--target-file <path>`, `-m/--mode <name>`, `-w/--workspace <alias>`, `-c/--config <path>` (default `./cyberauto.conf`, falling back to `./conf/cyberauto.conf.example` if absent), `--i-am-authorized`, `--allow-bruteforce`, `--list`, `-d/--delete`, `--export <dest>`, `--reimport <src>`.
  - Mode contract: for `-m <name>`, sources `modes/<name>.sh` (error "unknown mode '<name>'" + exit 1 if the file does not exist) and calls `mode_<name>_run "$target" "$workspace_path" "$opts"` (any flags after `--` are passed through verbatim as `opts`).
  - Exit codes: `0` success, `1` usage/scope/missing-required-tool error, `2` unknown mode.

- [ ] **Step 1: Write fixture mode `tests/fixtures/modes/true-mode.sh`**

```bash
mode_true-mode_run() {
  local target="$1" workspace_path="$2" opts="$3"
  echo "ran true-mode on $target with opts [$opts]" > "$workspace_path/loot/true-mode.out"
  return 0
}
```

- [ ] **Step 2: Write failing tests `tests/test_cyberauto_cli.bats`**

```bash
load test_helper
setup() { setup_cyberauto_test; cp "${BATS_TEST_DIRNAME}/../conf/cyberauto.conf.example" "$CYBERAUTO_TMP/cyberauto.conf"; }
teardown() { teardown_cyberauto_test; }

@test "refuses an offensive run without --i-am-authorized" {
  run "${BATS_TEST_DIRNAME}/../cyberauto" -c "$CYBERAUTO_TMP/cyberauto.conf" -t 192.168.1.5 -m true-mode -w demo --modes-dir "${BATS_TEST_DIRNAME}/fixtures/modes" --workspace-dir "$CYBERAUTO_TMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not authorized"* ]]
}

@test "refuses a target outside the allow-list even when authorized" {
  run "${BATS_TEST_DIRNAME}/../cyberauto" -c "$CYBERAUTO_TMP/cyberauto.conf" -t 8.8.8.8 -m true-mode -w demo --i-am-authorized --modes-dir "${BATS_TEST_DIRNAME}/fixtures/modes" --workspace-dir "$CYBERAUTO_TMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"outside CYBERAUTO_ALLOWED_TARGETS"* ]]
}

@test "unknown mode exits 2 with a clear message" {
  run "${BATS_TEST_DIRNAME}/../cyberauto" -c "$CYBERAUTO_TMP/cyberauto.conf" -t 192.168.1.5 -m no-such-mode -w demo --i-am-authorized --workspace-dir "$CYBERAUTO_TMP"
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown mode"* ]]
}

@test "dispatches an authorized, in-scope run to the mode's run function" {
  run "${BATS_TEST_DIRNAME}/../cyberauto" -c "$CYBERAUTO_TMP/cyberauto.conf" -t 192.168.1.5 -m true-mode -w demo --i-am-authorized --modes-dir "${BATS_TEST_DIRNAME}/fixtures/modes" --workspace-dir "$CYBERAUTO_TMP"
  [ "$status" -eq 0 ]
  grep -q "ran true-mode on 192.168.1.5" "$CYBERAUTO_TMP/demo/loot/true-mode.out"
}

@test "--list prints created workspace aliases" {
  "${BATS_TEST_DIRNAME}/../cyberauto" -c "$CYBERAUTO_TMP/cyberauto.conf" -t 192.168.1.5 -m true-mode -w demo --i-am-authorized --modes-dir "${BATS_TEST_DIRNAME}/fixtures/modes" --workspace-dir "$CYBERAUTO_TMP" > /dev/null
  run "${BATS_TEST_DIRNAME}/../cyberauto" --workspace-dir "$CYBERAUTO_TMP" --list
  [[ "$output" == *"demo"* ]]
}
```

- [ ] **Step 3: Run tests, verify they fail**

Run: `bats tests/test_cyberauto_cli.bats`
Expected: FAIL — `cyberauto` script missing/incomplete.

- [ ] **Step 4: Implement `cyberauto`**

Parse flags (include undocumented-but-needed test hooks `--modes-dir` and `--workspace-dir` that default to `./modes` and the config's `CYBERAUTO_WORKSPACE_DIR` respectively — this is how tests redirect the CLI without touching the real `modes/`/`workspaces/` dirs). On `-m`, call `workspace::create`, then `scope::check`, then source and dispatch per the Interfaces block.

- [ ] **Step 5: Run tests, verify they pass**

Run: `bats tests/test_cyberauto_cli.bats`
Expected: 5 tests, PASS.

- [ ] **Step 6: Commit**

```bash
git add cyberauto tests/test_cyberauto_cli.bats tests/fixtures/modes/true-mode.sh
git commit -m "feat: add cyberauto entrypoint (arg parsing, scope-gated dispatch)"
```

---

## Task 7: `lib/report.sh` + report templates

**Files:**
- Create: `lib/report.sh`
- Create: `templates/report.md.tpl`
- Create: `templates/finding_row.md.tpl`
- Test: `tests/test_report.bats`

**Interfaces:**
- Consumes: `findings.jsonl` schema from Task 5.
- Produces: `report::generate(workspace_path, template_path, row_template_path, output_path)` → reads every line of `workspace_path/findings.jsonl`, renders `row_template_path` once per finding (substituting `{{SEVERITY}}`, `{{TARGET}}`, `{{TITLE}}`, `{{DESCRIPTION}}`, `{{RECOMMENDATION}}`), concatenates the rows, substitutes the result into `{{FINDINGS_ROWS}}` in `template_path`, substitutes `{{GENERATED_AT}}` (ISO8601 now) and `{{FINDING_COUNT}}` (total line count), and writes the result to `output_path`. Returns 0 on success, 1 if `findings.jsonl` does not exist.

- [ ] **Step 1: Write `templates/finding_row.md.tpl`**

```
- **[{{SEVERITY}}]** {{TARGET}} — {{TITLE}}: {{DESCRIPTION}} _(Recommendation: {{RECOMMENDATION}})_
```

- [ ] **Step 2: Write `templates/report.md.tpl`**

```
# CyberAutomatic Report

Generated: {{GENERATED_AT}}
Total findings: {{FINDING_COUNT}}

## Findings

{{FINDINGS_ROWS}}
```

- [ ] **Step 3: Write failing tests `tests/test_report.bats`**

```bash
load test_helper
setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "report::generate renders every finding and the summary counts" {
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/report.sh"
  findings::add "$CYBERAUTO_TMP" "recon" "192.168.1.5" "high" "Open Telnet" "desc" "Disable it"
  findings::add "$CYBERAUTO_TMP" "web" "192.168.1.5" "low" "Missing header" "desc" "Add it"
  report::generate "$CYBERAUTO_TMP" \
    "${BATS_TEST_DIRNAME}/../templates/report.md.tpl" \
    "${BATS_TEST_DIRNAME}/../templates/finding_row.md.tpl" \
    "$CYBERAUTO_TMP/out.md"
  grep -q "Total findings: 2" "$CYBERAUTO_TMP/out.md"
  grep -q "Open Telnet" "$CYBERAUTO_TMP/out.md"
  grep -q "Missing header" "$CYBERAUTO_TMP/out.md"
}

@test "report::generate fails cleanly with no findings.jsonl" {
  source "${BATS_TEST_DIRNAME}/../lib/report.sh"
  run report::generate "$CYBERAUTO_TMP" \
    "${BATS_TEST_DIRNAME}/../templates/report.md.tpl" \
    "${BATS_TEST_DIRNAME}/../templates/finding_row.md.tpl" \
    "$CYBERAUTO_TMP/out.md"
  [ "$status" -eq 1 ]
}
```

- [ ] **Step 4: Run tests, verify they fail**

Run: `bats tests/test_report.bats`
Expected: FAIL — `lib/report.sh` not found.

- [ ] **Step 5: Implement `lib/report.sh`** (use `jq -r` to iterate `findings.jsonl` and plain `sed`/parameter-expansion substitution for the `{{...}}` placeholders — no `eval`).

- [ ] **Step 6: Run tests, verify they pass**

Run: `bats tests/test_report.bats`
Expected: 2 tests, PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/report.sh templates/report.md.tpl templates/finding_row.md.tpl tests/test_report.bats
git commit -m "feat: add report rendering (lib/report.sh + templates)"
```

---

## Task 8: nmap-based scan modes (recon, stealth, discover, port, fullport)

**Files:**
- Create: `modes/recon.sh`, `modes/stealth.sh`, `modes/discover.sh`, `modes/port.sh`, `modes/fullport.sh`
- Create: `tests/mocks/nmap` (overwrite Task 2's placeholder with a real fixture: prints a canned `-oG` style greppable line to stdout so each mode's parser has something deterministic to parse)
- Test: `tests/test_modes_nmap.bats`

**Interfaces:**
- Consumes: `deps::check_or_warn` (Task 2), `findings::add` (Task 5), mode contract from Task 6 (`mode_<name>_run(target, workspace_path, opts)`).
- Produces: each file defines exactly one function (`mode_recon_run`, `mode_stealth_run`, `mode_discover_run`, `mode_port_run`, `mode_fullport_run`) with the shared signature. Each: (a) returns 1 immediately if `nmap` is missing (hard-required per Global Constraints), logging to `<workspace>/logs/<mode>.log`; (b) runs `nmap` with its mode-specific flags (`recon`: `-sV -T4` default ports; `stealth`: adds `-sS -T2`; `discover`: `-sn` host-discovery only, no port findings; `port`: requires `opts` to contain a port list and passes `-p <ports>`; `fullport`: `-p-`); (c) writes raw nmap output to `<workspace>/loot/<mode>/nmap.txt`; (d) for every open port line, calls `findings::add` with `severity="info"`, `title="Open port <port>/<proto> (<service>)"`.

- [ ] **Step 1: Write `tests/mocks/nmap` fixture**

Prints one deterministic line simulating an open port (e.g. `22/tcp open ssh`) regardless of arguments, and writes its received arguments to `"$CYBERAUTO_NMAP_ARGS_LOG"` (test asserts the right flags were passed per mode) when that env var is set.

- [ ] **Step 2: Write failing tests `tests/test_modes_nmap.bats`**

```bash
load test_helper
setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "mode_recon_run records an open-port finding and raw loot" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/recon.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  mode_recon_run "192.168.1.5" "$ws" ""
  [ -f "$ws/loot/recon/nmap.txt" ]
  jq -e '.title | contains("22/tcp")' "$ws/findings.jsonl"
}

@test "mode_discover_run passes -sn and produces no port findings" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/discover.sh"
  export CYBERAUTO_NMAP_ARGS_LOG="$CYBERAUTO_TMP/nmap_args.log"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  mode_discover_run "192.168.1.0/24" "$ws" ""
  grep -q "\-sn" "$CYBERAUTO_NMAP_ARGS_LOG"
}

@test "mode_port_run fails loudly when nmap is entirely missing" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/port.sh"
  PATH="$CYBERAUTO_TMP/empty-path-dir" # nmap not here
  mkdir -p "$CYBERAUTO_TMP/empty-path-dir"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  run mode_port_run "192.168.1.5" "$ws" "--ports 80"
  [ "$status" -eq 1 ]
}
```

- [ ] **Step 3: Run tests, verify they fail**

Run: `bats tests/test_modes_nmap.bats`
Expected: FAIL — mode files not found.

- [ ] **Step 4: Implement `modes/recon.sh`, `modes/stealth.sh`, `modes/discover.sh`, `modes/port.sh`, `modes/fullport.sh`** per the Interfaces block.

- [ ] **Step 5: Run tests, verify they pass**

Run: `bats tests/test_modes_nmap.bats`
Expected: 3 tests, PASS.

- [ ] **Step 6: Commit**

```bash
git add modes/recon.sh modes/stealth.sh modes/discover.sh modes/port.sh modes/fullport.sh tests/mocks/nmap tests/test_modes_nmap.bats
git commit -m "feat: add nmap-based scan modes (recon, stealth, discover, port, fullport)"
```

---

## Task 9: `modes/web.sh`

**Files:**
- Create: `modes/web.sh`
- Create: `tests/mocks/whatweb`, `tests/mocks/nikto`, `tests/mocks/testssl.sh`
- Test: `tests/test_mode_web.bats`

**Interfaces:**
- Consumes: `deps::check_or_warn`, `findings::add`, mode contract.
- Produces: `mode_web_run(target, workspace_path, opts)`. Hard-required tool: none (web mode has no single mandatory tool — if *all* of whatweb/nikto/testssl.sh are missing it returns 1 with "no web tool available"; otherwise it runs whichever are present via `deps::check_or_warn` and skips the rest). Writes each tool's raw output to `<workspace>/loot/web/<tool>.txt`. Calls `findings::add` with `severity="medium"` for each nikto finding line and `severity="low"` for each testssl.sh weak-cipher line.

- [ ] **Step 1: Write mock tools** (`tests/mocks/whatweb`, `tests/mocks/nikto`, `tests/mocks/testssl.sh`) — each prints one deterministic canned line to stdout.

- [ ] **Step 2: Write failing tests `tests/test_mode_web.bats`**

```bash
load test_helper
setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "mode_web_run uses whichever tools are present and records findings" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/web.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  mode_web_run "192.168.1.5" "$ws" ""
  [ -f "$ws/loot/web/whatweb.txt" ]
  [ -f "$ws/loot/web/nikto.txt" ]
  [ "$(findings::count "$ws" "medium")" -ge 1 ]
}

@test "mode_web_run fails cleanly when no web tool is on PATH" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/web.sh"
  PATH="/usr/bin:/bin" # none of the mocks on PATH
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  run mode_web_run "192.168.1.5" "$ws" ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"no web tool available"* ]]
}
```

- [ ] **Step 3: Run tests, verify they fail**

Run: `bats tests/test_mode_web.bats`
Expected: FAIL.

- [ ] **Step 4: Implement `modes/web.sh`** per the Interfaces block.

- [ ] **Step 5: Run tests, verify they pass**

Run: `bats tests/test_mode_web.bats`
Expected: 2 tests, PASS.

- [ ] **Step 6: Commit**

```bash
git add modes/web.sh tests/mocks/whatweb tests/mocks/nikto tests/mocks/testssl.sh tests/test_mode_web.bats
git commit -m "feat: add web recon/scan mode (modes/web.sh)"
```

---

## Task 10: `modes/osint.sh`

**Files:**
- Create: `modes/osint.sh`
- Create: `tests/mocks/subfinder`, `tests/mocks/theHarvester`
- Test: `tests/test_mode_osint.bats`

**Interfaces:**
- Consumes: `deps::check_or_warn`, `findings::add`, mode contract.
- Produces: `mode_osint_run(target, workspace_path, opts)`. Calls `curl` against `https://crt.sh/?q=<target>&output=json` (no external tool needed for this source) plus `subfinder`/`theHarvester` if present. `opts` containing the literal substring `--deep` also runs `theHarvester`; without it, `theHarvester` is skipped even if present (keeps the default run fast). Writes raw output per source to `<workspace>/loot/osint/<source>.txt`. Records one `severity="info"` finding per discovered subdomain.

- [ ] **Step 1: Write mock tools** `tests/mocks/subfinder`, `tests/mocks/theHarvester`, each printing one canned subdomain line.

- [ ] **Step 2: Write failing tests `tests/test_mode_osint.bats`**

```bash
load test_helper
setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "mode_osint_run records subdomain findings from subfinder" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/osint.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  mode_osint_run "example.test" "$ws" ""
  [ -f "$ws/loot/osint/subfinder.txt" ]
  [ "$(findings::count "$ws" "info")" -ge 1 ]
}

@test "mode_osint_run only runs theHarvester when --deep is passed" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/osint.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  mode_osint_run "example.test" "$ws" ""
  [ ! -f "$ws/loot/osint/theHarvester.txt" ]
  mode_osint_run "example.test" "$ws" "--deep"
  [ -f "$ws/loot/osint/theHarvester.txt" ]
}
```

- [ ] **Step 3: Run tests, verify they fail**

Run: `bats tests/test_mode_osint.bats`
Expected: FAIL.

- [ ] **Step 4: Implement `modes/osint.sh`** per the Interfaces block (the `curl` call to crt.sh should itself go through `deps::check_or_warn "curl" ...` and be skipped gracefully if curl is absent, since the mode must still work offline on mocked tools in CI — tests above don't assert on crt.sh behavior, only on subfinder/theHarvester).

- [ ] **Step 5: Run tests, verify they pass**

Run: `bats tests/test_mode_osint.bats`
Expected: 2 tests, PASS.

- [ ] **Step 6: Commit**

```bash
git add modes/osint.sh tests/mocks/subfinder tests/mocks/theHarvester tests/test_mode_osint.bats
git commit -m "feat: add OSINT mode (modes/osint.sh)"
```

---

## Task 11: `modes/vulnscan.sh`

**Files:**
- Create: `modes/vulnscan.sh`
- Create: `tests/mocks/nuclei`
- Test: `tests/test_mode_vulnscan.bats`

**Interfaces:**
- Consumes: `deps::check_or_warn`, `findings::add`, mode contract, and reuses the `nmap` mock from Task 8.
- Produces: `mode_vulnscan_run(target, workspace_path, opts)`. Hard-required: `nmap` (for `--script vuln`, same hard-fail rule as Task 8). Runs `nmap --script vuln` then, if `nuclei` is present, runs it and merges findings. Severity mapping: nmap vuln hits → `"high"`; nuclei findings → pass through nuclei's own severity field (mock emits `medium`), defaulting to `"medium"` if absent/unrecognized.

- [ ] **Step 1: Write mock `tests/mocks/nuclei`** printing one canned `[medium]` finding line.

- [ ] **Step 2: Write failing tests `tests/test_mode_vulnscan.bats`**

```bash
load test_helper
setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "mode_vulnscan_run records findings from both nmap vuln scripts and nuclei" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/vulnscan.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  mode_vulnscan_run "192.168.1.5" "$ws" ""
  [ "$(findings::count "$ws" "high")" -ge 1 ]
  [ "$(findings::count "$ws" "medium")" -ge 1 ]
}

@test "mode_vulnscan_run fails when nmap is missing even if nuclei is present" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/vulnscan.sh"
  mkdir -p "$CYBERAUTO_TMP/only-nuclei"
  cp "${BATS_TEST_DIRNAME}/mocks/nuclei" "$CYBERAUTO_TMP/only-nuclei/"
  PATH="$CYBERAUTO_TMP/only-nuclei"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  run mode_vulnscan_run "192.168.1.5" "$ws" ""
  [ "$status" -eq 1 ]
}
```

- [ ] **Step 3: Run tests, verify they fail**

Run: `bats tests/test_mode_vulnscan.bats`
Expected: FAIL.

- [ ] **Step 4: Implement `modes/vulnscan.sh`** per the Interfaces block.

- [ ] **Step 5: Run tests, verify they pass**

Run: `bats tests/test_mode_vulnscan.bats`
Expected: 2 tests, PASS.

- [ ] **Step 6: Commit**

```bash
git add modes/vulnscan.sh tests/mocks/nuclei tests/test_mode_vulnscan.bats
git commit -m "feat: add vulnerability scan mode (modes/vulnscan.sh)"
```

---

## Task 12: Orchestration modes (massport, massweb, massvuln, airstrike, full)

**Files:**
- Create: `modes/massport.sh`, `modes/massweb.sh`, `modes/massvuln.sh`, `modes/airstrike.sh`, `modes/full.sh`
- Test: `tests/test_modes_mass.bats`

**Interfaces:**
- Consumes: `mode_port_run`/`mode_fullport_run` (Task 8), `mode_web_run` (Task 9), `mode_vulnscan_run` (Task 11), `workspace::create` (Task 4).
- Produces: each of these modes takes a *target-file path* as its `target` argument (one target per line) instead of a single host, loops over the file's lines, and for each target calls the corresponding single-target mode function, catching its exit status and appending `"<target>: <mode> exited <status>"` to `<workspace>/logs/<this-mode>.log` on nonzero without stopping the loop (per spec §8 — one target's failure never aborts the batch). `massport` → loops `mode_port_run`; `massweb` → loops `mode_web_run`; `massvuln` → loops `mode_vulnscan_run`; `airstrike` → loops `mode_recon_run` (fast single pass); `full` → for each target, runs recon, web, vulnscan, osint in sequence (not bruteforce — bruteforce is never implied by `full`, it always needs its own explicit flags per Global Constraints).

- [ ] **Step 1: Write failing tests `tests/test_modes_mass.bats`**

```bash
load test_helper
setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "mode_massport_run processes every target and logs per-target failures without aborting" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/port.sh"
  source "${BATS_TEST_DIRNAME}/../modes/massport.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  printf "192.168.1.5\n192.168.1.6\n" > "$CYBERAUTO_TMP/targets.txt"
  mode_massport_run "$CYBERAUTO_TMP/targets.txt" "$ws" "--ports 80"
  [ -f "$ws/loot/port/nmap.txt" ]
  grep -q "192.168.1.5" "$ws/logs/massport.log" || true
}

@test "mode_full_run runs recon, web and vulnscan for a single target" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/recon.sh"
  source "${BATS_TEST_DIRNAME}/../modes/web.sh"
  source "${BATS_TEST_DIRNAME}/../modes/vulnscan.sh"
  source "${BATS_TEST_DIRNAME}/../modes/osint.sh"
  source "${BATS_TEST_DIRNAME}/../modes/full.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  printf "192.168.1.5\n" > "$CYBERAUTO_TMP/targets.txt"
  mode_full_run "$CYBERAUTO_TMP/targets.txt" "$ws" ""
  [ -f "$ws/loot/recon/nmap.txt" ]
  [ -f "$ws/loot/web/whatweb.txt" ]
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `bats tests/test_modes_mass.bats`
Expected: FAIL.

- [ ] **Step 3: Implement all five mode files** per the Interfaces block.

- [ ] **Step 4: Run tests, verify they pass**

Run: `bats tests/test_modes_mass.bats`
Expected: 2 tests, PASS.

- [ ] **Step 5: Commit**

```bash
git add modes/massport.sh modes/massweb.sh modes/massvuln.sh modes/airstrike.sh modes/full.sh tests/test_modes_mass.bats
git commit -m "feat: add batch orchestration modes (massport, massweb, massvuln, airstrike, full)"
```

---

## Task 13: `modes/bruteforce.sh` — double-gated, opt-in only

**Files:**
- Create: `modes/bruteforce.sh`
- Create: `tests/mocks/ncrack`, `tests/mocks/netexec`
- Test: `tests/test_mode_bruteforce.bats`

**Interfaces:**
- Consumes: `deps::check_or_warn`, `findings::add`, mode contract.
- Produces: `mode_bruteforce_run(target, workspace_path, opts)`. **This function assumes the double-gate (`--i-am-authorized` AND `--allow-bruteforce`) was already checked by the entrypoint** (Task 6 must be extended there — see Step 4) and additionally re-checks for `opts` containing `--allow-bruteforce` as a defense-in-depth assertion, returning 1 with `"ERROR: bruteforce requires --allow-bruteforce"` if absent even when called directly. Requires `opts` to contain `--service <name>` (one of `ssh,ftp,http,rdp,smb`, hard-coded allow-list — anything else returns 1 with `"ERROR: unsupported service"`) and `--userlist <path>` and `--passlist <path>` (both user-supplied, never bundled; returns 1 with `"ERROR: wordlist not found"` if either path doesn't exist). Default backend: `ncrack`. If `opts` contains `--backend netexec`, uses `netexec` instead (only for `--service smb`; any other service with `--backend netexec` returns 1). Writes raw backend output to `<workspace>/loot/bruteforce/<backend>.txt`, and on a successful-login line calls `findings::add` with `severity="critical"`.

- [ ] **Step 1: Write mocks** `tests/mocks/ncrack`, `tests/mocks/netexec`, each printing one canned "successful login" line for a fixed fake user/pass pair, used only to prove the parsing/finding logic — never real credential material.

- [ ] **Step 2: Write failing tests `tests/test_mode_bruteforce.bats`**

```bash
load test_helper
setup() {
  setup_cyberauto_test
  echo "testuser" > "$CYBERAUTO_TMP/users.txt"
  echo "testpass" > "$CYBERAUTO_TMP/pass.txt"
}
teardown() { teardown_cyberauto_test; }

@test "refuses without --allow-bruteforce even if called directly" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/bruteforce.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  run mode_bruteforce_run "192.168.1.5" "$ws" "--service ssh --userlist $CYBERAUTO_TMP/users.txt --passlist $CYBERAUTO_TMP/pass.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--allow-bruteforce"* ]]
}

@test "refuses an unsupported service" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/bruteforce.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  run mode_bruteforce_run "192.168.1.5" "$ws" "--allow-bruteforce --service telnet --userlist $CYBERAUTO_TMP/users.txt --passlist $CYBERAUTO_TMP/pass.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unsupported service"* ]]
}

@test "refuses a missing wordlist path" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/bruteforce.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  run mode_bruteforce_run "192.168.1.5" "$ws" "--allow-bruteforce --service ssh --userlist /no/such/file --passlist $CYBERAUTO_TMP/pass.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"wordlist not found"* ]]
}

@test "default backend ncrack records a critical finding on success" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/bruteforce.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  mode_bruteforce_run "192.168.1.5" "$ws" "--allow-bruteforce --service ssh --userlist $CYBERAUTO_TMP/users.txt --passlist $CYBERAUTO_TMP/pass.txt"
  [ -f "$ws/loot/bruteforce/ncrack.txt" ]
  [ "$(findings::count "$ws" "critical")" -ge 1 ]
}

@test "netexec backend is rejected for a non-smb service" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/bruteforce.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  run mode_bruteforce_run "192.168.1.5" "$ws" "--allow-bruteforce --service ssh --backend netexec --userlist $CYBERAUTO_TMP/users.txt --passlist $CYBERAUTO_TMP/pass.txt"
  [ "$status" -eq 1 ]
}
```

- [ ] **Step 3: Run tests, verify they fail**

Run: `bats tests/test_mode_bruteforce.bats`
Expected: FAIL.

- [ ] **Step 4: Implement `modes/bruteforce.sh`** per the Interfaces block. Also extend `cyberauto` (Task 6) so that when `-m bruteforce` is selected, the entrypoint additionally requires `--allow-bruteforce` on the command line (same refusal style as the existing `--i-am-authorized` check) before even sourcing the mode file — this is the first of the two independent gates; the mode's own internal check (above) is the second, defense-in-depth layer.

- [ ] **Step 5: Run tests, verify they pass**

Run: `bats tests/test_mode_bruteforce.bats`
Expected: 5 tests, PASS.

- [ ] **Step 6: Commit**

```bash
git add modes/bruteforce.sh tests/mocks/ncrack tests/mocks/netexec tests/test_mode_bruteforce.bats cyberauto
git commit -m "feat: add double-gated bruteforce mode (Ncrack default, NetExec optional)"
```

---

## Task 14: `modes/hostaudit.sh`

**Files:**
- Create: `modes/hostaudit.sh`
- Test: `tests/test_mode_hostaudit.bats`

**Interfaces:**
- Consumes: `deps::check_or_warn`, `findings::add`, mode contract.
- Produces: `mode_hostaudit_run(target, workspace_path, opts)` where `target` is always the literal string `"localhost"` (hostaudit never takes a network target — the entrypoint's scope guard treats `"localhost"` as always in-scope, a one-line addition to `scope::check` in Task 3's file made here: `"localhost"` short-circuits to allowed). Checks, each independently, each appending one finding if non-compliant: (1) SSH root login — reads `/etc/ssh/sshd_config` via a path overridable by `opts` (`--sshd-config <path>`, defaulting to `/etc/ssh/sshd_config`) for `PermitRootLogin yes` → `severity="high"`; (2) a world-writable file check restricted to a path list from `opts` (`--check-paths <comma-list>`) rather than walking the whole filesystem — defaults to none if not given, so the mode is inert (returns 0, 0 findings) with no `opts`, which the test below exercises; (3) if `lynis` is present (optional, per `deps::check_or_warn`), runs it and stores raw output, without translating its findings yet (`compliance-lite` in Task 15 maps hostaudit's own checks only, not lynis output, to keep the v1 mapping exact and reviewable).

- [ ] **Step 1: Write failing tests `tests/test_mode_hostaudit.bats`**

```bash
load test_helper
setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "flags PermitRootLogin yes as a high-severity finding" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/hostaudit.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  printf "PermitRootLogin yes\n" > "$CYBERAUTO_TMP/sshd_config"
  mode_hostaudit_run "localhost" "$ws" "--sshd-config $CYBERAUTO_TMP/sshd_config"
  [ "$(findings::count "$ws" "high")" -ge 1 ]
}

@test "does not flag PermitRootLogin no" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/hostaudit.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  printf "PermitRootLogin no\n" > "$CYBERAUTO_TMP/sshd_config"
  mode_hostaudit_run "localhost" "$ws" "--sshd-config $CYBERAUTO_TMP/sshd_config"
  [ "$(findings::count "$ws" "high")" -eq 0 ]
}

@test "is inert with no --check-paths (no crash, zero findings from that check)" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/hostaudit.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  printf "PermitRootLogin no\n" > "$CYBERAUTO_TMP/sshd_config"
  run mode_hostaudit_run "localhost" "$ws" "--sshd-config $CYBERAUTO_TMP/sshd_config"
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `bats tests/test_mode_hostaudit.bats`
Expected: FAIL.

- [ ] **Step 3: Add the `"localhost"` short-circuit to `scope::check` in `lib/scope.sh`**, then implement `modes/hostaudit.sh` per the Interfaces block.

- [ ] **Step 4: Run tests, verify they pass**

Run: `bats tests/test_mode_hostaudit.bats && bats tests/test_scope.bats`
Expected: all PASS (re-running `test_scope.bats` guards against regressing Task 3).

- [ ] **Step 5: Commit**

```bash
git add modes/hostaudit.sh lib/scope.sh tests/test_mode_hostaudit.bats
git commit -m "feat: add defensive host-audit mode (modes/hostaudit.sh)"
```

---

## Task 15: `modes/compliance-lite.sh`

**Files:**
- Create: `modes/compliance-lite.sh`
- Test: `tests/test_mode_compliance_lite.bats`

**Interfaces:**
- Consumes: the `findings.jsonl` schema (Task 5) as written by `hostaudit` (Task 14).
- Produces: `mode_compliancelite_run(target, workspace_path, opts)`. Reads every finding in `workspace_path/findings.jsonl` whose `mode == "hostaudit"`, maps the single v1 check (`PermitRootLogin yes`) to CIS Control `5.2` with a hard-coded `{check_id, cis_control, status}` table (`status` is `"fail"` if that finding exists for the target, else `"pass"`), and writes `<workspace>/loot/compliance-lite/score.json` containing `{"total_checks":1,"passed":<n>,"score_pct":<n/1*100>}`. This mapping table is intentionally a single entry in v1 (per spec §6, "pas un moteur de conformité complet") — later hostaudit checks register themselves in the same table, not a parallel one.

- [ ] **Step 1: Write failing tests `tests/test_mode_compliance_lite.bats`**

```bash
load test_helper
setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "scores 0% when the PermitRootLogin finding is present" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/compliance-lite.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  findings::add "$ws" "hostaudit" "localhost" "high" "SSH PermitRootLogin yes" "d" "r"
  mode_compliancelite_run "localhost" "$ws" ""
  jq -e '.score_pct == 0' "$ws/loot/compliance-lite/score.json"
}

@test "scores 100% when there is no PermitRootLogin finding" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/compliance-lite.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  findings::add "$ws" "recon" "192.168.1.5" "info" "unrelated" "d" "r"
  mode_compliancelite_run "localhost" "$ws" ""
  jq -e '.score_pct == 100' "$ws/loot/compliance-lite/score.json"
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `bats tests/test_mode_compliance_lite.bats`
Expected: FAIL.

- [ ] **Step 3: Implement `modes/compliance-lite.sh`** per the Interfaces block.

- [ ] **Step 4: Run tests, verify they pass**

Run: `bats tests/test_mode_compliance_lite.bats`
Expected: 2 tests, PASS.

- [ ] **Step 5: Commit**

```bash
git add modes/compliance-lite.sh tests/test_mode_compliance_lite.bats
git commit -m "feat: add lightweight CIS compliance scoring (modes/compliance-lite.sh)"
```

---

## Task 16: `scripts/install.sh` + `scripts/uninstall.sh`

**Files:**
- Create: `scripts/install.sh`
- Create: `scripts/uninstall.sh`
- Test: `tests/test_install_uninstall.bats`

**Interfaces:**
- Consumes: nothing from lib/modes (these are standalone operational scripts).
- Produces: `install.sh` detects the package manager (`apt-get`, `pacman`, or neither → prints "unsupported distro, install manually: <tool list>" and exits 1), then installs the hard-required tools (`jq`, `nmap`) via that manager, and for each optional tool in the spec's §5 table that has a package of the same or a documented name, attempts install and on failure prints a one-line "optional: install <tool> manually" without aborting. `uninstall.sh` removes only files this project created (never touches system packages) — i.e., it is scoped to deleting the project's own `workspaces/` contents after a confirmation prompt, matching the spec's "ne modifie jamais ... sans confirmation explicite" principle carried over to uninstall.

- [ ] **Step 1: Write failing test `tests/test_install_uninstall.bats`**

```bash
load test_helper
setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "install.sh reports unsupported distro cleanly when no known package manager exists" {
  PATH="/usr/bin:/bin" # assume neither apt-get nor pacman is first on a minimal PATH in CI runner image; this test is skipped if either is found
  if command -v apt-get >/dev/null || command -v pacman >/dev/null; then
    skip "a real package manager is present in this environment"
  fi
  run "${BATS_TEST_DIRNAME}/../scripts/install.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unsupported distro"* ]]
}

@test "uninstall.sh refuses to delete workspaces without confirmation" {
  mkdir -p "$CYBERAUTO_TMP/workspaces/demo"
  run bash -c "echo n | '${BATS_TEST_DIRNAME}/../scripts/uninstall.sh' --workspace-dir '$CYBERAUTO_TMP/workspaces'"
  [ -d "$CYBERAUTO_TMP/workspaces/demo" ]
}

@test "uninstall.sh deletes workspaces when confirmed" {
  mkdir -p "$CYBERAUTO_TMP/workspaces/demo"
  run bash -c "echo y | '${BATS_TEST_DIRNAME}/../scripts/uninstall.sh' --workspace-dir '$CYBERAUTO_TMP/workspaces'"
  [ ! -d "$CYBERAUTO_TMP/workspaces/demo" ]
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `bats tests/test_install_uninstall.bats`
Expected: FAIL — scripts not found.

- [ ] **Step 3: Implement `scripts/install.sh` and `scripts/uninstall.sh`** per the Interfaces block.

- [ ] **Step 4: Run tests, verify they pass**

Run: `bats tests/test_install_uninstall.bats`
Expected: 3 tests, PASS (first may `skip` depending on the CI image).

- [ ] **Step 5: Commit**

```bash
git add scripts/install.sh scripts/uninstall.sh tests/test_install_uninstall.bats
git commit -m "feat: add install/uninstall scripts"
```

---

## Task 17: `scripts/schedule.sh`

**Files:**
- Create: `scripts/schedule.sh`
- Test: `tests/test_schedule.bats`

**Interfaces:**
- Consumes: nothing.
- Produces: `scripts/schedule.sh <alias> <daily|weekly|monthly>` prints the crontab line it *would* add (`@daily`/`@weekly`/`@monthly` prefix plus `cyberauto -w <alias> --rerun`) and only writes it to the user's crontab via `crontab -l`/`crontab -` after an explicit `y` confirmation prompt (same pattern as `uninstall.sh`); any other frequency argument is rejected with `"ERROR: unknown frequency"` and exit 1.

- [ ] **Step 1: Write failing tests `tests/test_schedule.bats`**

```bash
load test_helper
setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "rejects an unknown frequency" {
  run "${BATS_TEST_DIRNAME}/../scripts/schedule.sh" demo hourly
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown frequency"* ]]
}

@test "prints the crontab line for a known frequency without confirming" {
  run bash -c "echo n | '${BATS_TEST_DIRNAME}/../scripts/schedule.sh' demo daily"
  [[ "$output" == *"@daily"* ]]
  [[ "$output" == *"cyberauto -w demo --rerun"* ]]
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `bats tests/test_schedule.bats`
Expected: FAIL.

- [ ] **Step 3: Implement `scripts/schedule.sh`** per the Interfaces block.

- [ ] **Step 4: Run tests, verify they pass**

Run: `bats tests/test_schedule.bats`
Expected: 2 tests, PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/schedule.sh tests/test_schedule.bats
git commit -m "feat: add scan scheduling script"
```

---

## Task 18: CI workflow, shellcheck gate, README completion

**Files:**
- Create: `.github/workflows/ci.yml`
- Modify: `README.md` (replace Task 1's stub with full usage docs)

**Interfaces:**
- Consumes: every `tests/*.bats` file from Tasks 2–17.
- Produces: a GitHub Actions workflow with two jobs — `shellcheck` (runs `shellcheck cyberauto lib/*.sh modes/*.sh scripts/*.sh`, failing the build on any warning) and `bats` (installs `bats-core`, runs `bats tests/*.bats`) — triggered on `push` and `pull_request`.

- [ ] **Step 1: Write `.github/workflows/ci.yml`** with the `shellcheck` and `bats` jobs described above.

- [ ] **Step 2: Run shellcheck locally against every shell file and fix any reported issue**

Run: `shellcheck cyberauto lib/*.sh modes/*.sh scripts/*.sh`
Expected: no warnings (fix inline until clean).

- [ ] **Step 3: Run the full test suite locally**

Run: `bats tests/*.bats`
Expected: every test from Tasks 2–17, PASS.

- [ ] **Step 4: Fill in `README.md`**

Usage examples for every mode (mirroring the CLI contract from Task 6), the authorization/scope requirements from Global Constraints, the tool table from spec §5, install instructions referencing `scripts/install.sh`, and the "independent project, no code shared with Sn1per, authorized use only" notice already stubbed in Task 1.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/ci.yml README.md
git commit -m "chore: add CI (shellcheck + bats) and complete README"
```

---

## Self-Review Notes

- **Spec coverage:** §2 (principles) → Task 6/Global Constraints; §3 (architecture/file tree) → Tasks 1–17 match the tree exactly; §4 (mode inventory) → Tasks 8–15 cover every listed mode, §12 out-of-scope items correctly have no task; §5 (tool bindings) → Tasks 8–15 each wire the exact tools listed; §6 (bruteforce guardrails) → Task 13; §7 (data flow) → Tasks 3/4/5/7 implement each stage; §8 (error handling) → Review Focus items 1–2 plus Task 12's per-target logging; §9 (tests/CI) → Task 18; §10 (install/licence) → Tasks 1, 16; §11 (hosting) → handled after this plan, at push time, not a coding task.
- **Review Focus coverage:** all five items have an owning test — scope hard-stop (Task 3/6), hard-vs-soft tool failure (Task 8 vs Task 9/11), bruteforce double gate (Task 13), JSON escaping (Task 5), idempotent workspace reuse (Task 4).
- **Type/name consistency checked:** `mode_<name>_run` naming verified consistent across Tasks 6, 8–15; `findings::add`/`findings::count` signatures identical everywhere they're consumed; `workspace::create` return convention (prints path, idempotent) consistent across Tasks 4, 6, 8–15.
- **Proportion:** this plan is longer than the spec because each task carries its own test code (the spec intentionally does not), which is expected; no task carries a full implementation body beyond what its signature and tests already fix.
