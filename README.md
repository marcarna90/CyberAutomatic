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

Full usage docs are in progress — see `docs/superpowers/specs/` and
`docs/superpowers/plans/` for the design and implementation plan in the
meantime.
