import 'package:self/self.dart';

/// Testing the resend feature.
void main() {
  final self = Self();
  self.lobby.addSlotIfAbsent(Slot.c(
      'traits',
      SelfObject([
        Slot.c('block', self.traitsBlock),
        Slot.c('number', self.traitsNumber),
      ])));
  self.primitives.addAll({
    '_AddSlotsIfAbsent:': (a) {
      final r = a[0] as SelfObject;
      for (final slot in (a[1] as SelfObject).slots) {
        r.addSlotIfAbsent(slot);
      }
      return r;
    },
    '_Equal:': (a) => a[0] == a[1] ? self.trueObject : self.falseObject,
    '_Vector:': (a) => List<SelfValue>.filled(a[1] as int, self.nilObject, growable: true),
    '_AddTo:': (a) => (a[0] as int) + (a[1] as int),
    '_Print': (a) {
      print(a[0]);
      return self.nilObject;
    },
  });
  final result = self.execute('''
"summon globals from the interpreter."
self _AddSlotsIfAbsent: (|
  globals* = (|
    lobby = self.
    nil = [] value.
    true = 0 _Equal: 0.
    false = 0 _Equal: 1.
  |).
  traits = (|
    block = [] parent.
    " this doesn't work yet.
    number = 0 parent.
    string = '' parent.
    vector = (_Vector: 0) parent.
    "
  |).
|).

traits number _AddSlotsIfAbsent: (|
  parent* = lobby.
  isNil = false.
  ifNil: block = (self).
  + b = (self _AddTo: b).
|).

nil _AddSlotsIfAbsent: (|
  i_am_nil = 0.
  isNil = true.
  ifNil: block = (block value).
|).

true _AddSlotsIfAbsent: (|
  i_am_true = 0.
  not = false.
  ifTrue: block = (block value).
  ifTrue: block False: anotherBlock = (block value).
  ifFalse: block = nil.
  ifFalse: block True: anotherBlock = (anotherBlock value).
|).

false _AddSlotsIfAbsent: (|
  i_am_false = 0.
  not = true.
  ifTrue: block = nil.
  ifTrue: block False: anotherBlock = (anotherBlock value).
  ifFalse: block = (block value).
  ifFalse: block True: anotherBlock = (block value).
|).

traits block _AddSlotsIfAbsent: (|
  parent* = lobby.
  whileTrue: block = (self value ifTrue: [block value. self whileTrue: block]).
  whileFalse: block = (self value ifFalse: [block value. self whileFalse: block]).
  loopWithExit = (self value: [^nil]. self loopWithExit).
|).

"testing loopWithExit, this should print '6'."
[|x| x: 0. [| :exit | x: x + 1. (x _Equal: 6) ifTrue: exit] loopWithExit. x] value _Print.

"testing resend, this should print 'base' 'parent1' 'parent2' and return 'done' but doesn't work yet."
globals _AddSlotsIfAbsent: (|
  base = (|
    i_am_base = 0.
    parent* = (|
      i_am_parent1 = 0.
      parent* = (|
        i_am_parent2 = 0.
        foo = ('parent2' _Print. 'done').
      |).
      foo = ('parent1' _Print. "resent.foo").
    |).
    "foo = ('base' _Print. resent.foo)."
  |).
|).

base foo.

''');
  print(result);
  print('------');
  final base = self.findSlot(self.lobby, 'base').$1.value;
  print(base);
  final first = self.findSlot(base, 'foo', onlyParents: false);
  print(first);
  final second = self.findSlot(first.$2, 'foo', onlyParents: true);
  print(second);
}
