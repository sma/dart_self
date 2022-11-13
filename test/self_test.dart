import 'package:self/self.dart';
import 'package:test/test.dart';

SelfObject o(SelfValue v) => v as SelfObject;

void main() {
  final self = Self();
  final nil = self.nilObject;

  group('Self object:', () {
    test('Access a slot value', () {
      final obj = SelfObject([Slot.c('a', 1)]);
      expect(self.findSlot(obj, 'a').value, 1);
    });

    test('Access a slot value in parent object', () {
      final obj1 = SelfObject([Slot.c('a', 1)]);
      final obj2 = SelfObject([Slot.c('p', obj1, parent: true)]);
      expect(self.findSlot(obj2, 'a').value, 1);
    });

    test('Access a slot value in parent object without endless loop', () {
      final obj1 = SelfObject([Slot.c('b', nil, parent: true), Slot.c('a', 1)]);
      final obj2 = SelfObject([Slot.c('p', obj1, parent: true)]);
      obj1.slots[0].value = obj2;
      expect(self.findSlot(obj2, 'a').value, 1);
    });

    test('Access an unknown slot value', () {
      final obj = SelfObject([Slot.c('a', 1)]);
      expect(() => self.findSlot(obj, 'b'), throwsA('UnknownMessageSend(b)'));
    });

    test('Access an ambiguous slot value', () {
      final obj1 = SelfObject([Slot.c('a', 1)]);
      final obj2 = SelfObject([Slot.c('a', 2)]);
      final obj3 = SelfObject([Slot.c('p1', obj1, parent: true), Slot.c('p2', obj2, parent: true)]);
      expect(() => self.findSlot(obj3, 'a'), throwsA('AmbiguousMessageSend(a)'));
    });

    test('Cloning an object', () {
      final obj1 = SelfObject([Slot.a('a', 1), Slot.d('b', 2)]);
      final obj2 = obj1.clone();
      obj2.slots[0].value = 3;
      obj2.slots[1].value = 4;
      expect(obj1.slots[0].value, 1);
      expect(obj1.slots[1].value, 2);
    });

    test('Add a slot', () {
      final obj = SelfObject([]);
      obj.addSlotIfAbsent(Slot.c('a', nil));
      expect(obj.slots.length, 1);
      expect(obj.slots[0].name, 'a');
    });

    test('Add a data slot', () {
      final obj = SelfObject([]);
      obj.addSlotIfAbsent(Slot.d('a', nil));
      expect(obj.slots.length, 2);
      expect(obj.slots[0].name, 'a');
      expect(obj.slots[1].name, 'a:');
    });

    test('Remove a slot', () {
      final obj = SelfObject([Slot.c('x', 1)]);
      obj.removeSlotNamed('x');
      expect(obj.slots.length, 0);
    });

    test('Remove a data slot', () {
      final obj = SelfObject([Slot.c('x', 1), Slot.m('x')]);
      obj.removeSlotNamed('x');
      expect(obj.slots.length, 0);
    });

    test('Printstring', () {
      expect(SelfObject([]).toString(), '(|  |)');
      expect(
        SelfObject([
          Slot.c('a', 0),
          Slot.c('b', 0, parent: true),
          Slot.d('c', 0),
          Slot.m('c'),
          Slot.d('d', 0, parent: true),
          Slot.m('d'),
          Slot.a('e', 0),
          Slot.a('f', 0, parent: true),
        ]).toString(),
        '(| a. b*. c<-. c:. d*<-. d:. :e. :f* |)',
      );
    });
  });

  group('Self method:', () {
    test('Return nil for empty methods', () {
      expect(SelfMethod([], []).execute(self), nil);
    });

    test('Return the last expression', () {
      expect(SelfMethod([], [Lit(41)]).execute(self), 41);
      expect(SelfMethod([], [Lit(42), Lit(41)]).execute(self), 41);
    });

    test('Access an argument slot', () {
      expect(SelfMethod([Slot.c('a', 1)], [Msg(null, 'a', [])]).execute(self), 1);
    });

    test('Access an instance slot', () {
      final inst = SelfObject([Slot.c('b', 2)]);
      final meth = SelfMethod([Slot.c('self', inst, parent: true), Slot.c('a', 1)], [Msg(null, 'b', [])]);
      expect(meth.execute(self), 2);
    });

    test('Send a primitive message', () {
      self.primitives.addAll({
        '_Add:': (a) => (a[0] as int) + (a[1] as int),
        '_Sub:': (a) => (a[0] as int) - (a[1] as int),
      });
      expect(
          SelfMethod([], [
            Msg(Lit(3), '_Add:', [Lit(4)])
          ]).execute(self),
          7);
      expect(
          SelfMethod([], [
            Msg(Lit(4), '_Sub:', [Lit(3)])
          ]).execute(self),
          1);
    });

    test('Printstring', () {
      expect(SelfMethod([], []).toString(), '(|  |  )');
    });
  });

  group('Code:', () {
    test('Literal objects', () {
      final a = SelfObject([]);
      expect(Lit(1).execute(self, a), 1);
      expect(Lit(1.1).execute(self, a), 1.1);
      expect(Lit('a').execute(self, a), 'a');
      expect(Lit(nil).execute(self, a), nil);
      expect(Lit(true).execute(self, a), true);
      expect(Lit(false).execute(self, a), false);
      final obj = SelfObject([]);
      expect(Lit(obj).execute(self, a), same(obj));
    });

    test('Literal methods', () {
      final a = SelfObject([]);
      final meth = SelfMethod([], [Lit(1)]);
      expect(Mth(Lit(meth)).execute(self, a), 1);
    });

    test('Literal blocks', () {
      final a = SelfObject([]);
      final m = SelfMethod([Slot.a('(parent)', nil, parent: true)], [Lit(1)]);
      final b = SelfObject(
          [Slot.c('parent', self.traitsBlock, parent: true), Slot.a('(lexicalParent)', nil), Slot.c('value', m)]);
      final rslt = o(Blk(b).execute(self, a));
      expect(rslt.slots[0].value, self.traitsBlock);
      expect(rslt.slots[1].value, same(a));
      expect(rslt.slots[2].value, same(m));
    });

    test('Implicit message send', () {
      final a = SelfObject([Slot.d('a', 1), Slot.m('a')]);
      expect(Msg(null, 'a', []).execute(self, a), 1);
      final b = SelfObject([Slot.c('p', a, parent: true)]);
      expect(Msg(null, 'a', []).execute(self, b), 1);
      expect(Msg(null, 'a:', [Lit(2)]).execute(self, b), 2);
      expect(self.findSlot(a, 'a').value, 2);
    });

    test('Explicit message send', () {
      final a = SelfObject([Slot.c('o', nil)]);
      final obj1 = SelfObject([Slot.c('a', 1)]);
      a.slots[0].value = obj1;
      expect(Msg(Msg(null, 'o', []), 'a', []).execute(self, a), 1);
      final obj2 = SelfObject([Slot.c('p', obj1, parent: true)]);
      a.slots[0].value = obj2;
      expect(Msg(Msg(null, 'o', []), 'a', []).execute(self, a), 1);
    });

    test('Unknown primitive message send', () {
      expect(() => Msg(null, '_Qux', []).execute(self, nil), throwsA('UnknownPrimitive(_Qux)'));
    });

    test('Missing mutator message send', () {
      final a = SelfObject([Slot.m('a')]);
      expect(() => Msg(null, 'a:', [Lit(nil)]).execute(self, a), throwsA('MutatorWithoutDataSlot(a:)'));
    });
  });

  group('Parser:', () {
    group('Literals:', () {
      test('Numbers', () {
        expect(Parser(self, '1').parseLiteral(), 1);
        expect(Parser(self, '1.23').parseLiteral(), 1.23);
        expect(Parser(self, '-4').parseLiteral(), -4);
        expect(Parser(self, '-4.11').parseLiteral(), -4.11);
      });

      test('Strings', () {
        expect(Parser(self, "''").parseLiteral(), '');
        expect(Parser(self, "'1.23'").parseLiteral(), '1.23');
        expect(Parser(self, "'\\b\\f\\n\\r\\t\\u20AC\\'\\\\'").parseLiteral(), '\b\f\n\r\t\u20AC\'\\');
      });

      group('Objects:', () {
        test('Empty objects', () {
          expect(o(Parser(self, '()').parseLiteral()).slots, isEmpty);
          expect(o(Parser(self, '(||)').parseLiteral()).slots, isEmpty);
          expect(o(Parser(self, '(| |)').parseLiteral()).slots, isEmpty);
        });

        test('Enumerating slots', () {
          expect(Parser(self, '(| a |)').parseLiteral(), isNotNull);
          expect(Parser(self, '(| a. |)').parseLiteral(), isNotNull);
          expect(Parser(self, '(| a. b |)').parseLiteral(), isNotNull);
          expect(Parser(self, '(| a. b. |)').parseLiteral(), isNotNull);
          expect(Parser(self, '(| a = 1 |)').parseLiteral(), isNotNull);
          expect(Parser(self, '(| a = 1. |)').parseLiteral(), isNotNull);
          expect(Parser(self, '(| a = 1. b = 2 |)').parseLiteral(), isNotNull);
          expect(Parser(self, '(| a = 1. b = 2. |)').parseLiteral(), isNotNull);
          expect(Parser(self, '(| a <- 1 |)').parseLiteral(), isNotNull);
          expect(Parser(self, '(| a <- 1. |)').parseLiteral(), isNotNull);
          expect(Parser(self, '(| a <- 1. b <- 2 |)').parseLiteral(), isNotNull);
          expect(Parser(self, '(| a <- 1. b <- 2. |)').parseLiteral(), isNotNull);
        });

        test('Constant slot', () {
          final obj = o(Parser(self, '(| ab = 1 |)').parseLiteral());
          expect(obj.slots[0].name, 'ab');
          expect(obj.slots[0].value, 1);
          expect(obj.slots[0].parent, false);
          expect(obj.slots[0].argument, false);
          expect(obj.slots[0].data, false);
        });

        test('Data slot', () {
          final obj = o(Parser(self, '(| ab <- 2 |)').parseLiteral());
          expect(obj.slots[0].name, 'ab');
          expect(obj.slots[0].value, 2);
          expect(obj.slots[0].parent, false);
          expect(obj.slots[0].argument, false);
          expect(obj.slots[0].data, true);
          expect(obj.slots[1].name, 'ab:');
          expect(obj.slots[1].parent, false);
          expect(obj.slots[1].data, false);
        });

        test('Empty data slot', () {
          final obj = o(Parser(self, '(| ab |)').parseLiteral());
          expect(obj.slots[0].name, 'ab');
          expect(obj.slots[0].value, nil);
          expect(obj.slots[0].parent, false);
          expect(obj.slots[0].argument, false);
          expect(obj.slots[0].data, true);
          expect(obj.slots[1].name, 'ab:');
          expect(obj.slots[1].parent, false);
          expect(obj.slots[1].data, false);
        });

        test('Constant parent slot', () {
          final obj = o(Parser(self, '(| ab* = 1 |)').parseLiteral());
          expect(obj.slots[0].name, 'ab');
          expect(obj.slots[0].value, 1);
          expect(obj.slots[0].parent, true);
          expect(obj.slots[0].argument, false);
          expect(obj.slots[0].data, false);
        });

        test('Data parent slot', () {
          final obj = o(Parser(self, '(| ab* <- 2 |)').parseLiteral());
          expect(obj.slots[0].name, 'ab');
          expect(obj.slots[0].value, 2);
          expect(obj.slots[0].parent, true);
          expect(obj.slots[0].argument, false);
          expect(obj.slots[0].data, true);
          expect(obj.slots[1].name, 'ab:');
          expect(obj.slots[1].parent, false);
          expect(obj.slots[1].data, false);
        });

        test('Empty data parent slot', () {
          final obj = o(Parser(self, '(| ab* |)').parseLiteral());
          expect(obj.slots[0].name, 'ab');
          expect(obj.slots[0].value, nil);
          expect(obj.slots[0].parent, true);
          expect(obj.slots[0].argument, false);
          expect(obj.slots[0].data, true);
          expect(obj.slots[1].name, 'ab:');
          expect(obj.slots[1].parent, false);
          expect(obj.slots[1].data, false);
        });

        test('Argument slot', () {
          final obj = o(Parser(self, '(| :ab |)').parseLiteral());
          expect(obj.slots[0].name, 'ab');
          expect(obj.slots[0].value, nil);
          expect(obj.slots[0].parent, false);
          expect(obj.slots[0].argument, true);
          expect(obj.slots[0].data, false);
          expect(obj.slots.length, 1);
        });

        test('Argument parent slot', () {
          final obj = o(Parser(self, '(| :ab* |)').parseLiteral());
          expect(obj.slots[0].name, 'ab');
          expect(obj.slots[0].value, nil);
          expect(obj.slots[0].parent, true);
          expect(obj.slots[0].argument, true);
          expect(obj.slots[0].data, false);
          expect(obj.slots.length, 1);
        });

        group('Computed', () {
          setUp(self.initialize);

          test('Constant slot', () {
            final obj = o(Parser(self, '(| ab = true |)').parseLiteral());
            expect(obj.slots[0].name, 'ab');
            expect(obj.slots[0].value, same(self.trueObject));
          });

          test('Constant slot', () {
            final obj = o(Parser(self, '(| ab = (3 + 4) + 1 |)').parseLiteral());
            expect(obj.slots[0].name, 'ab');
            expect(obj.slots[0].value, 8);
          });

          test('Constant slot', () {
            final obj = o(Parser(self, '(| ab = (3 + 4) |)').parseLiteral());
            expect(obj.slots[0].name, 'ab');
            expect(obj.slots[0].value, isA<SelfMethod>());
          });

          test('Data slot', () {
            final obj = o(Parser(self, '(| ab <- true |)').parseLiteral());
            expect(obj.slots[0].name, 'ab');
            expect(obj.slots[0].value, same(self.trueObject));
          });

          test('Data slot', () {
            final obj = o(Parser(self, '(| ab <- (3 + 4) + 1 |)').parseLiteral());
            expect(obj.slots[0].name, 'ab');
            expect(obj.slots[0].value, 8);
          });

          test('Data slot', () {
            final obj = o(Parser(self, '(| ab <- (3 + 4) |)').parseLiteral());
            expect(obj.slots[0].name, 'ab');
            expect(obj.slots[0].value, 7);
          });
        });
      });

      group('Blocks:', () {
        test('Empty', () {
          for (final source in ['[]', '[||]', '[| |]']) {
            final obj = o(Parser(self, source).parseLiteral());
            expect(obj.slots[0].name, 'parent');
            expect(obj.slots[0].value, self.traitsBlock);
            expect(obj.slots[0].parent, true);
            expect(obj.slots[1].name, 'lexicalParent');
            expect(obj.slots[2].name, 'value');
            expect(obj.slots[2].value, isA<SelfMethod>());
          }
        });

        test('With arguments', () {
          final obj = o(Parser(self, '[| :a. :b. |]').parseLiteral());
          expect(obj.slots[0].name, 'parent');
          expect(obj.slots[0].value, self.traitsBlock);
          expect(obj.slots[0].parent, true);
          expect(obj.slots[1].name, 'lexicalParent');
          expect(obj.slots[2].name, 'value:With:');
          expect(obj.slots[2].value, isA<SelfMethod>());
        });
      });
    });

    group('Messages:', () {
      group('Implicit:', () {
        test('Single unary', () {
          expect(Parser(self, 'a').parseMessage().toString(), '{a null}');
        });

        test('Chained unary', () {
          expect(Parser(self, 'a b c').parseMessage().toString(), '{c {b {a null}}}');
        });

        test('Single binary', () {
          expect(Parser(self, '<< a').parseMessage().toString(), '{<< null {a null}}');
          expect(Parser(self, '<< a b').parseMessage().toString(), '{<< null {b {a null}}}');
        });

        test('Chained binary', () {
          expect(Parser(self, '<< a << b').parseMessage().toString(), '{<< {<< null {a null}} {b null}}');
          expect(Parser(self, '<< a b << b c').parseMessage().toString(), '{<< {<< null {b {a null}}} {c {b null}}}');
        });

        test('Single keyword', () {
          expect(Parser(self, 'a: 1').parseMessage().toString(), '{a: null 1}');
          expect(Parser(self, 'a: << 1').parseMessage().toString(), '{a: null {<< null 1}}');
          expect(Parser(self, 'a: 1 a').parseMessage().toString(), '{a: null {a 1}}');
        });

        test('Multiple keywords', () {
          expect(Parser(self, 'a: 1 B: 2 C: 3').parseMessage().toString(), '{a:B:C: null 1 2 3}');
        });
      });

      group('Explicit:', () {
        test('Single unary', () {
          expect(Parser(self, '1 negate').parseMessage().toString(), '{negate 1}');
        });

        test('Single binary', () {
          expect(Parser(self, '1 + 2').parseMessage().toString(), '{+ 1 2}');
        });

        test('Chained binary', () {
          expect(Parser(self, '1 + 2 + 3').parseMessage().toString(), '{+ {+ 1 2} 3}');
        });

        test('Single keyword', () {
          expect(Parser(self, '1 ab: 2').parseMessage().toString(), '{ab: 1 2}');
          expect(Parser(self, '1 ab: 2+3').parseMessage().toString(), '{ab: 1 {+ 2 3}}');
          expect(Parser(self, '1 ab: 2 a').parseMessage().toString(), '{ab: 1 {a 2}}');
        });

        test('Multiple keywords', () {
          expect(Parser(self, '1 a: 2 B: 3 C: 4').parseMessage().toString(), '{a:B:C: 1 2 3 4}');
        });
      });

      test('Parenthesized messages', () {
        expect(Parser(self, '(1 + 2) * 3').parseMessage().toString(), '{* (|  | {+ 1 2} ) 3}');
        expect(Parser(self, '1 + (2 * 3)').parseMessage().toString(), '{+ 1 (|  | {* 2 3} )}');
      });

      test('Not a message', () {
        expect(Parser(self, '()').parseMessage().toString(), '(|  |)');
        expect(Parser(self, '(||)').parseMessage().toString(), '(|  |)');
        expect(Parser(self, '(| |)').parseMessage().toString(), '(|  |)');
      });
    });

    group('Errors:', () {
      final throwsSyntaxError = throwsA(startsWith('SyntaxError:'));

      test('Garbage at the end', () {
        expect(() => Parser(self, '1 2').parse(), throwsSyntaxError);
      });
      test('Not a literal', () {
        expect(() => Parser(self, '').parseLiteral(), throwsSyntaxError);
        expect(() => Parser(self, 'foo').parseLiteral(), throwsSyntaxError);
        expect(() => Parser(self, '+ bar').parseLiteral(), throwsSyntaxError);
        expect(() => Parser(self, 'foo: 1').parseLiteral(), throwsSyntaxError);
        expect(() => Parser(self, '|').parseLiteral(), throwsSyntaxError);
        expect(() => Parser(self, ':').parseLiteral(), throwsSyntaxError);
        expect(() => Parser(self, '.').parseLiteral(), throwsSyntaxError);
        expect(() => Parser(self, '^').parseLiteral(), throwsSyntaxError);
      });
      test('Missing ) in object', () {
        expect(() => Parser(self, '(').parseObject(), throwsSyntaxError);
        expect(() => Parser(self, '(a').parseObject(), throwsSyntaxError);
        expect(() => Parser(self, '(|a|').parseObject(), throwsSyntaxError);
        expect(() => Parser(self, '(|a| b').parseObject(), throwsSyntaxError);
      });
      test('Missing ] in block', () {
        expect(() => Parser(self, '[').parseBlock(), throwsSyntaxError);
        expect(() => Parser(self, '[a').parseBlock(), throwsSyntaxError);
        expect(() => Parser(self, '[|a|').parseBlock(), throwsSyntaxError);
        expect(() => Parser(self, '[|a| b').parseBlock(), throwsSyntaxError);
        expect(() => Parser(self, '[^1.').parseBlock(), throwsSyntaxError);
      });
      test('Missing | in slots', () {
        expect(() => Parser(self, '(|').parse(), throwsSyntaxError);
        expect(() => Parser(self, '(|a').parse(), throwsSyntaxError);
        expect(() => Parser(self, '(|a.').parse(), throwsSyntaxError);
        expect(() => Parser(self, '(|a. b = 1').parse(), throwsSyntaxError);
        expect(() => Parser(self, '[|').parse(), throwsSyntaxError);
        expect(() => Parser(self, '[|a').parse(), throwsSyntaxError);
        expect(() => Parser(self, '[|a.').parse(), throwsSyntaxError);
        expect(() => Parser(self, '[|a. b = 1').parse(), throwsSyntaxError);
      });
      test('Not a slot', () {
        expect(() => Parser(self, '(|').parse(), throwsSyntaxError);
        expect(() => Parser(self, '(|1|)').parse(), throwsSyntaxError);
        expect(() => Parser(self, "(|'1'|)").parse(), throwsSyntaxError);
        expect(() => Parser(self, '(|()|)').parse(), throwsSyntaxError);
        expect(() => Parser(self, '(|[]|)').parse(), throwsSyntaxError);
        expect(() => Parser(self, '(|.|)').parse(), throwsSyntaxError);
        expect(() => Parser(self, '(|^|)').parse(), throwsSyntaxError);
      });
      test('Inconsistent inline parameters', () {
        expect(() => Parser(self, '(|at: a Put: = ()|)').parse(), throwsSyntaxError);
        expect(() => Parser(self, '(|at: Put: b = ()|)').parse(), throwsSyntaxError);
      });
      test('<- used as method', () {
        expect(() => Parser(self, '(|foo: a <- 42|)').parse(), throwsSyntaxError);
      });
    });
  });

  group('Runtime:', () {
    setUp(self.initialize);

    test('Sending a message', () {
      expect(self.send('lobby', [self.lobby]), same(self.lobby));
    });

    test('Accessing the lobby', () {
      expect(self.execute('lobby'), same(self.lobby));
      expect(self.execute('(|x = lobby|) x'), same(self.lobby));
      expect(self.execute('(|x = (lobby). p* = lobby|) x'), same(self.lobby));
    });

    test('Accessing nil', () {
      expect(self.execute('nil'), same(nil));
      expect(self.execute('lobby nil'), same(nil));
      expect(self.execute('lobby globals nil'), same(nil));
      expect(self.execute('(|x = (nil). p* = lobby|) x'), same(nil));
    });

    test('Accessing true', () {
      expect(self.execute('true'), same(self.trueObject));
      expect(self.execute('lobby true'), same(self.trueObject));
      expect(self.execute('lobby globals true'), same(self.trueObject));
      expect(self.execute('(|x = true|) x'), same(self.trueObject));
      expect(self.execute('(|x = (true). p* = lobby|) x'), same(self.trueObject));
    });

    test('Accessing false', () {
      expect(self.execute('false'), same(self.falseObject));
      expect(self.execute('lobby false'), same(self.falseObject));
      expect(self.execute('lobby globals false'), same(self.falseObject));
      expect(self.execute('(|x = false|) x'), same(self.falseObject));
      expect(self.execute('(|x = (false). p* = lobby|) x'), same(self.falseObject));
    });

    test('Accessing traits', () {
      expect(self.execute('traits block'), same(self.traitsBlock));
      expect(self.execute('traits number'), same(self.traitsNumber));
      expect(self.execute('traits string'), same(self.traitsString));
      expect(self.execute('traits vector'), same(self.traitsVector));
    });

    test('Cloning', () {
      expect(self.execute('nil clone'), same(nil));
      expect(self.execute('true clone'), same(self.trueObject));
      expect(self.execute('false clone'), same(self.falseObject));
      expect(self.execute('42 clone'), 42);
      expect(self.execute('-47.11 clone'), -47.11);
      expect(self.execute("'42' clone"), '42');
      expect(self.execute('traits vector clone'), isNot(same(self.traitsVector)));
      expect(self.execute('traits vector clone'), <SelfValue>[]);
      expect(self.execute('traits vector clone: 2'), <SelfValue>[nil, nil]);
      final obj = SelfObject([]);
      self.lobby.addSlotIfAbsent(Slot.c('t', obj));
      expect(self.execute('t _Clone'), isNot(same(obj)));
      expect(self.execute('t _Clone'), isA<SelfObject>());
    });

    test('Arithmetic operations on numbers', () {
      expect(self.execute('3 + 4'), 7);
      expect(self.execute('4 - 3'), 1);
      expect(self.execute('2 * 3'), 6);
      expect(self.execute('1 / 2'), 0.5);
      expect(self.execute('9 % 5'), 4);
      expect(self.execute('3 negate'), -3);
    });

    test('Relational operations on numbers', () {
      expect(self.execute('3 < 4'), self.trueObject);
      expect(self.execute('4 < 4'), self.falseObject);
      expect(self.execute('4 < 3'), self.falseObject);
      expect(self.execute('3 > 4'), self.falseObject);
      expect(self.execute('4 > 4'), self.falseObject);
      expect(self.execute('4 > 3'), self.trueObject);
      expect(self.execute('3 <= 4'), self.trueObject);
      expect(self.execute('4 <= 4'), self.trueObject);
      expect(self.execute('4 <= 3'), self.falseObject);
      expect(self.execute('3 >= 4'), self.falseObject);
      expect(self.execute('4 >= 4'), self.trueObject);
      expect(self.execute('4 >= 3'), self.trueObject);
    });

    test('Compare operations on numbers', () {
      expect(self.execute('3 = 4'), self.falseObject);
      expect(self.execute('4 = 4'), self.trueObject);
      expect(self.execute('3 != 4'), self.trueObject);
      expect(self.execute('4 != 4'), self.falseObject);
    });

    test('Adding parenthesized numbers', () {
      expect(self.execute('1 + 2 * 3'), 9.0);
      expect(self.execute('(1 + 2) * 3'), 9.0);
      expect(self.execute('1 + (2 * 3)'), 7.0);
      expect(self.execute('(1 + 2) * (3 - 4)'), -3);
      expect(self.execute('((1 + 2) * (3 - 4))'), -3);
    });

    test('Compare operations on strings', () {
      expect(self.execute("'3' = '4'"), self.falseObject);
      expect(self.execute("'4' = '4'"), self.trueObject);
      expect(self.execute("'3' != '4'"), self.trueObject);
      expect(self.execute("'4' != '4'"), self.falseObject);
    });

    test('Other perations on strings', () {
      expect(self.execute("'abc' size"), 3);
      expect(self.execute("'abc' at: 1"), 'b');
      expect(self.execute("'ab' , 'c'"), 'abc');
      expect(self.execute("'abc' from: 1 To: 2"), 'b');
    });

    group('Blocks:', () {
      test('Evaluating an empty block', () {
        expect(self.execute('[] value'), nil);
      });

      test('Evaluating a block', () {
        expect(self.execute('[3] value'), 3);
        expect(self.execute('[true] value'), self.trueObject);
      });

      test('Evaluating a block with an argument', () {
        expect(self.execute('[|:a| a] value: 2'), 2);
      });

      test('Evaluating a block with a closure', () {
        expect(self.execute('[|:a| [a] value] value: 2'), 2);
        expect(self.execute('(|m: a = ([a] value)|) m: 2'), 2);
      });

      test('Evaluating a block with a closure referencing self', () {
        expect(self.execute('(| x = 13. m = ([self x] value) |) m'), 13);
        expect(self.execute('(| x = 13. m = ([x] value) |) m'), 13); // is this correct?
        expect(self.execute('(| x = 13. b: block = (block value). m = (self b: [self x]) |) m'), 13);
      });
    });

    test('Assign a method argument', () {
      expect(self.execute('(| << a = (a) |) << 2'), 2);
      expect(self.execute('(| << = (|:a| a) |) << 2'), 2);
      expect(self.execute('(| << = (|:self. :a| a) |) << 2'), 2);

      expect(self.execute('(| m: a = (a) |) m: 3'), 3);
      expect(self.execute('(| m: = (|:a| a) |) m: 3'), 3);
      expect(self.execute('(| m: = (|:self*. :a| a) |) m: 1+2'), 3);

      expect(self.execute('(| m: a n: b = (a + b) |) m: 3 n: 4'), 7);
    });

    test('Return a local slot', () {
      expect(self.execute('(| m = (|s = 1| s) |) m'), 1);
    });

    test('Assign a local slot', () {
      expect(self.execute('(| m = (|s| s: 1. s) |) m'), 1);
    });

    test('Implicit self should work', () {
      expect(self.execute('''
      traits vector _AddSlotsIfAbsent: (|
        clone2: size = (_VectorClone: size).
        clone2 = (clone2: 0)
      |).
      traits vector clone2'''), isList);
      expect(self.execute('traits vector clone'), isList);
    });

    test('Simple if', () {
      expect(self.execute('true ifTrue: [5]'), 5);
      expect(self.execute('false ifTrue: [5]'), nil);
      expect(self.execute('true ifFalse: [5]'), nil);
      expect(self.execute('false ifFalse: [5]'), 5);
    });

    test('If-then-else', () {
      expect(self.execute('true ifTrue: [5] False: [6]'), 5);
      expect(self.execute('false ifTrue: [5] False: [6]'), 6);
    });

    test('While loop', () {
      expect(self.execute('(| x <- 0. m = ([x = 3] whileFalse: [x: x + 1]. x) |) m'), 3);
    });

    group('Vector', () {
      test('clone', () {
        expect(self.execute('traits vector clone'), <SelfObject>[]);
        expect(self.execute('traits vector clone: 1'), <SelfObject>[nil]);
      });

      test('size', () {
        expect(self.execute('traits vector clone size'), 0);
      });
      test('at/put', () {
        expect(
            self.execute(
                '(| parent* = lobby. v <- traits vector clone: 2. m = (v at: 0 Put: true. v at: 1 Put: false. v) |) m'),
            <SelfObject>[self.trueObject, self.falseObject]);
      });

      test('from/to', () {
        expect(self.execute('(traits vector clone: 3) from: 1 To: 1'), <SelfObject>[]);
      });
    });

    test('Vector builder', () {
      expect(self.execute('(| m = (1 & 2) |) m'), [1, 2]);
      expect(self.execute('(| m = (1 & 2 & 3) |) m'), [1, 2, 3]);
      expect(self.execute('(| m = (1 & 2 & 3 & 4) |) m printString'), '(1, 2, 3, 4)');
    });

    test('Do loop', () {
      expect(self.execute('(| m = (| x <- traits vector clone: 2 | x at: 0 Put: 3. x at: 1 Put: 4. x ) |) m'), [3, 4]);
      expect(
          self.execute(
              '(| m = (| x <- traits vector clone: 2. s | x at: 0 Put: 3. x at: 1 Put: 4. s: 0. x do: [|:each| s: s + each]. s) |) m'),
          7);
    });

    test('Select loop', () {
      expect(
          self.execute(
              '(| m = (| x <- traits vector clone: 2 | x at: 0 Put: 3. x at: 1 Put: 4. x select: [|:each| each < 4]) |) m'),
          [3]);
    });

    test('Collect loop', () {
      expect(
          self.execute(
              '(| m = (| x <- traits vector clone: 2 | x at: 0 Put: 3. x at: 1 Put: 4. x collect: [|:each| each + 1]) |) m'),
          [4, 5]);
    });

    test('For loop', () {
      expect( self.execute('(| m = (|sum<-0| 1 to: 10 Do: [|:i| sum: sum + i]. sum) |) m'), 55);
    });

    test('Non-local return', () {
      expect(self.execute('(| m = ([^42] value. 1) |) m'), 42);
      expect(self.execute('(| m = ([[^42] value. 2] value. 1) |) m'), 42);
    });
  });

  test('Factorial example', () {
    self.initialize();
    self.execute('''
traits number _AddSlotsIfAbsent:(| 
  factorial = (
    self = 0 ifTrue: [^1]. 
    (self - 1) factorial * self
  ) 
|).
''');
    expect(self.send('factorial', [0]), 1);
    expect(self.send('factorial', [6]), 720);
    expect(self.send('factorial', [25]), 7034535277573963776);
  });

  test('Fibonacci example', () {
    self.initialize();
    self.execute('''
traits number _AddSlotsIfAbsent:(|
  fibonacci = (
    self < 3 ifTrue: [^1]. 
    (self - 1) fibonacci + (self - 2) fibonacci
  )
|).
''');
    expect(self.send('fibonacci', [1]), 1);
    expect(self.send('fibonacci', [2]), 1);
    expect(self.send('fibonacci', [3]), 2);
    expect(self.send('fibonacci', [25]), 75025);
  });
}
