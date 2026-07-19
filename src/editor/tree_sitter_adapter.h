#ifndef NOCTTY_TREE_SITTER_ADAPTER_H
#define NOCTTY_TREE_SITTER_ADAPTER_H

#include <stddef.h>
#include <stdint.h>

typedef struct NocttyTreeSitterDocument NocttyTreeSitterDocument;

typedef struct {
    uint32_t start;
    uint32_t end;
    char scope[64];
} NocttyTreeSitterCapture;

typedef struct {
    uint32_t start_byte;
    uint32_t old_end_byte;
    uint32_t new_end_byte;
    uint32_t start_row;
    uint32_t start_column;
    uint32_t old_end_row;
    uint32_t old_end_column;
    uint32_t new_end_row;
    uint32_t new_end_column;
} NocttyTreeSitterEdit;

NocttyTreeSitterDocument *noctty_tree_sitter_document_new(int language);
void noctty_tree_sitter_document_free(NocttyTreeSitterDocument *document);
int noctty_tree_sitter_document_update(NocttyTreeSitterDocument *document,
                                        const char *source, size_t length,
                                        const NocttyTreeSitterEdit *edit);
int noctty_tree_sitter_document_highlight(NocttyTreeSitterDocument *document,
                                          NocttyTreeSitterCapture *captures,
                                          size_t capacity, size_t *total);

#endif
