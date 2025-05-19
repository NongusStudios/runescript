# Is it worth including the `NEGATE` instruction?
The negate instruction can be made redundant by simply loading literal constants as a negative number and you can negate numbers only known at runtime by simply using the `SUBTRACT` instruction (e.g. `-x` expands to `0 - x`). Further more subtract can also be eliminated by only using `NEGATE` (e.g. 2 - 1 expands to 2 + -1). This raises the question, why should `NEGATE` be included when it's functionality can be mimicked by `SUBTRACT` and  vice versa?

I think both of these instructions should be included in the byte code and here's why:
1. If `NEGATE` is removed then in order to negate a value not known at compile time, you would have to bump an extra value onto the stack which is unnecessary. 
2. If `SUBTRACT` is removed then you would have to add an extra instruction (`ADD`) to perform a subtract operation.
3. The only benefit either of these proposed changes provides, is a reduced instruction set, but they both add overhead for execution of subtract or negate operations, slowing these operations down.
### Conclusion
It's worth-while including both of these instructions in Runescript's bytecode for the sake of performance, while still minimizing the use of the `NEGATE` instruction by reading negated number constants (e.g. `-5`) in as negative numbers.