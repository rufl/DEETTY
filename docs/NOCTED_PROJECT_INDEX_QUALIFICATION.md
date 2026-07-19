# NoctEd Project-Index Qualification

Retained on 2026-07-18 with Zig 0.16.0 on Linux 7.1.3-arch2-1 x86_64, using a 16-vCPU `Genuine Intel(R) 0000` host. The checkout did not expose repository revision metadata, so this receipt is tied to the documented source state and date rather than a commit identifier.

## Method

`./scripts/nocted_project_index_qualification.sh` builds an isolated Debug and `ReleaseSafe` runner, creates real disposable 4K, 25K, and 100K-entry projects, and measures a complete immutable scan followed by five coalesced structural events. The delta deletes two files, replaces an existing destination through a file rename, renames a directory containing about 1000 entries, and admits a new two-level directory plus file. Only the changed paths/subtree are read; the unchanged worktree is rebuilt from the retained immutable index rather than rescanned from disk.

Every mode/scale verifies exact final entry count and path state, directory rename, replacement-conflict resolution to current disk state, `.ignore` full-scan fallback, 257-event overflow fallback, two simultaneously retained immutable snapshots, allocator cleanup, root-process PSS/RSS sampling, and complete disposable-fixture cleanup.

Stable matrix receipt:

```text
nocted_project_index_matrix debug=true release_safe=true scales=4000,25000,100000 immutable_delta=true directory_rename=true replacement_conflict=true ignore_fallback=true overflow_fallback=true scan_time=true delta_time=true index_memory=true two_snapshot_peak=true process_memory=true allocator_leak_free=true scratch_clean=true
```

## Retained Results

Times are monotonic-clock nanoseconds. Index bytes are the exact compact arena, entry, relationship, root, and storage bytes reported by the model. PSS/RSS are sampled observations of the verification process, not thresholds.

| Mode | Entries | Full scan ns | Delta ns | Index bytes | Two-snapshot bytes | Peak PSS KiB | Peak RSS KiB |
|---|---:|---:|---:|---:|---:|---:|---:|
| Debug | 4,000 | 21,184,600 | 79,974,307 | 283,981 | 563,989 | 4,144 | 4,324 |
| Debug | 25,000 | 115,291,701 | 353,597,110 | 1,753,645 | 3,503,317 | 13,736 | 13,744 |
| Debug | 100,000 | 529,303,557 | 1,426,676,874 | 7,002,445 | 14,000,917 | 39,104 | 39,112 |
| ReleaseSafe | 4,000 | 3,257,183 | 3,725,115 | 283,981 | 563,989 | 1,296 | 2,196 |
| ReleaseSafe | 25,000 | 17,562,970 | 35,448,418 | 1,753,645 | 3,503,317 | 6,972 | 6,980 |
| ReleaseSafe | 100,000 | 69,769,667 | 69,751,009 | 7,002,445 | 14,000,917 | 24,460 | 24,468 |

Each case applied five events and reported `delta_added=1003 delta_removed=1003`; the directory rename accounts for most of those entries. DebugAllocator requested bytes returned to zero and its leak check passed in every process.

The warning-fatal standalone native workflow separately retained the live worker/publication seam on X11:

```text
nocted_native_smoke_diagnostic pass=1 project_delta_updates=1 project_delta_fallbacks=0 project_delta_added=3 project_delta_removed=2 worker_lanes=2
```

## Proof Boundary

This closes the deterministic synthetic 4K/25K/100K index-size, full-scan, immutable-delta, directory-rename, replacement-conflict, ignore/overflow fallback, two-snapshot model-memory, allocator teardown, and root-process memory tranche. The complementary [native project-lifecycle qualification](NOCTED_PROJECT_LIFECYCLE_QUALIFICATION.md) now retains bounded current-project model/tree-draw, actual monitor-burst/UI publication, deterministic overflow recovery, and post-widget callback proof on X11 and Wayland. NCT-121 remains partial only for sustained long-duration cross-backend lifecycle evidence. NCT-122 search/cancellation/open-save distributions are separate.
