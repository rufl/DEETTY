# NoctEd KOF4J Compatibility Definition of Done

Status: **open acceptance gate**. NoctEd currently has general language import,
syntax discovery, local linter/LSP transport, diagnostics, completion, hover,
definition, references, rename, symbols, and formatting surfaces. This document
adds the project-specific requirement; those general capabilities do not prove
KOF4J compatibility.

The canonical KOF4J project fixture, its repository revision, build/language
inventory, linter configuration and version, LSP configuration and server
versions, and every required local tool must be pinned in the retained receipt.
NoctEd must not silently download tools or substitute a different project
configuration.

## Current implementation baseline (not acceptance)

The source tree now carries the official `source.kof` grammar as both its
vendored TextMate input and generated GtkSourceView `kof.lang` definition.
NoctEd maps `.kf` and `.kof` to `kof lsp`, and Kof tooling-project detection
invokes the local distribution launcher for `check`, `build`, and `test`.
`scripts/nocted_kof4j_qualification.sh` exercises a supplied real
distribution, but its receipt remains `status=partial`: no canonical fixture
manifest, complete advertised-capability matrix, lifecycle receipt, or
isolated native Debug/`ReleaseSafe` evidence is committed.

## Fixed DoD

The gate closes only when the canonical KOF4J project passes all of these on
every supported NoctEd target claimed by the release:

1. **100% language coverage.** Every KOF4J source, generated-but-opened, config,
   template, and documentation file type in the inventory opens with the
   correct NoctEd language identity and complete declared syntax/highlighting
   behavior. Unsupported or misidentified files are zero; skipped file classes
   must be explicitly approved in the fixture manifest.
2. **100% linter compatibility.** NoctEd discovers and invokes the exact KOF4J
   linter and project configuration from the project root, preserves its
   working directory and arguments, and renders every fixture diagnostic with
   correct file, range, severity, message, and version. Clean output, warnings,
   errors, non-zero exits, malformed output, cancellation, timeout, and missing
   executable paths must each have an explicit observable result; no diagnostic
   may be silently dropped or fabricated.
3. **100% required LSP compatibility.** NoctEd launches the exact KOF4J language
   servers and configuration over its local bounded stdio JSON-RPC path. Every
   KOF4J-required capability—initialization, workspace roots, open/change
   versions, diagnostics, completion, hover, definition, references, rename,
   document symbols, formatting, cancellation, restart, and shutdown—must pass
   the project fixture where the server advertises it. Unsupported server
   capabilities must be reported explicitly rather than treated as success.
4. **Project lifecycle compatibility.** Open, reload, rename, nested-module,
   generated/vendor-ignore, unsaved-buffer, multi-file, server restart, linter
   failure, and clean NoctEd exit flows must preserve project root, language,
   linter, and LSP state without stale diagnostics or cross-project leakage.
5. **Evidence integrity.** The receipt identifies the KOF4J revision, exact
   tool/server versions, configuration hashes, NoctEd commit and package
   digest, exercised language/linter/LSP cases, unsupported-but-approved cases,
   failures, skips, and host/backend. Debug and `ReleaseSafe` runs plus native
   NoctEd smoke must pass; source inspection alone, a single opened file, or a
   mocked server does not close this gate.

The acceptance receipt must state
`nocted_kof4j_compatibility languages=100% linter=100% lsp=100% lifecycle=true`
and must not use `100%` until every fixture-manifest row has a passing result.
