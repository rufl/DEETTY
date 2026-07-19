# Vendored Tree-sitter sources

The following vendored sources are used by NOCTTY's native syntax adapter. Each
directory retains its upstream license file.

| Source | Revision | License | Compiled in this slice |
| --- | --- | --- | --- |
| `tree-sitter` | `2a835ee029dca1c325e6f1c01dbce40396f6123e` | MIT | yes |
| `tree-sitter-json` | `001c28d7a29832b06b0e831ec77845553c89b56d` | MIT | yes |
| `tree-sitter-c` | `b780e47fc780ddc8da13afa35a3f4ed5c157823d` | MIT | yes |
| `tree-sitter-bash` | `a06c2e4415e9bc0346c6b86d401879ffb44058f7` | MIT | yes |
| `tree-sitter-markdown` | `c3570720f7f7bbad22fe96603f106276618e0cf5` | MIT | yes |
| `tree-sitter-zig` | `2866ee6f8b8f67c9b1eca2ca6c88f0a5f1bcc13f` | MIT | yes; parser generated with Tree-sitter CLI 0.20.8 |

NOCTTY does not load grammars dynamically or execute a language runtime. The
compiled adapter links the Tree-sitter C runtime and selected generated parser
sources directly into the native Zig build.

NOCTTY applies one source-compatible correction to the pinned Bash scanner:
`tree_sitter_bash_external_scanner_create` uses an explicit `(void)` parameter
list matching the declaration emitted in `parser.c`. This changes no grammar
tables or scanner behavior; it prevents an optimized indirect-call type
mismatch in the legacy verification adapter.
