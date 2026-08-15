# NOCTTY Backlog

Last refreshed: 2026-08-10.

## Source Of Truth Policy

Only incomplete accepted work lives here. `[status:yellow]` is locally evidenced but not closed; `[truth:*]` names that evidence. Archive completed or retired work.

## Completion Index

| ID | Open boundary |
|---|---|
| NCT-112 | Multi-day terminal stability |
| NCT-123 | Experimental Windows host parity and physical qualification |
| Release operations | Signed artifacts, publication, independent redistribution review, compositor and HID acceptance |

## Active

### NCT-112 Terminal stability and agent-resource qualification — partial

- [ ] [status:yellow] Complete the retained 48-hour `ReleaseSafe` Wayland/X11 hidden/visible matrix. The mode-40 runner, exact phase/resource receipts, 64 MiB root-growth guard, compositor capture, and four-lane Debug/`ReleaseSafe` shakedown pass; elapsed authenticated execution remains open. `[truth:test,measurement]`

Focused receipts and proof boundaries live in `docs/TECHNICAL_STATUS.md`,
`docs/RELEASE_CHECKLIST.md`, and the linked qualification records.

### NCT-123 Experimental Windows host — partial

- [ ] [status:yellow] Physically qualify the x86_64 Win32/GDI + ConPTY host on
  Windows 10/11. The source tranche now cross-compiles without GTK, owns bounded
  tabs/splits and per-pane ConPTY/VT state, supports native selection and DEC
  mouse reporting, ships the separate native NoctEd editor, and produces a
  reproducible per-user NSIS installer with reversible shortcuts/Open-With
  registration and an operator-owned signing hook. Wine-hosted self-tests and
  installer lifecycle smoke pass, but Wine does not prove physical ConPTY/GDI,
  input, installer, or editor behavior on supported Windows releases.
  `[truth:build,test,docs]`

## Release Operations

- [ ] [status:yellow] Retain both architecture artifacts/signatures, publication, independent dependency-bundle redistribution review and receipts, final compositor acceptance, and consented Wayland HID capture. The NCT-077 follow-through is locally closed; external evidence remains operator-owned. `[truth:build,docs,external]`
