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
