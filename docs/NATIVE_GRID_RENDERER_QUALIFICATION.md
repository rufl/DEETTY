# Native Grid Renderer Qualification

Status: bounded NCT-119 synthetic production-Cairo draw, pixel-repeat, and renderer-owned allocation tranche passed on 2026-07-18. The complementary real-PTY pipeline tranche is now retained separately; GTK widget/frame-clock/compositor latency remains open.

## Qualified Boundary

`scripts/native_grid_renderer_qualification.sh` builds only the native smoke binary in Debug and `ReleaseSafe`, then calls the exact production `draw_grid_contents` path against Cairo ARGB image surfaces without requiring a compositor. Each mode renders three 160×50 terminal fixtures:

- an idle blank grid;
- a full-screen ASCII/color grid; and
- a rich-style grid with grapheme fallback, cursor, selection, bold, inverse, underline, italic, dim, and strike paths.

After one warm-up draw, each fixture records 128 process-CPU samples and draws one independent comparison surface. The runner requires zero changed pixels between repeated surfaces, byte-identical Debug/`ReleaseSafe` PNGs, and matching 64-bit surface hashes. The three PNGs are generated only inside self-cleaning qualification scratch; this receipt retains their SHA-256 fingerprints rather than claiming release-artifact retention.

The allocation counters cover renderer-owned packed-row storage, glyph scratch, and glyph-cache construction. They deliberately do not claim visibility into Cairo, Pango, fontconfig, GLib, or allocator-internal work. The resize probe draws 80×24, grows to 160×50, and shrinks to 80×24; growth must be bounded and shrink must reuse the retained renderer scratch.

## Retained Result

| Mode | Fixture | p50 process CPU | p95 process CPU | p99 process CPU |
| --- | ---: | ---: | ---: | ---: |
| Debug | idle | 0.262 ms | 0.296 ms | 0.415 ms |
| Debug | full-screen | 3.477 ms | 3.653 ms | 3.744 ms |
| Debug | rich style | 4.010 ms | 4.184 ms | 4.626 ms |
| ReleaseSafe | idle | 0.142 ms | 0.163 ms | 0.208 ms |
| ReleaseSafe | full-screen | 2.767 ms | 3.054 ms | 3.149 ms |
| ReleaseSafe | rich style | 3.262 ms | 3.333 ms | 3.357 ms |

Across both modes, each run measured 384 frames. All repeated-surface comparisons reported `pixel_diff=0`; Debug and `ReleaseSafe` reported the same fixture hashes. The combined renderer-owned counts were 15 first-frame allocations, zero allocations across all 384 warm measured frames, one growth allocation, zero shrink allocations, and a 4352-byte peak for the counted row/glyph scratch. These are observed one-host values, not release thresholds.

| Mode | Peak root PSS | Peak root RSS | Samples |
| --- | ---: | ---: | ---: |
| Debug | 27,189 KiB | 48,436 KiB | 79 |
| ReleaseSafe | 21,087 KiB | 42,328 KiB | 66 |

PNG fingerprints:

- idle: `cf4d7cc8b3b474c474b28c1b37340e3f6223ad0159afb92b4a94bf31f1403e37`
- full-screen: `7ee1ee2c1c52478e9b196edd580cab3bb2b6ebecc6b7af67508c820d54554abf`
- rich style: `f53d9bfffd21dbc7118c08729ebdf9ccb58ef7c0914f0bc567c026b32294f190`

The stable acceptance contract is:

```text
native_grid_renderer_qualification_matrix debug=true release_safe=true frames_per_scenario=128 scenarios=3 pixel_repeat_exact=true cross_mode_artifacts_identical=true idle_draw_cpu=true fullscreen_draw_cpu=true rich_style_draw_cpu=true owned_allocation_counts=true warm_frame_owned_allocations=0 resize_growth_bounded=true resize_shrink_allocations=0 process_memory=true scratch_clean=true
```

## Proof Boundary

This advances NCT-119's display-independent production renderer boundary. It proves deterministic repeated output for the three fixed fixtures, host-local process-CPU distributions, and bounded renderer-owned warm/resize allocations through the exact Cairo draw function.

This synthetic lane does not initialize GTK, map a native surface, exercise a compositor or frame clock, measure Cairo/Pango/library allocations, archive release pixel artifacts, or measure PTY-read-to-draw, key-write-to-draw, frame intervals, idle wakeups, fullscreen-window behavior, GPU work, or real agent-TUI presentation. The complementary [terminal pipeline qualification](TERMINAL_PIPELINE_QUALIFICATION.md) now feeds the same draw function from a real shell/PTY/VT and retains display-independent input-write/PTY-read-start-to-Cairo distributions. NCT-119 remains partial for mapped GTK key/frame-clock/compositor evidence, full-stack allocations, idle wakeups, and archived compositor-backed pixels on Plasma Wayland and X11.

## Reproduce

```sh
./scripts/native_grid_renderer_qualification.sh
```

The script owns and removes its build caches, XDG cache, temporary files, installed smoke binary, and PNG surfaces.
