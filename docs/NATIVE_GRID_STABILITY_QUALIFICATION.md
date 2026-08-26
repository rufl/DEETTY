# Native grid stability qualification

Status: the four-lane cross-backend harness shakedown and a separate short authenticated `ReleaseSafe` Wayland/X11 shakedown passed on 2026-08-05. The default 48-hour authenticated run has not elapsed, so NCT-112 remains partial.

## Boundary

`scripts/native_grid_stability_qualification.sh` exercises smoke-only host mode 40 around the production command-profile, PTY, `TerminalSession`, VT/grid, GTK, and Cairo path. It alternates one live window between mapped visible and fully unmapped hidden phases while a bounded terminal workload continues producing output.

The host records:

- exact visible/hidden cycle completion and wall duration;
- mapped-visible and unmapped-hidden state;
- draw and presentation counts by phase;
- root-coalesced cursor and maintenance wakeups by phase;
- zero fallback PTY timer ticks;
- zero draws after the hidden phase is established;
- controlled terminal exit and host teardown.

The outer script samples root and process-tree PSS/RSS, process CPU ticks, voluntary and involuntary context switches, and initial/final compositor screenshots. It fails if final root PSS exceeds the first sample by more than the configurable 64 MiB host-local guardrail. That guard catches runaway growth; it is not a universal memory budget.

## Commands

Fast harness check:

```sh
NOCTTY_DEDICATED_DISPLAY=1 ./scripts/native_grid_stability_qualification.sh --smoke
```

This runs two two-second visible/hidden cycles in Debug and `ReleaseSafe` inside dedicated Plasma Wayland and X11 sessions. Retained shakedown evidence lives under `benchmarks/native-grid-stability-shakedown-2026-08-05/`.

The authenticated path was also checked with one two-second visible/hidden cycle per `ReleaseSafe` backend. Both exact ephemeral read-only responses were `NOCTTY_STABILITY_CODEX_OK`; root PSS changed by +28 KiB in each short lane. Those receipts live under `benchmarks/native-grid-stability-auth-shakedown-2026-08-05/` and still report `multi_day=false`.

Elapsed acceptance run:

```sh
NOCTTY_DEDICATED_DISPLAY=1 ./scripts/native_grid_stability_qualification.sh --run
```

The default run performs 24 cycles per backend with 1,800 seconds visible and 1,800 seconds hidden per cycle. It therefore retains 24 hours on Wayland plus 24 hours on X11, 48 hours total, in `ReleaseSafe`. Each backend begins with one exact authenticated Codex ephemeral read-only request, then continues a deterministic heartbeat without retaining credentials. The run samples every phase and captures the first and final visible compositor surfaces.

The duration can be widened, but shortening it produces bounded stability evidence rather than the `multi_day=true` receipt:

```sh
NOCTTY_DEDICATED_DISPLAY=1 \
NOCTTY_STABILITY_CYCLES=48 \
NOCTTY_STABILITY_PHASE_SECONDS=1800 \
./scripts/native_grid_stability_qualification.sh --run
```

## Shakedown result

All four short lanes passed with two hidden/visible cycles, visible and hidden output presentation, zero hidden draws, zero fallback PTY ticks, positive cursor/maintenance receipts, compositor pixels, external resource samples, and zero child exit. First-to-final root PSS changed by +5,408 KiB Debug Wayland, +100 KiB Debug X11, +5,328 KiB `ReleaseSafe` Wayland, and +12 KiB `ReleaseSafe` X11.

Stable shakedown contract:

```text
native_grid_stability_matrix smoke=true release_safe=true debug=true wayland=true x11=true cycles_per_lane=2 phase_seconds=2 expected_lane_seconds=8 authenticated_codex=false hidden_visible=true production_pty=true production_vt=true production_gtk=true production_cairo=true mapped_memory=true process_tree_memory=true scheduler_receipts=true compositor_pixels=true root_growth_guard_kib=65536 multi_day=false hid=false checksums=true scratch_clean=true
```

## Honest exclusions

The shakedown is not multi-day proof, sustained model activity, physical input, final compositor acceptance, or cross-host evidence. The elapsed run uses one exact authenticated Codex request per backend and then terminal output heartbeats; it does not repeatedly spend model requests merely to keep the terminal busy. NCT-112 closes only after the retained 48-hour matrix completes with ordered logs, screenshots, resource samples, checksums, and `multi_day=true`.
