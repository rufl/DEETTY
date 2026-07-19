#include "tree_sitter_adapter.h"
#include "tree_sitter/api.h"
#include <stdlib.h>
#include <string.h>

const TSLanguage *tree_sitter_json(void);
const TSLanguage *tree_sitter_c(void);
const TSLanguage *tree_sitter_bash(void);
const TSLanguage *tree_sitter_markdown(void);
const TSLanguage *tree_sitter_zig(void);

struct NocttyTreeSitterDocument {
    TSParser *parser;
    TSTree *tree;
    TSQuery *query;
    const TSLanguage *language;
};

static const char *query_for_language(int language) {
    switch (language) {
    case 1:
        return "(string) @string (number) @number (null) @constant "
               "(true) @constant (false) @constant (comment) @comment";
    case 2:
        return "(comment) @comment (string_literal) @string (number_literal) @number "
               "(identifier) @variable (type_identifier) @type "
               "(function_declarator declarator: (identifier) @function) "
               "[\"if\" \"else\" \"for\" \"while\" \"return\" \"struct\" \"typedef\" \"const\"] @keyword";
    case 3:
        return "[(comment) (string) (raw_string) (heredoc_body)] @string "
               "(command_name) @function (variable_name) @property "
               "[\"case\" \"do\" \"done\" \"elif\" \"else\" \"fi\" \"for\" \"function\" \"if\" \"in\" \"then\" \"while\"] @keyword";
    case 4:
        return "(atx_heading) @heading (setext_heading) @heading "
               "(fenced_code_block) @code_fence (indented_code_block) @code_fence "
               "(block_quote) @comment";
    case 5:
        return "(line_comment) @comment (doc_comment) @comment "
               "(string_literal) @string (string_literal_single) @string "
               "(integer) @number (float) @number (identifier) @variable";
    default:
        return NULL;
    }
}

static const TSLanguage *language_for_id(int language) {
    switch (language) {
    case 1: return tree_sitter_json();
    case 2: return tree_sitter_c();
    case 3: return tree_sitter_bash();
    case 4: return tree_sitter_markdown();
    case 5: return tree_sitter_zig();
    default: return NULL;
    }
}

NocttyTreeSitterDocument *noctty_tree_sitter_document_new(int language) {
    const TSLanguage *ts_language = language_for_id(language);
    const char *query_source = query_for_language(language);
    if (ts_language == NULL || query_source == NULL) return NULL;
    NocttyTreeSitterDocument *document = calloc(1, sizeof(*document));
    if (document == NULL) return NULL;
    document->parser = ts_parser_new();
    if (document->parser == NULL || !ts_parser_set_language(document->parser, ts_language)) {
        noctty_tree_sitter_document_free(document);
        return NULL;
    }
    uint32_t error_offset = 0;
    TSQueryError error_type = TSQueryErrorNone;
    document->query = ts_query_new(ts_language, query_source, strlen(query_source),
                                   &error_offset, &error_type);
    if (document->query == NULL || error_type != TSQueryErrorNone) {
        noctty_tree_sitter_document_free(document);
        return NULL;
    }
    document->language = ts_language;
    return document;
}

void noctty_tree_sitter_document_free(NocttyTreeSitterDocument *document) {
    if (document == NULL) return;
    if (document->tree != NULL) ts_tree_delete(document->tree);
    if (document->query != NULL) ts_query_delete(document->query);
    if (document->parser != NULL) ts_parser_delete(document->parser);
    free(document);
}

int noctty_tree_sitter_document_update(NocttyTreeSitterDocument *document,
                                       const char *source, size_t length,
                                       const NocttyTreeSitterEdit *edit) {
    if (document == NULL || source == NULL) return -1;
    if (document->tree != NULL && edit != NULL) {
        TSInputEdit input = {
            .start_byte = edit->start_byte,
            .old_end_byte = edit->old_end_byte,
            .new_end_byte = edit->new_end_byte,
            .start_point = {edit->start_row, edit->start_column},
            .old_end_point = {edit->old_end_row, edit->old_end_column},
            .new_end_point = {edit->new_end_row, edit->new_end_column},
        };
        ts_tree_edit(document->tree, &input);
    }
    TSTree *previous = edit != NULL ? document->tree : NULL;
    TSTree *next = ts_parser_parse_string(document->parser, previous,
                                           source, (uint32_t)length);
    if (next == NULL) return -1;
    if (document->tree != NULL) ts_tree_delete(document->tree);
    document->tree = next;
    return 0;
}

int noctty_tree_sitter_document_highlight(NocttyTreeSitterDocument *document,
                                           NocttyTreeSitterCapture *captures,
                                           size_t capacity, size_t *total) {
    if (document == NULL || document->tree == NULL || captures == NULL || total == NULL) return -1;
    *total = 0;
    TSQueryCursor *cursor = ts_query_cursor_new();
    if (cursor == NULL) return -1;
    ts_query_cursor_exec(cursor, document->query, ts_tree_root_node(document->tree));
    TSQueryMatch match;
    uint32_t capture_index;
    while (ts_query_cursor_next_capture(cursor, &match, &capture_index)) {
        TSQueryCapture capture = match.captures[capture_index];
        TSNode node = capture.node;
        uint32_t name_length = 0;
        const char *name = ts_query_capture_name_for_id(document->query, capture.index, &name_length);
        (*total)++;
        if (*total <= capacity) {
            NocttyTreeSitterCapture *out = &captures[*total - 1];
            out->start = ts_node_start_byte(node);
            out->end = ts_node_end_byte(node);
            size_t copy_length = name != NULL ? name_length : strlen("invalid");
            if (copy_length >= sizeof(out->scope)) copy_length = sizeof(out->scope) - 1;
            memcpy(out->scope, name != NULL ? name : "invalid", copy_length);
            out->scope[copy_length] = '\0';
        }
    }
    ts_query_cursor_delete(cursor);
    return 0;
}
