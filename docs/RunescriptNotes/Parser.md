# The Trie
The "trie" is a data structure that will be used check if an identifier is a keyword and what `Token_Type` it corresponds to, more efficiently than a standard array comparison search while being more robust than my current hard-coded conditional method.

This data structure will be created from an array of keyword strings and there subsequent `Token_Type` in a struct. The array is sorted alphabetically by hand.
E.G.
```
KEYWORDS :: [?]Keyword_Pair{
	{"elif",   ELIF},
	{"else",   ELSE},
	{"if",     IF},
	{"string", STRING},
	{"struct", STRUCT},
}
```
`init_trie` will be called with `init_parser` and would produce the following data structure based of the above array.
![trie](diagrams/trie.png)
## Usage
After initialisation of the trie it will simply need to be traversed against an identifier and then return a `Token_Type` determined by whether that identifier was present in the trie.
This will be done with the following function.
```
trie_search :: proc(identifier: string) -> Token_Type {...}
```
If the identifier is found in the trie, then that keywords corresponding `Token_Type` (stored at the leaves of the trie) entry will be returned. If the identifier is not found to lead to a leaf, then `Token_Type.IDENTIFIER` will be returned.

## Pseudo Code:
### `init_trie(KEYWORDS)`
- node = root
- for keyword in KEYWORDS
	- for character in keyword
		- if character is last
			- if exists(character) in node
				- break
			- insert leaf with type
		- elif exists(character) in node
			- traverse to next node
		- else
			- insert new node
		 
### `trie_search(identifier)`
- node = root
- for character in identifier
	- if exists(character) in node
		- traverse to node
		- if node is leaf
			- return `leaf.type`
	- else
		- return `IDENTIFIER`
## Notes
While not as efficient as a map I still thought it would be something to include in this first prototype rendition of the language, because implementing new data structures is great practice and keeps my mind thinking and learning new things.

# String Literal Interpolation
Right now the parser will only generate a single token to define a string literal. In order to implement string interpolation a string literal will need to be defined with multiple tokens. I think this could be achieved with a starting token to let the compiler know a string definition has started, a token for literal string values, a token for the start of an interpolation statement, a token for the end of an interpolation statement, and finally one to end the string definition.

e.g. `"Hello, ${x}"` would produce the following list of tokens:
```
- STRING_LITERAL_START '"'
- STRING_LITERAL_VALUE 'Hello, '
- STRING_INTERP_START '${'
- IDENTIFIER 'x'
- STRING_INTERP_END '}'
- STRING_LITERAL_END   '"'
```

## Implementation
`scan_token` only returns one token at a time, but if this is how I'm going to start represent strings how am I gonna keep track of whether I am inside a string or not?
I could have some conditional values in the Parser to keep track of this between `scan_token` calls but I have a better idea.

I will create all tokens needed to represent the string literal on the first call of `scan_token` when a string is found. I will then add those tokens to a new field in the parser `queuedTokens` which will be a FIFO queue object, after that subsequent calls to `scan_token` will dequeue this list until it is empty and then will go back to scanning tokens.
```
if len(queue) > 0 then dequeue
else scan next token
```