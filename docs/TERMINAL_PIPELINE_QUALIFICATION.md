# Terminal Pipeline Qualification

Status: bounded NCT-112/NCT-119 real-PTY-to-production-Cairo tranche passed on 2026-07-18. A separate live mapped GTK presentation tranche is now retained.

## Qualified Boundary

`scripts/native_grid_pipeline_qualification.sh` builds the verification-only native binary in Debug and `ReleaseSafe`. Each run starts `/bin/sh` through the production `TerminalSession`, clears the interactive prompt and waits for an explicit clear/title readiness marker, writes 64 distinct rich-output commands through the real PTY, drains each response through the bounded PTY pump and production VT grid until its final OSC title marker is visible, then calls the exact production `draw_grid_contents` Cairo path through the ABI-v2 row/cell callbacks. The same renderer context and Cairo image surface are retained across all 64 samples.

For every sample, the lane records two display-independent wall-clock intervals:

- input-write start through PTY output, VT mutation, and completed Cairo draw; and
- first PTY-read attempt through VT mutation and completed Cairo draw.

It also records draw process CPU, output bytes, renderer-owned allocations, root/process-tree PSS and RSS, and the final surface hash. Every mode runs the 64-sample sequence twice. The final PNG must be exact across repeats and byte-identical between Debug and `ReleaseSafe`; it exists only in the trap-cleaned scratch directory.

## Retained Result

The 2026-07-18 retained run ingested 191,646 PTY bytes across 64 measured
updates at 120×40. The current readiness handshake deliberately removes prompt
bytes from the measured region; its local regression runs ingest 190,912 bytes.
The stable contract checks positive output and deterministic pixels rather than
pinning either historical byte count.

| Mode | Input write→draw p50 / p95 / p99 | PTY-read start→draw p50 / p95 / p99 | Draw CPU p50 / p95 / p99 |
| --- | ---: | ---: | ---: |
| Debug | 3.748 / 5.278 / 12.373 ms | 3.745 / 5.272 / 12.364 ms | 0.587 / 0.783 / 7.990 ms |
| ReleaseSafe | 1.510 / 1.796 / 11.186 ms | 1.506 / 1.794 / 11.180 ms | 0.341 / 0.419 / 8.930 ms |

The shared final surface hash was `5096774441444124007`; repeated and cross-mode PNGs were byte-identical with SHA-256 `6ffcf3f95517772167cb41074a4af7afdc82aa2ec9edd621ff85fd90500c55fc`. Both modes reported three first-frame renderer-owned allocations, zero allocations across the remaining 63 warm frames, and 4032 peak counted row/glyph scratch bytes.

| Mode | Peak root PSS | Peak root RSS | Peak process-tree PSS | Peak process-tree RSS | Samples |
| --- | ---: | ---: | ---: | ---: | ---: |
| Debug | 19,662 KiB | 40,108 KiB | 20,659 KiB | 47,448 KiB | 40 |
| ReleaseSafe | 13,677 KiB | 34,412 KiB | 14,680 KiB | 41,344 KiB | 21 |

These are one-host observations, not release thresholds. The stable contract is:

```text
native_grid_pipeline_matrix debug=true release_safe=true samples_per_run=64 runs_per_mode=2 production_pty=true production_vt=true production_cairo=true input_write_to_draw=true pty_read_to_draw=true latency_percentiles=true artifact_repeat_exact=true cross_mode_artifacts_identical=true warm_frame_owned_allocations=0 root_memory_separate=true process_tree_memory=true compositor_presented=false scratch_clean=true
```

## Proof Boundary

This closes the display-independent PTY/input-to-production-Cairo measurement gap. Unlike the synthetic renderer qualification, it feeds the renderer from real shell output transported through the production PTY, `TerminalSession`, VT model, packed-row ABI, and Cairo draw implementation. It also keeps terminal root memory separate from the live shell process tree.

The input is programmatically written at the terminal-session boundary; it is not a GTK key event. `PTY-read start` begins immediately before the first bounded pump attempt, not at kernel byte arrival. The final timestamp is completion of a Cairo image-surface draw, not a mapped GTK widget, frame-clock callback, compositor presentation, or visible photon. Renderer-owned counters still exclude Cairo, Pango, fontconfig, GLib, and allocator-internal allocations. The later [mapped presentation qualification](NATIVE_GRID_PRESENTATION_QUALIFICATION.md) adds direct synthetic production key-handler-to-draw/after-paint distributions and completed Wayland GDK presentation timestamps; the [full-stack qualification](NATIVE_GRID_FULL_STACK_QUALIFICATION.md) adds live idle/fullscreen pixels, memory, and wakeups and closes NCT-119. The authenticated Codex mapped companion now covers one exact model response per mode/backend. The [stability qualification](NATIVE_GRID_STABILITY_QUALIFICATION.md) passes its short hidden/visible matrix; NCT-112 remains partial for the elapsed 48-hour Wayland/X11 evidence.

## Reproduce

```sh
./scripts/native_grid_pipeline_qualification.sh
```

The runner isolates and removes its Zig local/global caches, prefix, XDG cache, temporary files, PTY fixture state, outputs, and PNG artifacts.
