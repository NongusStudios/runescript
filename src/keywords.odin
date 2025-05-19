package main

import "core:fmt"

Keyword_Pair :: struct {
    word: string,
    type: Token_Type,
}

// All keyword identifiers, sorted alphabetically
KEYWORDS :: [?]Keyword_Pair {
    {"and",      Token_Type.AND}, 
    {"bool",     Token_Type.BOOL},    
    {"break",    Token_Type.BREAK},   
    {"continue", Token_Type.CONTINUE},
    {"double",   Token_Type.DOUBLE},
    {"elif",     Token_Type.ELIF},
    {"else",     Token_Type.ELSE},
    {"false",    Token_Type.FALSE},
    {"func",     Token_Type.FUNC},
    {"float",    Token_Type.FLOAT},
    {"if",       Token_Type.IF},
    {"import",   Token_Type.IMPORT},
    {"int",      Token_Type.INT},
    {"nil",      Token_Type.NIL},
    {"or",       Token_Type.OR},
    {"print",    Token_Type.PRINT},
    {"size",     Token_Type.SIZE},
    {"string",   Token_Type.STRING},
    {"struct",   Token_Type.STRUCT},
    {"var",      Token_Type.VAR},
    {"true",     Token_Type.TRUE},
}

Keyword_Trie_Node :: union{^Keyword_Trie_Branch, ^Keyword_Trie_Leaf}

KEYWORD_TRIE_BRANCH_CHILDREN_INIT_CAP :: 4
Keyword_Trie_Branch :: struct {
    character: rune,
    children: [dynamic]Keyword_Trie_Node,
}

Keyword_Trie_Leaf :: struct {
    character: rune,
    type: Token_Type,
}

@(private="file")
trie: Keyword_Trie_Branch

@(private="file")
trie_allocations: [dynamic]Keyword_Trie_Node

make_keyword_trie_branch :: proc(c: rune) -> Keyword_Trie_Node {
    branch := new(Keyword_Trie_Branch)
    branch.character = c
    branch.children  = make([dynamic]Keyword_Trie_Node, 0, KEYWORD_TRIE_BRANCH_CHILDREN_INIT_CAP)

    append(&trie_allocations, branch)

    return branch
}

make_keyword_trie_leaf :: proc(c: rune, t: Token_Type) -> Keyword_Trie_Node {
    leaf := new(Keyword_Trie_Leaf)
    leaf.character = c
    leaf.type      = t

    append(&trie_allocations, leaf)

    return leaf
}

delete_keyword_trie_node :: proc(node: Keyword_Trie_Node) {
    switch t in node {
        case ^Keyword_Trie_Branch: {
            delete(t.children)
            free(t)
        }
        case ^Keyword_Trie_Leaf: free(t)
    }
}

keyword_trie_branch_insert_node :: proc(branch: ^Keyword_Trie_Branch, node: Keyword_Trie_Node) {
    append(&branch.children, node)
}

/* traverses to next node that contains a key equal-to 'to' and secondary return value is true.
 * if the next node can't be traversed to then (nil, false) is returned
*/
keyword_trie_branch_traverse :: proc(from: ^Keyword_Trie_Branch, to: rune) -> (Keyword_Trie_Node, bool) {
    for child in from.children {
        key: rune
        switch t in child {
            case ^Keyword_Trie_Branch: {
                key = t.character               
            }
            case ^Keyword_Trie_Leaf: {
                key = t.character
            }
        }

        if key == to {
            return child, true
        }
    }

    return nil, false
}

// populates trie with keywords
init_keyword_trie :: proc() {
    trie.character = 0
    trie.children = make([dynamic]Keyword_Trie_Node, 0, len(KEYWORDS))
    trie_allocations = make([dynamic]Keyword_Trie_Node, 0, len(KEYWORDS)*32)

    for KEYWORD in KEYWORDS {
        current: Keyword_Trie_Node = &trie
        
        i := 0
        for c in KEYWORD.word {
            switch node in current {
                case ^Keyword_Trie_Branch: {
                    if next, ok := keyword_trie_branch_traverse(node, c); ok {
                        current = next
                    } else {
                        insert_node := make_keyword_trie_leaf(c, KEYWORD.type) if i == len(KEYWORD.word)-1 else make_keyword_trie_branch(c)
                        keyword_trie_branch_insert_node(node, insert_node)
                        //fmt.printfln("info: inserting %v under %v", insert_node, current)
                        current = insert_node
                        
                    }
                }
                case ^Keyword_Trie_Leaf: break
            }
            i += 1
        }
    }
}

free_keyword_trie :: proc() {
    for alloc in trie_allocations {
        delete_keyword_trie_node(alloc)
    }
    delete(trie.children)
    delete(trie_allocations)
}

/* searches for 'identifier' and returns its related token type
 * if the identifier is not found in the trie 'Token_Type.IDENTIFIER' is returned
*/
keyword_trie_search :: proc(identifier: []rune) -> Token_Type {
    current: Keyword_Trie_Node = &trie
    for c in identifier {
        switch node in current {
            case ^Keyword_Trie_Branch: {
                if next, ok := keyword_trie_branch_traverse(node, c); ok {
                    current = next
                    //fmt.printfln("info: traversed to %v", next)
                    continue
                }
                break
            }
            case ^Keyword_Trie_Leaf: break
        }
    }
    if leaf, ok := current.(^Keyword_Trie_Leaf); ok {
        return leaf.type
    }
    return Token_Type.IDENTIFIER
}