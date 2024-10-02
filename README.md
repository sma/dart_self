# Self

This is an experimental interpreter for a subset of [Self][Self]. It has nearly
no runtime system. Super calls and direct resends are missing. I wrote it some
years ago (in Java) to get a grasp on the non-trivial message execution semantic
of this interesting programming language. I haven't checked with the Self system
so I might have got some methods or some semantics wrong.

[Self]: http://en.wikipedia.org/wiki/Self_(programming_language)

Most code is from 2013 and was written for Dart 1.x but in 2022 I ported it to
the then current Dart 2.19. Run `dart pub get` to initialize the project, then
run `dart test` to run all unit tests and run `dart run` to start a simple REPL.
Use ^C or ^D to end it.

The `Makefile` helps in creating a code coverage report.

## Resends

Currently, the interpreter is **lacking support** for both undirected and for
directed resends. Neither does the parser understands them nor can the runtime
system execute them. A resend is a NAME (or `resend` keyword) followed by a DOT
followed by either a NAME, OPERATOR or KEYWORD, without whitespace inbetween. I
might be able to use `(\w+)\.(?=\S)|(\w+)` to distinguish resends from normal
names. Then a `_T.res` could denote resend identifiers, swallowing the dot.

The bigger problem is that to search for a resend message, I cannot start with
the receiver for the method lookup but need to start at the parents of the
object the current method belongs to. This is an information I don't keep track
of. When normally searching for a method, I find and return the `Slot`. I'd have
to store a reference to the object in each slot. Or at least return that object
together with the slot and then store a reference in the method object. Or at
least for methods that have a resend instruction. But I don't want to modify the
instructions so I probably need to add a hidden slot.

The `findSlot` call should return a `(Slot, SelfObject)` tuple. We could then
store the holder inside the current activation (that is method) as a slot called
`(holder)`. A resend would then read that `(holder)` slot and starts `findSlot`
with its parents.
