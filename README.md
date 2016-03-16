# Egg-Eater

![An adder](https://upload.wikimedia.org/wikipedia/commons/9/97/Dasypeltis_atra.jpg)

This assignment implements a compiler for the Egg-eater language, a small
language with functions, numbers, booleans, and _tuples_.  The name egg-eater
comes from the fact that tuple syntax with parentheses looks a little bit like
an egg, if you squint and don't think about it too much.

## Language

Egg-eater has largely the same semantics as Diamondback, with a few additions
and changes.

### Syntax Additions

The main addition in Egg-eater is _tuple expressions_, along with an accessor
expression for getting the contents of tuples.  Tuple expressions are a series
of _two or more_ comma-separated expressions enclosed in parentheses.  A tuple
access expression is an expression, followed by another expression enclosed in
square brakcets.  Finally, `istuple` is a primitive, like `isnum` and `isbool`
that checks for tuple-ness.

```
expr :=
    [ the same expressions as Diamondback ]
  | (<expr>, <expr>, <expr>, ...)
  | <expr>[<expr>]
  | istuple(<expr>)
```

For example:

```
let x = (3, 4, 5) in
x[0]
```

uses a tuple expression in the let binding, and has a tuple access as the body.

In the `expr` datatype, these are represented as:

```
type expr =
  ...
  | ETuple of expr list
  | EGetItem of expr * expr

type prim1 =
  | IsTuple
```

In ANF syntax, these expressions are represented as `cexpr`s, with `immexpr`
components:

```
type cexpr =
  ...
  | CTuple of immexpr list
  | CGetItem of immexpr * immexpr
```

### Semantics and Representation of Tuples

#### Tuple Heap Layout

Tuples expressions should evaluate their sub-expressions in order, and store
the resulting values on the heap.  The layout for a tuple on the heap is:

```
  (4 bytes)    (4 bytes)  (4 bytes)          (4 bytes)
--------------------------------------------------------
| # elements | element_0 | element_1 | ... | element_n |
--------------------------------------------------------
```

That is, one word is used to store the _count_ of the number of elements in the
tuple, and the subsequent words are used to store the values themselves.

A _tuple value_ is stored in variables and registers as the address of the
first word in the tuple's memory, but with an additional `1` added to the value
to act as a tag.  So, for example, if the start address of the above memory
were `0x0adadad0`, the tuple value would be `0x0adadad1`.  With this change, we
extend the set of tag bits to the following:

- Numbers: `0` in least significant bit
- Booleans: `111` in least three significant bits
- Tuples: `001` in least three significant bits

Visualized differently, the value layout is:

```
0xWWWWWWW[www0] - Number
0xFFFFFFF[1111] - True
0x7FFFFFF[1111] - False
0xWWWWWWW[w001] - Tuple
```

Where `W` is a "wildcard" nibble and `w` is a "wildcard" bit.

#### Accessing Tuple Contents

In a _tuple access_ expression, like 

```
(6, 7, 8, 9)[1 + 2]
```

The behavior should be:

1.  Evaluate the expression in tuple position (before the brackets), then the
    index expression (the one inside the brackets).
2.  Check that the tuple position's value is actually a tuple, and signal an
    error containing `"expected tuple"` if not.
3.  Check that the index value is a number, and signal an error containing
    `"expected number"` if not.
4.  Check that the index number is a valid index for the tuple value—that
    is, it is between `0` and the stored number of elements in the tuple minus
    one.  Signal an error containing `"index too small"` or `"index too large"`
    as appropriate.
5.  Evaluate to the tuple element at the specified index.

You _can_ do this with just `EAX`, but it causes some minor pain.  The register
`ECX` has been added to the registers in `instruction.ml` – feel free to
generate code that uses both `EAX` and `ECX` in this case (for example saving
the index in `ECX` and using `EAX` to store the address of the tuple).  This
can save a number of instructions.  Note that we will generate code that
doesn't need to use `ECX` or `EAX` beyond the extent of this one expression, so
there is no need to worry about saving or restoring the old value from `ECX`.

You also may want to use an extended syntax for `mov` in order to combine these
values for lookup.  For example, this kind of arithmetic is allowed inside
`mov` instructions:

```
  mov eax, [eax + ecx * 4]
```

This would access the memory at the location of `eax`, offset by the value of
`ecx * 4` plus one.  So if the value in `ecx` were, say `2`, this may be part
of a scheme for accessing the first element of a tuple (there are other details
you should think through here; this is _not_ a complete solution) Feel free to
add additional `arg` types in `instruction.ml` to support a broader range of
`mov` instructions, if it helps.

Neither `ECX` nor anything beyond the typical `RegOffset` is _required_ to make
this work, but you may find it interesting to try different shapes of
generated instructions.

#### General Heap Layout

The register `ESI` has been designated as the heap pointer.  The provided
`main.c` does a large `malloc` call, and passes in the resulting address as an
argument to `our_code_starts_here`.  The support code provided fetches this
value (as a traditional argument), and stores it in `ESI`.  It also does a bit
of arithmetic to make sure that `ESI` starts at an 8-byte boundary – that is,
the last three _bits_ of `ESI` are `000`.  It is up to your code to ensure that:

- The value of `ESI` always ends in `000`.  This ensures that the beginning of
  each allocation happens at an 8-byte boundary, which means that we only need
  29 bits of a 32-bit word in order to store addresses.  The least significant
  bits are then fair game for the tag.
- The value of `ESI` is always the address of the next block of free space (in
  increasing address order) in the provided block of memory.
  
The first point above means that for tuples that take up an odd amount of
4-byte words, `ESI` needs to leave some "dead space" in order to align with an
8-byte boundary.  For example, assume before an allocation `ESI` is pointing at
address 0xada0:

```
ESI = 0xada0


                  0xada0
                    |
--------------------|
| *** used space ***|
---------------------
```

And then we need to allocate the tuple `(4, true)`.  Since we need one word for
the size (2) and one word each for the two values `4` and `true`, there are 3
bytes required to store the tuple.  If we left the heap in this state:


```
ESI = 0xadac


                  0xada0                                0xadac
                    |                                      |
--------------------|--------------------------------------|
| *** used space ***| 0x00000002 | 0x00000004 | 0xFFFFFFFF |
-----------------------------------------------------------|
```

Then we couldn't use three tag bits when using `0xadac` (the next allocation
we'd need to perform), because the `c` part uses the third-least significant bit:

```
c = 1100
```

Which would conflict with our tagging strategy.  Note that in this assignment,
we might be able to get away with 4-byte word boundaries, but in future
assignments we will use more tags, and need all three bits.  So instead of the
above resulting picture, `ESI` should be moved one word further:

```
ESI = 0xadb0


                  0xada0                                            0xadb0
                    |  (size)       (value 4)  (value true)           |
--------------------|-------------------------------------------------|
| *** used space ***| 0x00000002 | 0x00000008 | 0xFFFFFFFF | padding  |
----------------------------------------------------------------------|
```

The `padding` is unused space to make the heap allocation strategy with tagging
work cleanly – this is certainly a place where you can think about some
interesting tradeoffs (what are some of them?)


#### Interaction with Existing Features

Any time we add a new feature to a language, we need to consider its
interactions with all the existing features.  In the case of Egg-eater, that
means considering:

- If expressions
- Function calls and definitions
- Tuples in binary and unary operators
- Let bindings

We'll take them one at a time.

- **If expressions**:  Since we've decided to only allow booleans in
  conditional position, we simply need to make sure our existing checks for
  boolean-tagged values in if continue to work for tuples.
- **Function calls and definitions**:  Tuple values behave just like other
  values when passed to and returned from functions – the tuple value is just
  a (tagged) address that takes up a single word.
- **Tuples in let bindings**:  As with function calls and returns, tuple values
  take up a single word and act just like other values in let bindings.
- **Tuples in binary operators**:  The arithmetic expressions should
  continue to only allow numbers, and signal errors on tuple values.  There is
  one binary operator that doesn't check its types, however: `==`.  We need to
  decide what the behavior of `==` is on two tuple values.  Note that we have a
  (rather important) choice here.  Clearly, this program should evaluate to
  `true`:

  ```
  let t = (4, 5) in t == t
  ```
  
  However, we need to decide if

  ```
  (4,5) == (4,5)
  ```

  should evaluate to `true` or `false`.  That is, do we check if the _tuple
  addresses_ are the same to determine equality, or if the _tuple contents_ are
  the same.  For this assignment, we'll take the somewhat simpler route and
  compare _addresses_ of tuples, so the second test should evaluate to `false`.
  (If you have extra time on this assignment, it's worth trying out the
  alternate implementation, where you check the tuple contents.  A useful hint
  is to write a two-argument function `equal` in `main.c` that handles this.
  There is no extra credit for this, just extra learning, which is immensely
  more valuable.)
- **Tuples in unary operators**: The behavior of the unary operators is
  straightforward, with the exception that we need to implement `print` for
  tuples.  We could just print the address, but that would be somewhat
  unsatisfying.  Instead, we should recursively print the tuple contents, so
  that the program

  ```
  print((4, (true, 3)))
  ```

  actually prints the string `"(4, (true, 3))"`.  This will require some
  careful work with pointers in `main.c`.  A useful hint is to create a
  recursive helper function for `print` that traverses the nested structure of
  tuples and prints single values.

## Approaching Reality

With the addition of tuples, Egg-eater is dangerously close to a useful
language.  Of course, it still puts no control on memory limits, doesn't have a
module system, and has other major holes.  However, since we have structured
data, we can now, for instance, implement a linked list.  We need to pick a
value to represent `empty` – `false` will do in a pinch.  Then we can write
`link`, which creates a pair of the first with the next link:

```
def link(first, rest):
  (first, rest)

let mylist = link(1, link(2, link(3, false))) in
  mylist[0]
```

Now we can write some list functions:

```
def length(l):
  if l == false: 0
  else:
    1 + length(l[1])
```

Try building on this idea, and writing up a basic list library.  Write at least
`sum`, to add up a numeric list, `append`, which concatenates two lists, and
`reverse`, which reverses a list.  Write more if you want, and test them out.


## Recommended TODO List

1. Implement the `ETuple` and `EGetItem` cases in ANF.  The helper `anf_list`
   has been provided for you to use in the `ETuple` case.
2. Get tuple creation and access working for tuples containing two elements,
   testing as you go.  This is very similar to the pairs code from lecture.
3. Modify the binary and unary operators to handle tuples appropriately (it may
   be useful to skip `print` at first). Test as you go.
4. Make tuple creation and access work for tuples of any size.  Test as you go.
5. Tackle `print` for tuples if you haven't already.  Test as you go.
6. Write some list library functions (at least the three above) to really
   stress your tuple implementation.  Rejoice in your implementation of the
   core features needed for nontrivial computation (Aside from the pesky issue
   of running out of memory.  More on that in lecture soon.).
7. If you want to try more, implement content-equality rather than
   address-equality for tuples.  And/or, try implementing something more
   ambitious than lists, like a binary search tree, in Egg-eater.  This last
   point is ungraded, but quite rewarding!
