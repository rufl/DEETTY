# Public Alpha Code Review

Review date: 2026-09-06. Scope: DEETTY and NoctEd source behavior, native
usability, contributor setup, and MIT source distribution. This supersedes the
2026-08-31 assessment; it is not a formal security audit or release approval.

## Decision

The exercised terminal and editor paths are real native implementations, not a
scaffold. However, the audit found data-loss, memory-ownership, authorization,
and misleading-success defects despite earlier green smoke receipts. The old
blanket readiness assessment was too generous.

The corrections below are implemented. Their evidence is deliberately separated
from untested scenarios and publication gates. Source can be reviewed and built;
a public-ready or daily-driver-qualified announcement is still not justified.
Language percentages and accumulated test counts are not quality certificates.

## Corrected findings

| Priority | Finding | Correction and source boundary |
|---|---|---|
| P1 | NoctEd could overwrite external disk changes, including after dirty-session restore. | `src/nocted/Document.zig` retains an original file identity and checks it before atomic replacement. GTK restore treats dirty snapshots as having an unknown disk baseline; Save As is required. |
| P1 | A close-time save could discard edits made while the worker pumped GTK events; delayed reloads could replace newer text. | `src/nocted/main.zig` checks the post-save modified state and binds reload results to the document change serial. Worker admission has one owner for each payload. |
| P1 | Delayed language-service edits used the active tab, could dereference a closed document, and could partially mutate a workspace rename. | Request-time open-buffer snapshots bind identity, generation, text, and disk state to the request. Every rename target is validated before mutation. Closed, changed, and unsnapshotted targets reject the result visibly. |
| P1 | Failed autosave could remain pending forever; allocation failures could lose the closed-tab recovery snapshot or dirty generation. | `src/app/App.zig`, `src/workspace/Workspace.zig`, and `Storage.zig` clear failed maintenance work for a later cadence and commit ownership/state only after fallible preparation succeeds. |
| P1 | Sharing queue backpressure double-freed an encoded frame; a hostile split-chain manifest could exhaust traversal storage. | `src/share/LiveHost.zig` has one frame owner on rejection; `Session.zig` bounds pending traversal pushes. |
| P1 | Control approval could outlive its requesting connection; a modal dialog could use a retired host; invalid host trust did not reliably discard queued input. | Control requests carry a request epoch. GTK/Win32 revalidate the host after modal message pumping, and host trust invalidation cancels queued input and cannot revive the same grant. |
| P1 | Per-read timeouts let a peer extend a sharing transaction indefinitely by trickling bytes. | `src/share/Transport.zig` and `Net.zig` enforce one absolute five-second budget per handshake or encrypted frame, including partial reads/writes. This bounds the transaction, not an instantaneous disconnect guarantee. |
| P1 | Windows NoctEd could display the previous small document as editable under a newly selected oversized document's name. | `src/windows/NoctedHost.zig` replaces the displayed content, enforces read-only previews, disables Save/Save As and undo mutation where appropriate, and restores the small document on tab return. |
| P2 | Recovery maintenance reported a fabricated empty cleanup receipt without doing cleanup. | The native event path now invokes the existing bounded storage cleanup operation and reports its real result or error. |
| P2 | RIS retained terminal modes/buffer state; UTF-8 OSC continuations could be confused with string terminators. | `src/terminal/Vt.zig` and `VtParser.zig` reset the actual terminal state and track UTF-8 sequence boundaries in OSC strings. |
| P2 | Windows shell selection dropped the final character of command candidates such as `cmd.exe`. | `WindowsPtyLogic.zig`, `WindowsPty.zig`, and `WindowsProcess.zig` preserve full sentinel-terminated commands, including arguments and fallback order. |
| P2 | Painting the continuation-cell background erased the right half of a wide glyph. | Both Windows local-grid and pane rendering paint continuation backgrounds before the leading glyph. An offscreen GDI pixel regression covers the overlap. |
| P2 | Linux help/unknown options silently launched a GUI or forwarded to an existing editor; help could create dogfood receipts. | Entrypoints validate options before GUI/IPC activation. `scripts/cli_smoke.sh` exercises help/version/errors without a reachable display or mutable user state. Launchers bypass receipts for help/version. |
| P2 | First-party source packaging omitted required build inputs; binary installs omitted compiled third-party license texts. | `build.zig.zon` includes required source/resource/package inputs. Linux installs include vendored parser and Unicode notices; Windows ZIP/NSIS payload contracts include Unicode licensing. Arch/RPM packaging preserves the installed license tree. DEETTY remains MIT; third-party works retain their own licenses. |
| P2 | Contributor quick starts implied maintainer infrastructure was required; failed Git inventory could pass source hygiene. | README, contributing/install instructions, and code map now distinguish normal builds from qualification. The hygiene gate fails closed on Git inventory failure. Windows documentation describes its actual `.npr` project contract. |

## Verification performed

### Focused behavior checks

Passed the focused regression groups for:

- checked saves: changed, missing, unknown, and newly created destinations;
- maintenance/autosave and closed-tab recovery under allocation failure;
- sharing backpressure ownership, split-chain traversal, host trust invalidation,
  and connection-scoped input; ordinary loopback pairing and trickled-input
  transaction expiry;
- terminal RIS and UTF-8 OSC boundary behavior;
- complete Windows shell command profiles and fallback order.

Linux libc-linked direct tests used `-target x86_64-linux-gnu -mcpu baseline`.
The host-native invocation encountered a Zig/GCC relocation error before any
behavior test ran; the explicit baseline-target runs passed.

### Actual native surfaces

All display work ran in the reviewed `overzeer-isolated-display` private
namespace with Xvfb/KWin, bounded timeouts, serialization, and process-tree
cleanup. No active developer desktop or physical monitor was used.

Passed (Linux screenshots visually inspected; Windows checks automated):

- terminal input, creating a second tab, and resizing to 520 by 420;
- editor typing and saving, including a 640 by 480 window;
- refusal to overwrite an external file change;
- hot exit and dirty restore followed by another external disk change: the
  restored text remained available and Save preserved the external bytes;
- 33-file admission without crashing the native editor;
- a delayed formatter response while another tab was selected: the original
  document received the edit, not the active tab;
- rejection of delayed formatting after a newer local edit or after all source
  tabs closed, with visible feedback and no crash;
- isolated Wine offscreen GDI wide-glyph regression and mapped Win32 NoctEd
  editable/preview/unavailable transitions, including rejected saves and return
  to the original editable document.

The delayed-language smoke used a local protocol fixture only as the server;
real NoctEd menus, tabs, edits, saves, and close actions were exercised. This is
not compatibility qualification for a production language server. Multi-file
rename's snapshot restriction is documented, not a claim of arbitrary workspace
rename parity.

The Wine bootstrap first timed out before the test executable ran. A subsequent
bounded direct launch in that disposable prefix passed both Windows checks.
Wine is not physical Windows qualification. Fixture screenshots were inspected,
not promoted as release screenshots.

### Source and contributor boundary

- The actual Zig-fetched source archive built both applications and installed
  their resources successfully: **38/38 steps**. This build used no Git checkout
  metadata and no external display-test runner.
- Ten Linux installed license payloads matched their source files byte-for-byte.
- The Windows `ReleaseFast` ZIP and per-user NSIS installer built successfully.
  The isolated installer lifecycle passed silent install/uninstall, reversible
  shortcuts/Open-With registration, preservation of user/unrelated files, and
  byte-exact installed Unicode licensing.
- CLI and dogfood logging checks passed, including help/version receipt bypass.
- Source hygiene rejected an archive without Git inventory instead of reporting
  a clean tree. That gate intentionally applies to a checkout; the source build
  itself does not require Git.
- Native ownership, documentation-truth, and no-surprise-network source guards
  passed. The network guard is a static scan, not proof of absence of every
  possible network behavior.
- The release workflow now provisions the repository-owned private X11 runner
  and virtual-capable KWin, then runs the bounded source-alpha gate rather than
  invoking the environment-heavy maintainer matrix without its prerequisites.

No repository-wide graphical matrix, physical Windows run, long-duration
stability run, signing, publication, or redistribution approval was performed
by this audit.

## Remaining publication and maintenance risks

1. **Current-build acceptance is incomplete.** Seven operator-confirmed
   installed sessions contribute 167.107 counted hours, so the minimum
   session-count and agent-use baselines are met. NCT-125 remains open because
   the retained candidates predate the final source state or contain the
   historical exit-139, popup, or GTK-critical observations; four-pane,
   close-protection, and multi-OMP evidence also remain incomplete.
2. **Windows and release operations remain separate gates.** Physical Windows
   input/ConPTY/installer behavior, signing, retained architecture artifacts,
   dependency-bundle redistribution review, compositor acceptance, and consented
   HID proof remain open. See [known limitations](KNOWN_LIMITATIONS.md).
3. **External-write safety is conservative, not a filesystem lock.** Identity
   checks narrow races but cannot coordinate an uncooperative external writer
   across the final check/rename interval. Unknown restored baselines and
   unsnapshotted rename targets are explicitly rejected, not guessed.
4. **Large modules remain a maintenance cost.** `src/main.zig`,
   `src/nocted/main.zig`, and the remaining GTK C adapter still combine multiple
   lifecycle concerns. Future extraction should follow behavior and ownership
   boundaries, not a Zig-percentage target or another abstraction layer.
5. **Usability proof remains narrow.** Native normal/narrow-window operation,
   current isolated publication captures, and sustained installed terminal use
   are demonstrated; screen-reader completeness, varied high-contrast themes,
   high-DPI/platform coverage, and sustained varied-project editor work are not
   established by this pass.

## Contributor entry point

Follow [CONTRIBUTING.md](../CONTRIBUTING.md) and
[the install guide](INSTALL.md). A normal source trial is:

```sh
zig build -j1
./zig-out/bin/deetty --native-grid-windowed
./zig-out/bin/nocted --open README.md
```

Those last two commands are ordinary interactive application launches on the
user's chosen desktop, not graphical tests. Automated display checks must stay
inside the reviewed isolated environment. Do not require contributors to run the
maintainer matrix merely to build or try the applications.
