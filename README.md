# CyberAutomatic

A lightweight Bash orchestrator combining opt-in-gated offensive
reconnaissance/pentest automation with defensive host-audit modules, behind a
built-in authorization and scope guard.

**Independent project.** CyberAutomatic shares no code, wordlists, or
templates with any other security tool — it is an original implementation
inspired only by the general *concept* of automated recon/pentest tooling.

**Authorized use only.** CyberAutomatic refuses to run any offensive mode
without `--i-am-authorized`, and refuses any target outside
`CYBERAUTO_ALLOWED_TARGETS` (private ranges by default). Use it only against
systems you are explicitly authorized to test.

License: MIT.

## Install

```bash
./scripts/install.sh      # detects apt/pacman, installs required + optional tools
cp conf/cyberauto.conf.example cyberauto.conf   # edit CYBERAUTO_ALLOWED_TARGETS
```

Only `jq` and `nmap` are required. Every other tool below is optional per
mode: if it's missing, that one step is skipped with a logged warning
instead of failing the whole run.

| Category | Modes | Tools | Role |
|---|---|---|---|
| Ports/services | recon, port, fullport, discover, massport | nmap (required), masscan (optional) | host/service discovery |
| Web recon | web, massweb | whatweb, httpx, wafw00f | tech fingerprint / WAF detection |
| Web scan | web, massweb | nikto, ffuf/gobuster | known web vulns, fuzzing |
| Screenshots | web | gowitness | visual evidence |
| Vulnerabilities | vulnscan, massvuln | nmap --script vuln, nuclei | CVE/misconfig detection |
| TLS/SSL | web, vulnscan | testssl.sh, sslscan | weak protocols/ciphers |
| OSINT | osint | amass/subfinder, theHarvester, curl (crt.sh) | passive reconnaissance |
| Bruteforce (opt-in) | bruteforce | Ncrack (default), NetExec (SMB only) | credential testing, strictly gated |
| Host audit | hostaudit | none required; lynis optional | local hardening checks |
| Reporting | all | pandoc (optional) | PDF export from Markdown/HTML |

## Usage

```bash
# Authorization + scope: every offensive command below needs this
cyberauto -t <target> -m <mode> -w <workspace> --i-am-authorized

# Single-target offensive modes
cyberauto -t 192.168.1.5 -m recon     -w demo --i-am-authorized
cyberauto -t 192.168.1.5 -m stealth   -w demo --i-am-authorized
cyberauto -t 192.168.1.0/24 -m discover -w demo --i-am-authorized
cyberauto -t 192.168.1.5 -m port      -w demo --i-am-authorized -- --ports 80,443
cyberauto -t 192.168.1.5 -m fullport  -w demo --i-am-authorized
cyberauto -t 192.168.1.5 -m web       -w demo --i-am-authorized
cyberauto -t example.test -m osint    -w demo --i-am-authorized -- --deep
cyberauto -t 192.168.1.5 -m vulnscan  -w demo --i-am-authorized

# Bruteforce — double-gated, off by default, no bundled wordlists
cyberauto -t 192.168.1.5 -m bruteforce -w demo --i-am-authorized --allow-bruteforce \
  -- --service ssh --userlist users.txt --passlist passwords.txt

# Batch modes — target file, one host per line
cyberauto -f targets.txt -m massport  -w demo --i-am-authorized -- --ports 80
cyberauto -f targets.txt -m massweb   -w demo --i-am-authorized
cyberauto -f targets.txt -m massvuln  -w demo --i-am-authorized
cyberauto -f targets.txt -m airstrike -w demo --i-am-authorized
cyberauto -f targets.txt -m full      -w demo --i-am-authorized

# Defensive modes — local host audit, no network target
cyberauto -t localhost -m hostaudit       -w demo --i-am-authorized -- --check-paths /tmp
cyberauto -t localhost -m compliance-lite -w demo --i-am-authorized

# Reports — render the workspace's findings.jsonl via templates/
cyberauto -w demo --report demo-report.md

# Workspaces
cyberauto --list
cyberauto -w demo -d                      # delete a workspace
cyberauto -w demo --export demo.tar.gz    # export
cyberauto --reimport demo.tar.gz          # reimport
cyberauto -w demo --rerun --i-am-authorized  # repeat the last recorded run

# Scheduling (generates a crontab line, confirms before installing it)
./scripts/schedule.sh demo daily
```

A full scan writes raw tool output to `workspaces/<alias>/loot/<mode>/` and
structured findings to `workspaces/<alias>/findings.jsonl`. Run
`cyberauto -w <alias> --report <output.md>` whenever you want a rendered
report from those findings, using the templates in `templates/`.

## Uninstall

```bash
./scripts/uninstall.sh --workspace-dir ./workspaces   # asks for confirmation
```

## Development

```bash
shellcheck cyberauto lib/*.sh modes/*.sh scripts/*.sh
bats tests/*.bats
```

See `docs/superpowers/specs/` and `docs/superpowers/plans/` for the design
spec and implementation plan this v1 was built from.
