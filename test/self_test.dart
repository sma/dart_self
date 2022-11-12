import 'package:self/self.dart';
import 'package:test/test.dart';

SelfObject o(SelfValue v) => v as SelfObject;

final nil = Self.nilObject;

void main() {
  group('Self object:', () {
    test('Access a slot value', () {
      var obj = SelfObject([Slot.c('a', 1)]);
      expect(Self.findSlot(obj, 'a').value, 1);
    });

    test('Access a slot value in parent object', () {
      var obj1 = SelfObject([Slot.c('a', 1)]);
      var obj2 = SelfObject([Slot.c('p', obj1, parent: true)]);
      expect(Self.findSlot(obj2, 'a').value, 1);
    });

    test('Access a slot value in parent object without endless loop', () {
      var obj1 = SelfObject([Slot.c('b', nil, parent: true), Slot.c('a', 1)]);
      var obj2 = SelfObject([Slot.c('p', obj1, parent: true)]);
      obj1.slots[0].value = obj2;
      expect(Self.findSlot(obj2, 'a').value, 1);
    });

    test('Access an unknown slot value', () {
      var obj = SelfObject([Slot.c('a', 1)]);
      expect(() => Self.findSlot(obj, 'b'), throwsA('UnknownMessageSend(b)'));
    });

    test('Access an ambiguous slot value', () {
      var obj1 = SelfObject([Slot.c('a', 1)]);
      var obj2 = SelfObject([Slot.c('a', 2)]);
      var obj3 = SelfObject([Slot.c('p1', obj1, parent: true), Slot.c('p2', obj2, parent: true)]);
      expect(() => Self.findSlot(obj3, 'a'), throwsA('AmbiguousMessageSend(a)'));
    });

    test('Cloning an object', () {
      var obj1 = SelfObject([Slot.a("a", 1), Slot.d("b", 2)]);
      var obj2 = obj1.clone();
      obj2.slots[0].value = 3;
      obj2.slots[1].value = 4;
      expect(obj1.slots[0].value, 1);
      expect(obj1.slots[1].value, 2);
    });

    test('Add a slot', () {
      var obj = SelfObject([]);
      obj.addSlotIfAbsent(Slot.c('a', nil));
      expect(obj.slots.length, 1);
      expect(obj.slots[0].name, 'a');
    });

    test('Add a data slot', () {
      var obj = SelfObject([]);
      obj.addSlotIfAbsent(Slot.d('a', nil));
      expect(obj.slots.length, 2);
      expect(obj.slots[0].name, 'a');
      expect(obj.slots[1].name, 'a:');
    });

    test('Remove a slot', () {
      var obj = SelfObject([Slot.c('x', 1)]);
      obj.removeSlotNamed('x');
      expect(obj.slots.length, 0);
    });

    test('Remove a data slot', () {
      var obj = SelfObject([Slot.c('x', 1), Slot.m('x')]);
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
      expect(SelfMethod([], []).execute(), nil);
    });

    test('Return the last expression', () {
      expect(SelfMethod([], [Lit(41)]).execute(), 41);
      expect(SelfMethod([], [Lit(42), Lit(41)]).execute(), 41);
    });

    test('Access an argument slot', () {
      expect(SelfMethod([Slot.c('a', 1)], [Msg(null, 'a', [])]).execute(), 1);
    });

    test('Access an instance slot', () {
      var inst = SelfObject([Slot.c('b', 2)]);
      var meth = SelfMethod([Slot.c('self', inst, parent: true), Slot.c('a', 1)], [Msg(null, 'b', [])]);
      expect(meth.execute(), 2);
    });

    test('Send a primitive message', () {
      Self.primitives = {
        '_Add:': (a) => (a[0] as int) + (a[1] as int),
        '_Sub:': (a) => (a[0] as int) - (a[1] as int),
      };
      expect(
          SelfMethod([], [
            Msg(Lit(3), '_Add:', [Lit(4)])
          ]).execute(),
          7);
      expect(
          SelfMethod([], [
            Msg(Lit(4), '_Sub:', [Lit(3)])
          ]).execute(),
          1);
    });

    test('Printstring', () {
      expect(SelfMethod([], []).toString(), '(|  |  )');
    });
  });

  group('Code:', () {
    test('Literal objects', () {
      var a = SelfObject([]);
      expect(Lit(1).execute(a), 1);
      expect(Lit(1.1).execute(a), 1.1);
      expect(Lit('a').execute(a), 'a');
      expect(Lit(nil).execute(a), nil);
      expect(Lit(true).execute(a), true);
      expect(Lit(false).execute(a), false);
      var obj = SelfObject([]);
      expect(Lit(obj).execute(a), same(obj));
    });

    test('Literal methods', () {
      var a = SelfObject([]);
      var meth = SelfMethod([], [Lit(1)]);
      expect(Mth(Lit(meth)).execute(a), 1);
    });

    test('Literal blocks', () {
      var a = SelfObject([]);
      var m = SelfMethod([Slot.a("(parent)", nil, parent: true)], [Lit(1)]);
      var b = SelfObject(
          [Slot.c("parent", Self.traitsBlock, parent: true), Slot.a("(lexicalParent)", nil), Slot.c("value", m)]);
      var rslt = o(Blk(b).execute(a));
      expect(rslt.slots[0].value, Self.traitsBlock);
      expect(rslt.slots[1].value, same(a));
      expect(rslt.slots[2].value, same(m));
    });

    test('Implicit message send', () {
      var a = SelfObject([Slot.d('a', 1), Slot.m('a')]);
      expect(Msg(null, 'a', []).execute(a), 1);
      var b = SelfObject([Slot.c('p', a, parent: true)]);
      expect(Msg(null, 'a', []).execute(b), 1);
      expect(Msg(null, 'a:', [Lit(2)]).execute(b), 2);
      expect(Self.findSlot(a, 'a').value, 2);
    });

    test('Explicit message send', () {
      var a = SelfObject([Slot.c('o', nil)]);
      var obj1 = SelfObject([Slot.c('a', 1)]);
      a.slots[0].value = obj1;
      expect(Msg(Msg(null, 'o', []), 'a', []).execute(a), 1);
      var obj2 = SelfObject([Slot.c('p', obj1, parent: true)]);
      a.slots[0].value = obj2;
      expect(Msg(Msg(null, 'o', []), 'a', []).execute(a), 1);
    });

    test('Unknown primitive message send', () {
      expect(() => Msg(null, '_Qux', []).execute(nil), throwsA('UnknownPrimitive(_Qux)'));
    });

    test('Missing mutator message send', () {
      var a = SelfObject([Slot.m('a')]);
      expect(() => Msg(null, 'a:', [Lit(nil)]).execute(a), throwsA('MutatorWithoutDataSlot(a:)'));
    });
  });

  group('Parser:', () {
    group('Literals:', () {
      test('Numbers', () {
        expect(Parser('1').parseLiteral(), 1);
        expect(Parser('1.23').parseLiteral(), 1.23);
        expect(Parser('-4').parseLiteral(), -4);
        expect(Parser('-4.11').parseLiteral(), -4.11);
      });

      test('Strings', () {
        expect(Parser("''").parseLiteral(), '');
        expect(Parser("'1.23'").parseLiteral(), '1.23');
        expect(Parser("'\\b\\f\\n\\r\\t\\u20AC\\'\\\\'").parseLiteral(), '\b\f\n\r\t\u20AC\'\\');
      });

      group('Objects:', () {
        test('Empty objects', () {
          expect(o(Parser("()").parseLiteral()).slots, isEmpty);
          expect(o(Parser("(| |)").parseLiteral()).slots, isEmpty);
        });

        test('Enumerating slots', () {
          expect(Parser("(| a |)").parseLiteral(), isNotNull);
          expect(Parser("(| a. |)").parseLiteral(), isNotNull);
          expect(Parser("(| a. b |)").parseLiteral(), isNotNull);
          expect(Parser("(| a. b. |)").parseLiteral(), isNotNull);
          expect(Parser("(| a = 1 |)").parseLiteral(), isNotNull);
          expect(Parser("(| a = 1. |)").parseLiteral(), isNotNull);
          expect(Parser("(| a = 1. b = 2 |)").parseLiteral(), isNotNull);
          expect(Parser("(| a = 1. b = 2. |)").parseLiteral(), isNotNull);
          expect(Parser("(| a <- 1 |)").parseLiteral(), isNotNull);
          expect(Parser("(| a <- 1. |)").parseLiteral(), isNotNull);
          expect(Parser("(| a <- 1. b <- 2 |)").parseLiteral(), isNotNull);
          expect(Parser("(| a <- 1. b <- 2. |)").parseLiteral(), isNotNull);
        });

        test('Constant slot', () {
          final obj = o(Parser("(| ab = 1 |)").parseLiteral());
          expect(obj.slots[0].name, 'ab');
          expect(obj.slots[0].value, 1);
          expect(obj.slots[0].parent, false);
          expect(obj.slots[0].argument, false);
          expect(obj.slots[0].data, false);
        });

        test('Data slot', () {
          final obj = o(Parser("(| ab <- 2 |)").parseLiteral());
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
          final obj = o(Parser("(| ab |)").parseLiteral());
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
          final obj = o(Parser("(| ab* = 1 |)").parseLiteral());
          expect(obj.slots[0].name, 'ab');
          expect(obj.slots[0].value, 1);
          expect(obj.slots[0].parent, true);
          expect(obj.slots[0].argument, false);
          expect(obj.slots[0].data, false);
        });

        test('Data parent slot', () {
          final obj = o(Parser("(| ab* <- 2 |)").parseLiteral());
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
          final obj = o(Parser("(| ab* |)").parseLiteral());
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
          final obj = o(Parser("(| :ab |)").parseLiteral());
          expect(obj.slots[0].name, 'ab');
          expect(obj.slots[0].value, nil);
          expect(obj.slots[0].parent, false);
          expect(obj.slots[0].argument, true);
          expect(obj.slots[0].data, false);
          expect(obj.slots.length, 1);
        });

        test('Argument parent slot', () {
          final obj = o(Parser("(| :ab* |)").parseLiteral());
          expect(obj.slots[0].name, 'ab');
          expect(obj.slots[0].value, nil);
          expect(obj.slots[0].parent, true);
          expect(obj.slots[0].argument, true);
          expect(obj.slots[0].data, false);
          expect(obj.slots.length, 1);
        });

        group('Computed', () {
          setUp(() => Self.initialize());

          test('Constant slot', () {
            final obj = o(Parser("(| ab = true |)").parseLiteral());
            expect(obj.slots[0].name, 'ab');
            expect(obj.slots[0].value, same(Self.trueObject));
          });

          test('Constant slot', () {
            final obj = o(Parser("(| ab = (3 + 4) + 1 |)").parseLiteral());
            expect(obj.slots[0].name, 'ab');
            expect(obj.slots[0].value, 8);
          });

          test('Constant slot', () {
            final obj = o(Parser("(| ab = (3 + 4) |)").parseLiteral());
            expect(obj.slots[0].name, 'ab');
            expect(obj.slots[0].value, isA<SelfMethod>());
          });

          test('Data slot', () {
            final obj = o(Parser("(| ab <- true |)").parseLiteral());
            expect(obj.slots[0].name, 'ab');
            expect(obj.slots[0].value, same(Self.trueObject));
          });

          test('Data slot', () {
            final obj = o(Parser("(| ab <- (3 + 4) + 1 |)").parseLiteral());
            expect(obj.slots[0].name, 'ab');
            expect(obj.slots[0].value, 8);
          });

          test('Data slot', () {
            final obj = o(Parser("(| ab <- (3 + 4) |)").parseLiteral());
            expect(obj.slots[0].name, 'ab');
            expect(obj.slots[0].value, 7);
          });
        });
      });

      group('Blocks:', () {
        test('Empty', () {
          final obj = o(Parser("[]").parseLiteral());
          expect(obj.slots[0].name, 'parent');
          expect(obj.slots[0].value, Self.traitsBlock);
          expect(obj.slots[0].parent, true);
          expect(obj.slots[1].name, 'lexicalParent');
          expect(obj.slots[2].name, 'value');
          expect(obj.slots[2].value, isA<SelfMethod>());
        });

        test('With arguments', () {
          final obj = o(Parser("[| :a. :b. |]").parseLiteral());
          expect(obj.slots[0].name, 'parent');
          expect(obj.slots[0].value, Self.traitsBlock);
          expect(obj.slots[0].parent, true);
          expect(obj.slots[1].name, 'lexicalParent');
          expect(obj.slots[2].name, 'value:With:');
          expect(obj.slots[2].value, isA<SelfMethod>());
        });
      });
    });

    group("Messages:", () {
      group("Implicit:", () {
        test("Single unary", () {
          expect(Parser("a").parseMessage().toString(), "{a null}");
        });

        test("Chained unary", () {
          expect(Parser("a b c").parseMessage().toString(), "{c {b {a null}}}");
        });

        test("Single binary", () {
          expect(Parser("<< a").parseMessage().toString(), "{<< null {a null}}");
          expect(Parser("<< a b").parseMessage().toString(), "{<< null {b {a null}}}");
        });

        test("Chained binary", () {
          expect(Parser("<< a << b").parseMessage().toString(), "{<< {<< null {a null}} {b null}}");
          expect(Parser("<< a b << b c").parseMessage().toString(), "{<< {<< null {b {a null}}} {c {b null}}}");
        });

        test("Single keyword", () {
          expect(Parser("a: 1").parseMessage().toString(), "{a: null 1}");
          expect(Parser("a: << 1").parseMessage().toString(), "{a: null {<< null 1}}");
          expect(Parser("a: 1 a").parseMessage().toString(), "{a: null {a 1}}");
        });

        test("Multiple keywords", () {
          expect(Parser("a: 1 B: 2 C: 3").parseMessage().toString(), "{a:B:C: null 1 2 3}");
        });
      });

      group("Explicit:", () {
        test("Single unary", () {
          expect(Parser("1 negate").parseMessage().toString(), "{negate 1}");
        });

        test("Single binary", () {
          expect(Parser("1 + 2").parseMessage().toString(), "{+ 1 2}");
        });

        test("Chained binary", () {
          expect(Parser("1 + 2 + 3").parseMessage().toString(), "{+ {+ 1 2} 3}");
        });

        test("Single keyword", () {
          expect(Parser("1 ab: 2").parseMessage().toString(), "{ab: 1 2}");
          expect(Parser("1 ab: 2+3").parseMessage().toString(), "{ab: 1 {+ 2 3}}");
          expect(Parser("1 ab: 2 a").parseMessage().toString(), "{ab: 1 {a 2}}");
        });

        test("Multiple keywords", () {
          expect(Parser("1 a: 2 B: 3 C: 4").parseMessage().toString(), "{a:B:C: 1 2 3 4}");
        });
      });

      test('Parenthesized messages', () {
        // expect(new Parser("(1 + 2) * 3").parseMessage().toString(), "(* (+ <1> <2> <3>))");
        // expect(new Parser("1 + (2 * 3)").parseMessage().toString(), "(+ <1> (* <2> <3>))");
      });
    });

    group("Errors:", () {
      final throwsSyntaxError = throwsA(startsWith('SyntaxError:'));

      test("Garbage at the end", () {
        expect(() => Parser("1 2").parse(), throwsSyntaxError);
      });
      test("Not a literal", () {
        expect(() => Parser("").parseLiteral(), throwsSyntaxError);
        expect(() => Parser("foo").parseLiteral(), throwsSyntaxError);
        expect(() => Parser("+ bar").parseLiteral(), throwsSyntaxError);
        expect(() => Parser("foo: 1").parseLiteral(), throwsSyntaxError);
        expect(() => Parser("|").parseLiteral(), throwsSyntaxError);
        expect(() => Parser(":").parseLiteral(), throwsSyntaxError);
        expect(() => Parser(".").parseLiteral(), throwsSyntaxError);
        expect(() => Parser("^").parseLiteral(), throwsSyntaxError);
      });
      test("Missing ) in object", () {
        expect(() => Parser("(").parseObject(), throwsSyntaxError);
        expect(() => Parser("(a").parseObject(), throwsSyntaxError);
        expect(() => Parser("(|a|").parseObject(), throwsSyntaxError);
        expect(() => Parser("(|a| b").parseObject(), throwsSyntaxError);
      });
      test("Missing ] in block", () {
        expect(() => Parser("[").parseBlock(), throwsSyntaxError);
        expect(() => Parser("[a").parseBlock(), throwsSyntaxError);
        expect(() => Parser("[|a|").parseBlock(), throwsSyntaxError);
        expect(() => Parser("[|a| b").parseBlock(), throwsSyntaxError);
        expect(() => Parser("[^1.").parseBlock(), throwsSyntaxError);
      });
      test("Missing | in slots", () {
        expect(() => Parser("(|").parse(), throwsSyntaxError);
        expect(() => Parser("(|a").parse(), throwsSyntaxError);
        expect(() => Parser("(|a.").parse(), throwsSyntaxError);
        expect(() => Parser("(|a. b = 1").parse(), throwsSyntaxError);
        expect(() => Parser("[|").parse(), throwsSyntaxError);
        expect(() => Parser("[|a").parse(), throwsSyntaxError);
        expect(() => Parser("[|a.").parse(), throwsSyntaxError);
        expect(() => Parser("[|a. b = 1").parse(), throwsSyntaxError);
      });
      test("Not a slot", () {
        expect(() => Parser("(|").parse(), throwsSyntaxError);
        expect(() => Parser("(|1|)").parse(), throwsSyntaxError);
        expect(() => Parser("(|'1'|)").parse(), throwsSyntaxError);
        expect(() => Parser("(|()|)").parse(), throwsSyntaxError);
        expect(() => Parser("(|[]|)").parse(), throwsSyntaxError);
        expect(() => Parser("(|.|)").parse(), throwsSyntaxError);
        expect(() => Parser("(|^|)").parse(), throwsSyntaxError);
      });
      test("Inconsistent inline parameters", () {
        expect(() => Parser("(|at: a Put: = ()|)").parse(), throwsSyntaxError);
        expect(() => Parser("(|at: Put: b = ()|)").parse(), throwsSyntaxError);
      });
      test("<- used as method", () {
        expect(() => Parser("(|foo: a <- 42|)").parse(), throwsSyntaxError);
      });
    });
  });

  group('Runtime:', () {
    setUp(Self.initialize);

    test('Sending a message', () {
      expect(Self.send('lobby', [Self.lobby]), same(Self.lobby));
    });

    test('Accessing the lobby', () {
      expect(Self.execute('lobby'), same(Self.lobby));
      expect(Self.execute('(|x = lobby|) x'), same(Self.lobby));
      expect(Self.execute('(|x = (lobby). p* = lobby|) x'), same(Self.lobby));
    });

    test('Accessing nil', () {
      expect(Self.execute('nil'), same(Self.nilObject));
      expect(Self.execute('lobby nil'), same(Self.nilObject));
      expect(Self.execute('lobby globals nil'), same(Self.nilObject));
      expect(Self.execute('(|x = (nil). p* = lobby|) x'), same(Self.nilObject));
    });

    test('Accessing true', () {
      expect(Self.execute('true'), same(Self.trueObject));
      expect(Self.execute('lobby true'), same(Self.trueObject));
      expect(Self.execute('lobby globals true'), same(Self.trueObject));
      expect(Self.execute('(|x = true|) x'), same(Self.trueObject));
      expect(Self.execute('(|x = (true). p* = lobby|) x'), same(Self.trueObject));
    });

    test('Accessing false', () {
      expect(Self.execute('false'), same(Self.falseObject));
      expect(Self.execute('lobby false'), same(Self.falseObject));
      expect(Self.execute('lobby globals false'), same(Self.falseObject));
      expect(Self.execute('(|x = false|) x'), same(Self.falseObject));
      expect(Self.execute('(|x = (false). p* = lobby|) x'), same(Self.falseObject));
    });

    test('Accessing traits', () {
      expect(Self.execute('traits block'), same(Self.traitsBlock));
      expect(Self.execute('traits number'), same(Self.traitsNumber));
      expect(Self.execute('traits string'), same(Self.traitsString));
      expect(Self.execute('traits vector'), same(Self.traitsVector));
    });

    test('Cloning', () {
      expect(Self.execute('nil clone'), same(Self.nilObject));
      expect(Self.execute('true clone'), same(Self.trueObject));
      expect(Self.execute('false clone'), same(Self.falseObject));
      expect(Self.execute('42 clone'), 42);
      expect(Self.execute('-47.11 clone'), -47.11);
      expect(Self.execute("'42' clone"), '42');
      expect(Self.execute("traits vector clone"), isNot(same(Self.traitsVector)));
      expect(Self.execute("traits vector clone"), <SelfValue>[]);
      expect(Self.execute("traits vector clone: 2"), <SelfValue>[nil, nil]);
      expect(Self.execute("(| |) _Clone"), isA<SelfObject>());
      // TODO expect(Self.execute("() _Clone"), isA<SelfMethod>());
    });

    test('Arithmetic operations on numbers', () {
      expect(Self.execute('3 + 4'), 7);
      expect(Self.execute('4 - 3'), 1);
      expect(Self.execute('2 * 3'), 6);
      expect(Self.execute('1 / 2'), 0.5);
      expect(Self.execute('9 % 5'), 4);
      expect(Self.execute('3 negate'), -3);
    });

    test('Relational operations on numbers', () {
      expect(Self.execute('3 < 4'), Self.trueObject);
      expect(Self.execute('4 < 4'), Self.falseObject);
      expect(Self.execute('4 < 3'), Self.falseObject);
      expect(Self.execute('3 > 4'), Self.falseObject);
      expect(Self.execute('4 > 4'), Self.falseObject);
      expect(Self.execute('4 > 3'), Self.trueObject);
      expect(Self.execute('3 <= 4'), Self.trueObject);
      expect(Self.execute('4 <= 4'), Self.trueObject);
      expect(Self.execute('4 <= 3'), Self.falseObject);
      expect(Self.execute('3 >= 4'), Self.falseObject);
      expect(Self.execute('4 >= 4'), Self.trueObject);
      expect(Self.execute('4 >= 3'), Self.trueObject);
    });

    test('Compare operations on numbers', () {
      expect(Self.execute('3 = 4'), Self.falseObject);
      expect(Self.execute('4 = 4'), Self.trueObject);
      expect(Self.execute('3 != 4'), Self.trueObject);
      expect(Self.execute('4 != 4'), Self.falseObject);
    });

    test('Adding parenthesized numbers', () {
      expect(Self.execute('1 + 2 * 3'), 9.0);
      expect(Self.execute('(1 + 2) * 3'), 9.0);
      expect(Self.execute('1 + (2 * 3)'), 7.0);
      expect(Self.execute('(1 + 2) * (3 - 4)'), -3);
      expect(Self.execute('((1 + 2) * (3 - 4))'), -3);
    });

    test('Compare operations on strings', () {
      expect(Self.execute("'3' = '4'"), Self.falseObject);
      expect(Self.execute("'4' = '4'"), Self.trueObject);
      expect(Self.execute("'3' != '4'"), Self.trueObject);
      expect(Self.execute("'4' != '4'"), Self.falseObject);
    });

    test('Other perations on strings', () {
      expect(Self.execute("'abc' size"), 3);
      expect(Self.execute("'abc' at: 1"), 'b');
      expect(Self.execute("'ab' , 'c'"), 'abc');
      expect(Self.execute("'abc' from: 1 To: 2"), 'b');
    });

    group('Blocks:', () {
      test('Evaluating an empty block', () {
        expect(Self.execute('[] value'), Self.nilObject);
      });

      test('Evaluating a block', () {
        expect(Self.execute('[3] value'), 3);
        expect(Self.execute('[true] value'), Self.trueObject);
      });

      test('Evaluating a block with an argument', () {
        expect(Self.execute('[|:a| a] value: 2'), 2);
      });

      test('Evaluating a block with a closure', () {
        expect(Self.execute('[|:a| [a] value] value: 2'), 2);
        expect(Self.execute('(|m: a = ([a] value)|) m: 2'), 2);
      });

      test('Evaluating a block with a closure referencing self', () {
        expect(Self.execute('(| x = 13. m = ([self x] value) |) m'), 13);
        expect(Self.execute('(| x = 13. m = ([x] value) |) m'), 13); // is this correct?
        expect(Self.execute('(| x = 13. b: block = (block value). m = (self b: [self x]) |) m'), 13);
      });
    });

    test('Assign a method argument', () {
      expect(Self.execute('(| << a = (a) |) << 2'), 2);
      expect(Self.execute('(| << = (|:a| a) |) << 2'), 2);
      expect(Self.execute('(| << = (|:self. :a| a) |) << 2'), 2);

      expect(Self.execute('(| m: a = (a) |) m: 3'), 3);
      expect(Self.execute('(| m: = (|:a| a) |) m: 3'), 3);
      expect(Self.execute('(| m: = (|:self*. :a| a) |) m: 1+2'), 3);

      expect(Self.execute('(| m: a n: b = (a + b) |) m: 3 n: 4'), 7);
    });

    test('Return a local slot', () {
      expect(Self.execute('(| m = (|s = 1| s) |) m'), 1);
    });

    test('Assign a local slot', () {
      expect(Self.execute('(| m = (|s| s: 1. s) |) m'), 1);
    });

    test('Implicit self should work', () {
      expect(Self.execute('''
      traits vector _AddSlotsIfAbsent: (|
        clone2: size = (_VectorClone: size).
        clone2 = (clone2: 0)
      |).
      traits vector clone2'''), isList);
      expect(Self.execute('traits vector clone'), isList);
    });

    test('Simple if', () {
      expect(Self.execute('true ifTrue: [5]'), 5);
      expect(Self.execute('false ifTrue: [5]'), Self.nilObject);
      expect(Self.execute('true ifFalse: [5]'), Self.nilObject);
      expect(Self.execute('false ifFalse: [5]'), 5);
    });

    test('If-then-else', () {
      expect(Self.execute('true ifTrue: [5] False: [6]'), 5);
      expect(Self.execute('false ifTrue: [5] False: [6]'), 6);
    });

    test('While loop', () {
      expect(Self.execute('(| x <- 0. m = ([x = 3] whileFalse: [x: x + 1]. x) |) m'), 3);
    });

    group('Vector', () {
      test('clone', () {
        expect(Self.execute('traits vector clone'), <SelfObject>[]);
        expect(Self.execute('traits vector clone: 1'), <SelfObject>[Self.nilObject]);
      });

      test('size', () {
        expect(Self.execute('traits vector clone size'), 0);
      });
      test('at/put', () {
        expect(
            Self.execute(
                '(| parent* = lobby. v <- traits vector clone: 2. m = (v at: 0 Put: true. v at: 1 Put: false. v) |) m'),
            <SelfObject>[Self.trueObject, Self.falseObject]);
      });

      test('from/to', () {
        expect(Self.execute('(traits vector clone: 3) from: 1 To: 1'), <SelfObject>[]);
      });
    });

    test('Vector builder', () {
      expect(Self.execute('(| m = (1 & 2) |) m'), [1, 2]);
      expect(Self.execute('(| m = (1 & 2 & 3) |) m'), [1, 2, 3]);
      expect(Self.execute('(| m = (1 & 2 & 3 & 4) |) m printString'), '(1, 2, 3, 4)');
    });

    test('Do loop', () {
      expect(Self.execute('(| m = (| x <- traits vector clone: 2 | x at: 0 Put: 3. x at: 1 Put: 4. x ) |) m'), [3, 4]);
      expect(
          Self.execute(
              '(| m = (| x <- traits vector clone: 2. s | x at: 0 Put: 3. x at: 1 Put: 4. s: 0. x do: [|:each| s: s + each]. s) |) m'),
          7);
    });

    test('Select loop', () {
      expect(
          Self.execute(
              '(| m = (| x <- traits vector clone: 2 | x at: 0 Put: 3. x at: 1 Put: 4. x select: [|:each| each < 4]) |) m'),
          [3]);
    });

    test('Collect loop', () {
      expect(
          Self.execute(
              '(| m = (| x <- traits vector clone: 2 | x at: 0 Put: 3. x at: 1 Put: 4. x collect: [|:each| each + 1]) |) m'),
          [4, 5]);
    });

    test('Non-local return', () {
      expect(Self.execute('(| m = ([^42] value. 1) |) m'), 42);
      expect(Self.execute('(| m = ([[^42] value. 2] value. 1) |) m'), 42);
    });
  });

  test('Factorial example', () {
    Self.initialize();
    Self.execute('''
traits number _AddSlotsIfAbsent:(| 
  factorial = (
    self = 0 ifTrue: [^1]. 
    (self - 1) factorial * self
  ) 
|).
''');
    expect(Self.send('factorial', [0]), 1);
    expect(Self.send('factorial', [6]), 720);
    expect(Self.send('factorial', [25]), 7034535277573963776);
  });

  test('Fibonacci example', () {
    Self.initialize();
    Self.execute('''
traits number _AddSlotsIfAbsent:(|
  fibonacci = (
    self < 3 ifTrue: [^1]. 
    (self - 1) fibonacci + (self - 2) fibonacci
  )
|).
''');
    expect(Self.send('fibonacci', [1]), 1);
    expect(Self.send('fibonacci', [2]), 1);
    expect(Self.send('fibonacci', [3]), 2);
    expect(Self.send('fibonacci', [25]), 75025);
  });
}
