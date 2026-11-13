# Release Operations Evidence

Last refreshed: 2026-10-02.

The 0.1.0 product behavior and local release-source evidence are complete. The remaining release operations need external runners, release credentials, unavailable compositor sessions, or explicit user consent. Local verification must keep those operations visible without converting them into source-code success. The ztash path builds reproducible x86_64 Linux and Windows archives with manifest/checksum receipts, but remains build-only and reports `remote_deployment=not_performed`; it is not a release signature, publication, or physical-host receipt.

The maintained local status command is:

```sh
./scripts/release_operations_status.sh
```

Current expected local receipt without retained external evidence:

```text
release_operations_status version=0.1.0 tagged_artifacts=false signatures=false publication=false dependency_bundle_redistribution=false compositor_acceptance=false wayland_hid_consent=false complete=false external_blockers=6
```

Use `./scripts/release_operations_status.sh --require-complete` only after collecting the evidence below. The normal `./scripts/verify.sh` gate intentionally accepts `complete=false` because these are release-operation blockers, not application-source blockers.

For deterministic diagnostics:

```sh
./scripts/release_operations_status.sh --list-missing
```

An empty evidence directory emits issue rows such as:

```text
release_operations_issue category=tagged_artifacts path=deetty-linux-x86_64.tar.gz reason=missing
release_operations_issue category=compositor_acceptance path=compositors/niri.txt reason=missing
release_operations_issues total=21
```

`./scripts/release_operations_status_smoke.sh` proves those diagnostics, proves incomplete evidence fails `--require-complete`, and proves a complete checksum-verified fixture can satisfy the release-operation gate. Its acceptance receipt is `release_operations_status_smoke missing_diagnostics=true require_complete_blocks=true complete_fixture=true checksum_verified=true semantic_receipts=true bundle_manifest_attestation=true scratch_clean=true`.

To create editable templates:

```sh
./scripts/release_operations_scaffold.sh release/evidence/0.1.0
```

The scaffold creates publication, redistribution, compositor, and Wayland HID receipt templates with TODO fields, but it does not create fake artifacts, checksum sidecars, manifests, or signatures. Its receipt is `release_operations_scaffold version=0.1.0 path=release/evidence/0.1.0 receipt_templates=true compositor_templates=6 placeholder_blocking=true artifact_files=false`; the smoke receipt is `release_operations_scaffold_smoke templates=true fake_artifacts=false placeholder_blocked=true require_complete_blocks=true scratch_clean=true`.

To retain architecture artifacts after a tagged workflow run:

```sh
./scripts/release_operations_artifact_intake.sh x86_64 /path/to/deetty-linux-x86_64.tar.gz release/evidence/0.1.0
./scripts/release_operations_artifact_intake.sh aarch64 /path/to/deetty-linux-aarch64.tar.gz release/evidence/0.1.0
```

Each archive must have adjacent `.sha256` and `.manifest` sidecars. The intake guard runs `sha256sum -c`, requires `architecture=<arch>`, requires `archive_sha256=<sidecar digest>`, and rewrites the retained checksum sidecar to the canonical evidence filename. Its smoke receipt is `release_operations_artifact_intake_smoke x86_64=true aarch64=true sidecars_verified=true retained_status=true mismatch_blocked=true scratch_clean=true`. After both lanes are retained, status can report `tagged_artifacts=true signatures=false publication=false dependency_bundle_redistribution=false compositor_acceptance=false wayland_hid_consent=false complete=false external_blockers=5`; this proves retained architecture artifacts only, not signatures or publication.

To retain signatures after the matching targets exist:

```sh
./scripts/release_operations_signature_intake.sh x86_64 archive /path/to/deetty-linux-x86_64.tar.gz.sig release/evidence/0.1.0
./scripts/release_operations_signature_intake.sh x86_64 checksum /path/to/deetty-linux-x86_64.tar.gz.sha256.sig release/evidence/0.1.0
./scripts/release_operations_signature_intake.sh x86_64 manifest /path/to/deetty-linux-x86_64.tar.gz.manifest.sig release/evidence/0.1.0
./scripts/release_operations_signature_intake.sh aarch64 archive /path/to/deetty-linux-aarch64.tar.gz.sig release/evidence/0.1.0
./scripts/release_operations_signature_intake.sh aarch64 checksum /path/to/deetty-linux-aarch64.tar.gz.sha256.sig release/evidence/0.1.0
./scripts/release_operations_signature_intake.sh aarch64 manifest /path/to/deetty-linux-aarch64.tar.gz.manifest.sig release/evidence/0.1.0
```

The signature intake guard requires the canonical retained artifact, checksum, or manifest target to already exist, rejects empty or placeholder signature files, and copies the signature into the canonical evidence filename. It does not perform cryptographic verification; that remains a release-key operation outside local source verification. Its smoke receipt is `release_operations_signature_intake_smoke archive=true checksum=true manifest=true x86_64=true aarch64=true placeholder_blocked=true target_required=true retained_status=true scratch_clean=true`. After all six signatures are retained, status can report `tagged_artifacts=true signatures=true publication=false dependency_bundle_redistribution=false compositor_acceptance=false wayland_hid_consent=false complete=false external_blockers=4`; this proves retained signature files only, not publication or key trust.

To retain publication or dependency-bundle redistribution receipts:

```sh
./scripts/release_operations_receipt_intake.sh publication /path/to/publication-receipt.txt release/evidence/0.1.0
./scripts/release_operations_receipt_intake.sh dependency-bundle-redistribution /path/to/dependency-bundle-redistribution-notices.md release/evidence/0.1.0
```

The receipt intake guard rejects placeholder text and requires the semantic fields consumed by `./scripts/release_operations_status.sh`. Publication also stays blocked unless retained tagged artifacts and retained signatures are already true; a standalone publication receipt is diagnosed with `publication_prerequisites_missing`. Its smoke receipt is `release_operations_receipt_intake_smoke publication=true redistribution=true semantic=true placeholder_blocked=true incomplete_blocked=true manifest_attestation=true publication_prerequisites=true retained_status=true scratch_clean=true`. After publication and redistribution receipts are retained on top of artifacts and signatures, status can report `tagged_artifacts=true signatures=true publication=true dependency_bundle_redistribution=true compositor_acceptance=false wayland_hid_consent=false complete=false external_blockers=2`; this proves retained receipt semantics only, not live compositor acceptance or consented Wayland HID evidence.

To retain final compositor acceptance and Wayland HID consent receipts:

```sh
./scripts/release_operations_acceptance_intake.sh compositor niri /path/to/niri.txt release/evidence/0.1.0
./scripts/release_operations_acceptance_intake.sh compositor hyprland /path/to/hyprland.txt release/evidence/0.1.0
./scripts/release_operations_acceptance_intake.sh compositor sway /path/to/sway.txt release/evidence/0.1.0
./scripts/release_operations_acceptance_intake.sh compositor scroll /path/to/scroll.txt release/evidence/0.1.0
./scripts/release_operations_acceptance_intake.sh compositor labwc /path/to/labwc.txt release/evidence/0.1.0
./scripts/release_operations_acceptance_intake.sh compositor mango /path/to/mango.txt release/evidence/0.1.0
./scripts/release_operations_acceptance_intake.sh wayland-hid /path/to/wayland-hid-consent-receipt.txt release/evidence/0.1.0
```

The acceptance intake guard rejects placeholder text, requires each compositor receipt to name the requested compositor plus `native_release_smoke=true` and `operator_acceptance=true`, and requires the Wayland HID receipt to name the RemoteDesktop/EIS portal with explicit consent and physical-input proof. It does not create compositor sessions or bypass portal consent. Its smoke receipt is `release_operations_acceptance_intake_smoke compositors=6 wayland_hid=true semantic=true placeholder_blocked=true compositor_mismatch_blocked=true consent_required=true complete_status=true scratch_clean=true`. A complete retained-evidence fixture can then report `tagged_artifacts=true signatures=true publication=true dependency_bundle_redistribution=true compositor_acceptance=true wayland_hid_consent=true complete=true external_blockers=0`.

## Evidence Directory

By default the checker reads `release/evidence/0.1.0`. Override it with `DEETTY_RELEASE_EVIDENCE_DIR` when validating retained evidence outside the checkout.

Required files for `tagged_artifacts=true`:

- `deetty-linux-x86_64.tar.gz`
- `deetty-linux-x86_64.tar.gz.sha256`
- `deetty-linux-x86_64.tar.gz.manifest`
- `deetty-linux-aarch64.tar.gz`
- `deetty-linux-aarch64.tar.gz.sha256`
- `deetty-linux-aarch64.tar.gz.manifest`

The checker runs `sha256sum -c` for both retained architecture artifacts before marking the row true.

Each retained `.manifest` must also include:

- `bundle_manifest_version=1`
- `architecture=<matching architecture>`
- `archive_sha256=<digest from the matching .sha256 sidecar>`
- `installed_files_begin`
- `library_inventory_begin`

If the sidecar and manifest disagree, the checker emits `manifest_digest_mismatch`; if a required receipt field is absent, it emits `receipt_field_missing`.

Required files for `signatures=true`:

- `deetty-linux-x86_64.tar.gz.sig`
- `deetty-linux-aarch64.tar.gz.sig`
- `deetty-linux-x86_64.tar.gz.sha256.sig`
- `deetty-linux-aarch64.tar.gz.sha256.sig`
- `deetty-linux-x86_64.tar.gz.manifest.sig`
- `deetty-linux-aarch64.tar.gz.manifest.sig`

Use `./scripts/release_operations_signature_intake.sh` for these files so each signature is tied to an already retained canonical target. The local checker rejects placeholder signature text but intentionally does not claim cryptographic key verification.

Required file for `publication=true`:

- `publication-receipt.txt`

The publication receipt must include `version=0.1.0`, `tag=v0.1.0`, `artifacts_published=true`, `checksums_published=true`, `signatures_published=true`, and `release_notes_published=true`.

Publication is only accepted after retained tagged artifacts and signatures are true. If those prerequisites are absent, the checker emits `publication_prerequisites_missing`.

Required file for `dependency_bundle_redistribution=true`:

- `dependency-bundle-redistribution-notices.md`

That notice file must not contain `TODO`, `TBD`, `unresolved`, or `missing`. The exact reviewed bundle manifest must report `redistribution_ready=true`, `all_copied_host_libraries_accounted=true`, and `bundle_license_payload_complete=true`; receipt intake requires the corresponding `bundle_manifest_redistribution_ready=true` and `bundle_license_payload_complete=true` attestations. The generated manifest/payload is necessary evidence, not a substitute for independent review or a retained release receipt.

The redistribution notice must also include `all_copied_host_libraries_accounted=true` and `redistribution_notices_complete=true`.

Use `./scripts/release_operations_receipt_intake.sh` for publication and redistribution receipts so placeholder and incomplete files are rejected before they are copied into the canonical evidence directory.

Required files for `compositor_acceptance=true`:

- `compositors/niri.txt`
- `compositors/hyprland.txt`
- `compositors/sway.txt`
- `compositors/scroll.txt`
- `compositors/labwc.txt`
- `compositors/mango.txt`

Each compositor receipt must include `version=0.1.0`, `compositor=<name>`, `native_release_smoke=true`, and `operator_acceptance=true`.

Use `./scripts/release_operations_acceptance_intake.sh compositor <name>` for these files so compositor mismatches and placeholder receipts are rejected before retention.

Required file for `wayland_hid_consent=true`:

- `wayland-hid-consent-receipt.txt`

The Wayland HID receipt must come from an explicitly consented RemoteDesktop/EIS portal session. DEETTY must never bypass compositor consent or treat a read-only capability probe as physical-input proof.

The HID receipt must include `version=0.1.0`, `portal=RemoteDesktop/EIS`, `explicit_user_consent=true`, and `physical_input_receipt=true`.

Use `./scripts/release_operations_acceptance_intake.sh wayland-hid` for this file so missing explicit consent is rejected before retention.

All receipt-like files are rejected if they contain placeholder language such as `TODO`, `TBD`, `unresolved`, `missing`, `placeholder`, `dummy`, or `retained evidence`.
