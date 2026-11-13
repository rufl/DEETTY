const std = @import("std");
const builtin = @import("builtin");
const core = @import("nocted_core");

const max_cycles: usize = 512;
const default_cycles: usize = 128;
const AccountedAllocator = std.heap.DebugAllocator(.{
    .enable_memory_limit = true,
});

const document_even =
    \\fn stabilityCycle() void {
    \\    const stability_needle = "even";
    \\    _ = stability_needle;
    \\}
    \\stability_needle stability_needle
;
const document_odd =
    \\fn stabilityCycle() void {
    \\    const stability_needle = "odd";
    \\    _ = stability_needle;
    \\}
    \\stability_needle stability_needle
;
const grammar_source =
    \\{
    \\  "name": "DINTTY Stability",
    \\  "scopeName": "source.dintty-stability",
    \\  "fileTypes": ["zig"],
    \\  "patterns": [
    \\    { "match": "\\b(stability_needle)\\b", "name": "variable.other" },
    \\    { "begin": "\\\"", "end": "\\\"", "name": "string.quoted.double" }
    \\  ]
    \\}
;

const Samples = struct {
    save: [max_cycles]u64 = undefined,
    load: [max_cycles]u64 = undefined,
    edit: [max_cycles]u64 = undefined,
    scan: [max_cycles]u64 = undefined,
    search: [max_cycles]u64 = undefined,
    quick_open: [max_cycles]u64 = undefined,
    grammar: [max_cycles]u64 = undefined,
};

const Summary = struct {
    p50_ns: u64,
    p95_ns: u64,
    p99_ns: u64,
};

const Outcome = struct {
    samples: Samples,
    project_entries: usize,
    search_results: usize,
    checkpoint_peak_active_bytes: usize,
    ranking_fingerprint: u64,
};

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len < 2 or args.len > 3) return error.InvalidArguments;
    const cycles = if (args.len == 3)
        try std.fmt.parseInt(usize, args[2], 10)
    else
        default_cycles;
    if (cycles == 0 or cycles > max_cycles) return error.InvalidCycleCount;

    var debug_allocator: AccountedAllocator = .init;
    var outcome = runQualification(&debug_allocator, init.io, args[1], cycles) catch |err| {
        _ = debug_allocator.deinit();
        return err;
    };
    const residual_bytes = debug_allocator.total_requested_bytes;
    const leak_check = debug_allocator.deinit();
    if (residual_bytes != 0 or leak_check != .ok)
        return error.AllocatorAccountingFailed;

    var stdout_buffer: [8192]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), init.io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    const save = summarize(outcome.samples.save[0..cycles]);
    const load = summarize(outcome.samples.load[0..cycles]);
    const edit = summarize(outcome.samples.edit[0..cycles]);
    const scan = summarize(outcome.samples.scan[0..cycles]);
    const search = summarize(outcome.samples.search[0..cycles]);
    const quick_open = summarize(outcome.samples.quick_open[0..cycles]);
    const grammar = summarize(outcome.samples.grammar[0..cycles]);
    try stdout.print(
        "nocted_core_stability mode={s} cycles={d} project_entries={d} search_results={d} " ++
            "allocator_leak_free=true allocator_residual_bytes={d} checkpoint_peak_active_bytes={d} " ++
            "save_p50_ns={d} save_p95_ns={d} save_p99_ns={d} " ++
            "load_p50_ns={d} load_p95_ns={d} load_p99_ns={d} " ++
            "edit_p50_ns={d} edit_p95_ns={d} edit_p99_ns={d} " ++
            "scan_p50_ns={d} scan_p95_ns={d} scan_p99_ns={d} " ++
            "search_p50_ns={d} search_p95_ns={d} search_p99_ns={d} " ++
            "quick_open_p50_ns={d} quick_open_p95_ns={d} quick_open_p99_ns={d} " ++
            "ranking_queries=3 ranking_cycles={d} ranking_fingerprint={d} " ++
            "ranking_deterministic=true " ++
            "grammar_p50_ns={d} grammar_p95_ns={d} grammar_p99_ns={d} assertions=true\n",
        .{
            @tagName(builtin.mode),
            cycles,
            outcome.project_entries,
            outcome.search_results,
            residual_bytes,
            outcome.checkpoint_peak_active_bytes,
            save.p50_ns,
            save.p95_ns,
            save.p99_ns,
            load.p50_ns,
            load.p95_ns,
            load.p99_ns,
            edit.p50_ns,
            edit.p95_ns,
            edit.p99_ns,
            scan.p50_ns,
            scan.p95_ns,
            scan.p99_ns,
            search.p50_ns,
            search.p95_ns,
            search.p99_ns,
            quick_open.p50_ns,
            quick_open.p95_ns,
            quick_open.p99_ns,
            cycles,
            outcome.ranking_fingerprint,
            grammar.p50_ns,
            grammar.p95_ns,
            grammar.p99_ns,
        },
    );
}

fn runQualification(
    accounting: *AccountedAllocator,
    io: std.Io,
    project_root: []const u8,
    cycles: usize,
) !Outcome {
    const allocator = accounting.allocator();
    const document_path = try std.fs.path.join(allocator, &.{ project_root, "focus.zig" });
    defer allocator.free(document_path);
    const cycle_baseline_bytes = accounting.total_requested_bytes;

    var outcome = Outcome{
        .samples = .{},
        .project_entries = 0,
        .search_results = 0,
        .checkpoint_peak_active_bytes = 0,
        .ranking_fingerprint = 0,
    };
    for (0..cycles) |cycle| {
        const contents = if (cycle % 2 == 0) document_even else document_odd;

        var started = std.Io.Clock.awake.now(io);
        try core.document.saveFileAtomic(io, document_path, contents);
        outcome.samples.save[cycle] = elapsedNanoseconds(started, io);

        {
            started = std.Io.Clock.awake.now(io);
            var loaded = try core.document.loadFileAlloc(allocator, io, document_path);
            defer loaded.deinit(allocator);
            outcome.samples.load[cycle] = elapsedNanoseconds(started, io);
            if (!std.mem.eql(u8, loaded.contents, contents) or loaded.mode != .editable)
                return error.DocumentRoundTripMismatch;
            recordPeak(&outcome, accounting);

            started = std.Io.Clock.awake.now(io);
            var selections = try core.multi_selection.findAllAlloc(
                allocator,
                loaded.contents,
                "stability_needle",
            );
            defer selections.deinit(allocator);
            if (selections.ranges.len != 4 or selections.truncated)
                return error.MultiSelectionMismatch;
            const edited = try core.multi_selection.replaceAlloc(
                allocator,
                loaded.contents,
                selections.ranges,
                "stable_signal",
            );
            defer allocator.free(edited);
            if (std.mem.indexOf(u8, edited, "stability_needle") != null or
                std.mem.indexOf(u8, edited, "stable_signal") == null)
                return error.EditMismatch;
            var folding = try core.folding.analyzeAlloc(allocator, loaded.contents, 4);
            defer folding.deinit();
            if (folding.regions.items.len == 0 or folding.truncated)
                return error.FoldingMismatch;
            outcome.samples.edit[cycle] = elapsedNanoseconds(started, io);
            recordPeak(&outcome, accounting);
        }

        {
            started = std.Io.Clock.awake.now(io);
            var index = try core.project_index.scanAlloc(allocator, io, project_root);
            defer index.deinit(allocator);
            outcome.samples.scan[cycle] = elapsedNanoseconds(started, io);
            if (index.entries.len < 129 or index.truncated)
                return error.ProjectFixtureMismatch;
            outcome.project_entries = index.entries.len;
            recordPeak(&outcome, accounting);

            started = std.Io.Clock.awake.now(io);
            var quick_open = try core.quick_open.filterAlloc(allocator, index, "file");
            defer quick_open.deinit(allocator);
            outcome.samples.quick_open[cycle] = elapsedNanoseconds(started, io);
            if (quick_open.matches.len == 0 or quick_open.total_matches < 128)
                return error.QuickOpenMismatch;
            const ranking_queries = [_][]const u8{
                "file",
                "module03f007",
                "focusz",
            };
            var ranking_fingerprint: u64 = 14695981039346656037;
            for (ranking_queries) |query| {
                var ranking = try core.quick_open.filterAlloc(allocator, index, query);
                defer ranking.deinit(allocator);
                if (ranking.matches.len == 0) return error.QuickOpenRankingCorpusMismatch;
                for (ranking.matches) |match| {
                    ranking_fingerprint = (ranking_fingerprint ^ match.entry_index) *%
                        1099511628211;
                    ranking_fingerprint = (ranking_fingerprint ^ @as(
                        u64,
                        @bitCast(@as(i64, match.score)),
                    )) *% 1099511628211;
                }
            }
            if (cycle == 0) {
                outcome.ranking_fingerprint = ranking_fingerprint;
            } else if (ranking_fingerprint != outcome.ranking_fingerprint) {
                return error.QuickOpenRankingChanged;
            }
            recordPeak(&outcome, accounting);
        }

        {
            started = std.Io.Clock.awake.now(io);
            var search = try core.project_search.searchAllocWithLimits(
                allocator,
                io,
                project_root,
                "stability_needle",
                .{
                    .files = 512,
                    .file_bytes = 64 * 1024,
                    .total_bytes = 8 * 1024 * 1024,
                    .results = 512,
                },
            );
            defer search.deinit(allocator);
            outcome.samples.search[cycle] = elapsedNanoseconds(started, io);
            if (search.results.len < 128 or search.truncated)
                return error.ProjectSearchMismatch;
            outcome.search_results = search.results.len;
            recordPeak(&outcome, accounting);
        }

        {
            started = std.Io.Clock.awake.now(io);
            var grammar = try core.textmate_grammar.convertAlloc(allocator, grammar_source);
            defer grammar.deinit(allocator);
            outcome.samples.grammar[cycle] = elapsedNanoseconds(started, io);
            if (grammar.pattern_count != 2 or grammar.file_type_count != 1)
                return error.GrammarConversionMismatch;
            recordPeak(&outcome, accounting);
        }

        if (accounting.total_requested_bytes != cycle_baseline_bytes)
            return error.CycleAllocatorResidual;
    }
    return outcome;
}

fn recordPeak(outcome: *Outcome, accounting: *const AccountedAllocator) void {
    outcome.checkpoint_peak_active_bytes = @max(
        outcome.checkpoint_peak_active_bytes,
        accounting.total_requested_bytes,
    );
}

fn elapsedNanoseconds(started: std.Io.Timestamp, io: std.Io) u64 {
    const elapsed = started.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return @intCast(@max(elapsed, 0));
}

fn summarize(values: []u64) Summary {
    std.mem.sort(u64, values, {}, std.sort.asc(u64));
    return .{
        .p50_ns = percentile(values, 50),
        .p95_ns = percentile(values, 95),
        .p99_ns = percentile(values, 99),
    };
}

fn percentile(values: []const u64, percent: usize) u64 {
    const rank = (values.len * percent + 99) / 100;
    return values[@max(rank, 1) - 1];
}
