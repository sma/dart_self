/**
 * Self values are either Dart `int`, `double`, `String`, [SelfObject]
 * (also used for `nil`, `true`, and `false`), [SelfMethod], [Mutator],
 * or a `List<SelfValue>` of such values.
 */
typedef SelfValue = Object;

/**
 * Implements a generic Self object with zero or more _slots_ to store other
 * Self objects. There are constant slots, data slots, and argument slots.
 * Additionally, slots can be parent slots. Constant slots are immutable. 
 * Data slots come with an associated mutator slot and can be changed by the
 * user. Argument slots have no associated mutator slot and are initialized 
 * by the runtime.
 *
 * Examples:
 * 
 *     the empty object:
 *         ( )
 *         new SelfObject([]);
 *
 *     an object with a single constant slot "a" initialized to 1:
 *         (| a = 1 |)
 *         new SelfObject([new Slot.constant("a", 1)]);
 *
 *     an object with a single data slot "b":
 *        (| b |)
 *        new SelfObject([new Slot.data("b", Self.nilObject), new Slot.mutator("b")]);
 *
 *     an object with a single data slot "b" initialized to 2:
 *        (| b <- 2 |)
 *        new SelfObject([new Slot.data("b", 2), new Slot.mutator("b")]);
 *
 *     an object with both a constant slot and a data slot:
 *        (| a = 1. b <- 2 |)
 *        new SelfObject([new Slot.constant("a", 1), new Slot.data("b", 2), new Slot.mutator("b")]);
 *
 *     an object with a constant parent slot "c" initialized to another empty object:
 *         (| c* = () |)
 *         new SelfObject([new Slot.constant("c", new SelfObject([]), parent:true)]);
 *
 *     an object (typically a method) with a parent-argument slot named "self", another argument slot and a data slot:
 *         (| :self*. :a. b |)
 *         var ss = new Slot.argument("self", nil, parent:true);
 *         var sa = new Slot.argument("a", nil);
 *         var sb = new Slot.data("b", Self.nilObject);
 *         var sm = new Slot.mutator("b");
 *         new SelfObject([ss, sa, sb, sm]);
 *
 *     an object (typically a block method) with a parent-argument slot named "(parent)":
 *         (| :(parent)*. |)
 *         new SelfObject([new Slot.argument("(parent)", nil, parent:true)]);
 */
class SelfObject {
  /// Holds the object's [Slot] objects.
  final List<Slot> slots;

  /// Constructs a new Self object with the given list of [slots].
  SelfObject(this.slots);

  /// Returns a list of cloned slots which should be used to construct a clone of the receiver.
  List<Slot> clonedSlots() => slots.map((slot) => slot.clone()).toList();

  /// Clones the receiver. Subclasses should override this method.
  SelfObject clone() => SelfObject(clonedSlots());

  /// Adds the [slot] if the receiver doesn't yet have a slot with that name.
  void addSlotIfAbsent(Slot slot) {
    if (!slots.any((s) => s.name == slot.name)) {
      final clonedSlot = slot.clone();
      slots.add(clonedSlot);
      if (clonedSlot.data) {
        slots.add(Slot.m(clonedSlot.name));
      }
    }
  }

  /// Removes a slot if the receiver has a slot with that name.
  void removeSlotNamed(String name) {
    slots.removeWhere((s) => s.name == name || (s.value is Mutator && (s.value as Mutator).name == name));
  }

  /// Returns a string representation somewhat similar to Self syntax.
  @override
  String toString() => '(| ${slots.join('. ')} |)';
}

/**
 * Implements a Self method object. In addition to the usual slots it has a
 * list of [Code] objects, representing explicit and implicit message send 
 * expressions, object and block literals, and non-local returns.
 *
 * Examples:
 * 
 *     the empty method:
 *         ( )
 *         new SelfMethod([...], []);
 *
 *     a method returning a literal:
 *         ( 1 )
 *         new SelfMethod([...], [new Lit(1)]);
 *
 *     literals can also be objects:
 *         ( (|a = 1|) )
 *         new SelfMethod([...], [new Lit(new SelfObject([new Slot.constant("a", 1)]))]);
 *
 *     a method returning the result of adding 3 and 4:
 *         ( 3 + 4 )
 *         new SelfMethod([...], [new Msg(new Lit(3), "+", [new Lit(4)])]);
 *
 *     a method sending two implicit messages, returning the result of the last message send:
 *         ( one. two )
 *         new SelfMethod([...], [new IMsg("one", []), IMsg("two", [])]);
 *
 *     a method sending an implicit message with an argument:
 *         ( a: 1 )
 *         new SelfMethod([...], [new IMsg("one", [new Lit(1)])]);
 *
 *     a block method with a non-local return:
 *         ( one. ^1 )
 *         new SelfMethod([...], [new IMsg("one", []), new Ret(new Lit(1))]);
 *
 *     a method with a block literal:
 *         ( [ ] )
 *         var mth = new SelfMethod([new Slot.argument("(parent)", nil, parent: true)], []);
 *         var blk = new SelfObject([new Slot.argument("(lexicalParent)", nil),
 *                                   new Slot.constant("value"), mth),
 *                                   new Slot.constant("parent", Self.traitsBlock, parent:true)];
 *         new SelfMethod([...], [new Blk(new Lit(blk))]);
 *
 * Please note the convention that every method object must have a 
 * parent-argument slot called `self` and enough argument slots matching 
 * the selector's arity, that is unary methods have no arguments, binary
 * methods have one argument and keyword methods have a number of argument 
 * slots identical to the number of keyword parts. Argument slots have no 
 * associated mutators and can only be set by the runtime system.
 * The runtime requires the `:self*` slot to be the first one, directly 
 * followed by the argument slots.
 *
 * Block method objects have a slot called `:(parent)*` instead, which is 
 * set to the block object's `(lexicalParent)` object when activated. The 
 * `(lexicalParent)` captures the activation when the block object is created.
 * Again, the runtime requires the `:(parent)*` slot to be the first one.
 *
 * Examples:
 * 
 *     an unary method called size by assignment (body omitted):
 *         (| size = ( ... ) |)
 *         (| size = ( | :self* | ... ) |)
 *         new SelfMethod([new Slot.argument("self", nil, parent:true)], [...]);
 *
 *     a binary method called + by assignment (body omitted):
 *         (| + num = ( ... ) |)
 *         (| + = (| :self*. :num | ... ) |)
 *         new SelfMethod([new Slot.argument("self", nil, parent:true), new Slot.argument("num", nil)], [...]);
 *
 *     a single keyword method called ifTrue: by assignment (body omitted):
 *         (| ifTrue: block = ( ... ) |)
 *         (| ifTrue: = (| :self*. :block | ... ) |)
 *         new SelfMethod([new Slot.argument("self", nil, parent:true), new Slot.argument("block", nil)], [...]);
 *
 *     a keyword method with two keyword parts called ifTrue:False: by assignment (body omitted):
 *         (| ifTrue: block False: anotherBlock = ( ... ) |)
 *         (| ifTrue:False: = (| :self*. :block. :anotherBlock | ... ) |)
 *         new SelfMethod([new Slot.argument("self", nil, parent:true)
 *                         new Slot.argument("block", nil),
 *                         new Slot.argument("anotherBlock", nil)], [...]);
 *
 *     a binary method with two additional data slots:
 *         (| & obj = (| t1. t2 <- 7 | ... ) |)
 *         (| & = (| *self:. :obj. t1. t2 <- 7 | ... ) |)
 *         new SelfMethod([new Slot.argument("self", nil, parent:true),
 *                         new Slot.argument("obj", nil),
 *                         new Slot.data("t1", Self.nilObject),
 *                         new Slot.mutator("t1")],
 *                         new Slot.data("t2", 7),
 *                         new Slot.mutator("t2")], [...]);
 *
 * The first line in each example shows the typical inline argument slot 
 * definition and the second line shows the explicit slot definition.
 *
 * This class also implements block method objects. Instead of a `:self*` 
 * slot, block methods have a special `(parent)*` parent-argument slot 
 * which contains the activation of the place the block was defined (a.k.a. 
 * cloned). A block object is a normal Self object with three slots: 
 * 
 * - An argument slot called `(lexicalParent)` that contains the already 
 *   mentioned activation which is then copied into `(parent)*`,
 * - a parent slot `parent` containing a `traits block` object that defines 
 *   the common behavior of all blocks, 
 * - and a slot containing the method object. It is called `value` if the 
 *   block has no arguments, `value:` if there is one argument and
 *   `value:With:...With:` with enough `With:` keyword parts for all 
 *   additional arguments.
 * 
 * The runtime requires the `(lexicalParent)` slot to be the first one, 
 * directly followed by the argument slots.
 *
 * Examples:
 * 
 *     the empty block (returning nil):
 *         [ ]
 *         (| (lexicalParent). parent* = traits block. value = (| :(parent)* | nil) |)
 *
 *     a block returning a literal:
 *         [ 1 ]
 *         (| (lexicalParent). parent* = traits block. value = (| :(parent)* | 1) |)
 *
 *     a block taking a parameter and defining a local variable:
 *         [| :a. b | b: a. b + 1]
 *         (| (lexicalParent). parent* = traits block. value: = (| :(parent)*. :a. b | b: a. b + 1) |)
 *
 *     a block with two parameters, defining another block:
 *         [| :a :b | [a + b] ]
 *         (| (lexicalParent).
 *            parent* = traits block.
 *            value:With: = (| :(parent)*. :a. :b | (| (lexicalParent).
 *                                                     parent* = traits block.
 *                                                     value = (| :(parent)* | a + b ) |) ) |)
 *
 * The first line shows the block syntax, the second line demonstrates the 
 * actual implementation. It is worth noticing that `(lexicalParent)` always
 * has a value which cannot be represented easily. In fact, in the last 
 * example, the inner `(lexicalParent)` contains the outer block's activation
 * object to gain access to the method slots `a` and `b`.
 */
class SelfMethod extends SelfObject {
  /// Holds the method's code.
  final List<Code> codes;

  /// Constructs a new method object with the given [slots] and [codes].
  SelfMethod(super.slots, this.codes);

  /// Clones the receiver.
  @override
  SelfMethod clone() => SelfMethod(clonedSlots(), codes);

  /**
   * Clones the receiver, then initializes its argument slots (beginning 
   * with the method's receiver) from [arguments] and executes it. An empty
   * method yields the receiver. An empty block yields `nil`. Otherwise the 
   * result of the execution of the last `Code` object is returned. The 
   * parent-argument `self` (or `(parent)` in the case of blocks) must be 
   * the first slot and all other arguments must be the adjacent slots.
   */
  SelfValue activate(Self self, List<SelfValue> arguments) {
    final activation = clone();
    arguments.asMap().forEach((i, a) {
      activation.slots[i].value = a;
    });
    if (isBlock) {
      // Block methods must have its block object as receiver which must have
      // a `(lexicalParent)` slot. The value of the `(lexicalParent)` becomes
      // the value of the method's `(parent)` slot.
      activation.slots[0].value = (arguments[0] as SelfObject).slots[1].value;
    }
    return activation.execute(self);
  }

  /**
   * Executes the method using itself as activation object.
   * Returns either `nil` for empty methods or the result of the last code object.
   */
  SelfValue execute(Self self) {
    try {
      return codes.fold(self.nilObject, (result, code) => code.execute(self, this));
    } on NonLocalReturn catch (ret) {
      if (ret.target == this) {
        return ret.value;
      }
      rethrow;
    }
  }

  /// Returns whether this method is a block method. Kind of hackish...
  bool get isBlock => slots[0].name == '(parent)';

  /// Returns a string representation somewhat similar to Self syntax.
  @override
  String toString() => '(| ${slots.join('. ')} | ${codes.join('. ')} )';
}

/**
 * Implements an object property which associates a name with a value.
 *
 * All slots have a name and a value. Constant slots are not changeable by
 * the user. Data slots can be mutated by an associated mutator slot.
 * To honor the Self semantic, data slots should have simple names and must
 * not have an operator or keyword as name. A mutator slot has the same name
 * as the data slot ending with `:` (making it a keyword). Argument slots
 * are data slots without a mutator which therefore can only be changed by 
 * the runtime system. They might have invalid names like `(parent)` or
 * `(lexicalParent)` to keep them internal and not accessible by the user.
 * Additionally, all slots can be parent slots. Parent slots should contain 
 * other Self objects and when searching for a slot, the search is continued
 * in those objects.
 */
class Slot {
  final String name;
  final int kind; // CONST = 0, DATA = 1, ARGUMENT = 2, PARENT = 4
  SelfValue value;

  bool get constant => (kind & 3) == 0; // coverage:ignore-line
  bool get data => (kind & 3) == 1;
  bool get argument => (kind & 3) == 2;
  bool get parent => (kind & 4) != 0;

  /// Constructs a new constant slot (which holds an object).
  Slot.c(this.name, this.value, {bool parent = false}) : kind = parent ? 4 : 0;

  /// Constructs a new data slot (which holds an object).
  Slot.d(this.name, this.value, {bool parent = false}) : kind = parent ? 5 : 1;

  /// Constructs a new argument slot.
  Slot.a(this.name, this.value, {bool parent = false}) : kind = parent ? 6 : 2;

  /// Constructs a new mutator slot.
  Slot.m(String name) : this.c('$name:', Mutator(name));

  Slot._(this.name, this.kind, this.value);

  /// Clones the receiver if its value can be mutated, otherwise it can be shared.
  Slot clone() => (kind & 3) != 0 ? Slot._(name, kind, value) : this;

  /// Returns the associated mutator slot (only useful for data slots).
  // Slot get mutator => new Slot(name + ":", new Mutator(name));

  /// Returns a string representation somewhat similar to Self syntax.
  @override
  String toString() => '${argument ? ":" : ""}$name${parent ? "*" : ""}${data ? "<-" : ""}';
}

/**
 * When used as [Slot] value, that slot is a mutator for the encapsulated slot.
 *
 * The magic happens when [Msg] tries to activate this object. Instead of
 * returning this object, the associated data slot is searched and its value 
 * is changed. An alternative implementation would have been to add another
 * variable to [Slot] which in the case of a mutator slot, points to the 
 * associated data slot.
 */
class Mutator {
  final String name;

  Mutator(this.name);
}

/**
 * Represents a piece of code of a Self method object which can be executed.
 * See [Lit], [Mth], [Blk] and [Msg].
 *
 * Here are examples for literals:
 *
 *      number:
 *          42
 *          new Lit(42);
 *
 *      string:
 *          'abc'
 *          new Lit('abc');
 *
 *      object:
 *          ( )
 *          new Lit(new SelfObject([]));
 *
 * Method objects must be wrapped with a [Mth]. Because it is known at 
 * compile time whether a literal is a primitive object, a simple literal 
 * object, or method object, the later are wrapped to correctly perform 
 * method activation without a runtime check. Therefore, [Mth] is an 
 * optimization.
 *
 *      a method literal:
 *          ( 42 )
 *          new Mth(new Lit(new SelfMethod(
 *              [new Slot.argument("self", nil, parent:true)], 
 *              [new Lit(42)])))
 *
 * Block objects must be wrapped with a [Blk] for the same reason:
 *
 *      a block literal:
 *          [ 21 ]
 *          var blk = new SelfMethod([new Slot.argument("(parent)", nil, parent:true)], [new Lit(21)]);
 *          new Blk(new Lit(new SelfObject([new Slot.argument("(lexicalParent)", nil),
 *                                          new Slot.constant("value", blk),
 *                                          new Slot.constant("parent", Self.traitsBlock)])));
 *
 * Here are examples for messages:
 *
 *      an implicit unary message:
 *          foo
 *          new Msg(null, "foo", [])
 *
 *      an explicit unary message:
 *          2 negated
 *          new Msg(new Lit(2), "negated", [])
 *
 *      an explicit unary message (using an implicit unary message to compute the receiver):
 *          foo bar baz
 *          new Msg(new Msg(new Msg(null, "foo", []), "bar", []), "baz", [])
 *
 *      an implicit binary message:
 *          << 7
 *          new Msg(null, "<<", [new Lit(7)])
 *
 *      an explicit binary message:
 *          3 + 4
 *          new Msg(new Lit(3), "+", [new Lit(4)])
 *
 *      an implicit single keyword message:
 *          foo: 1
 *          new Msg(null, "foo:", [new Lit(1)])
 *
 *      an explicit two keyword message:
 *          array at: 1 Put: 3 + 4
 *          new Msg(new Msg(null, "array", []), "at:Put:", [new Lit(1), new Msg(new Lit(3), "+", [new Lit(4)])])
 *
 * Because explicit and implicit message sends can be detected at compile 
 * time, we should probably use two kind of classes where to save a runtime 
 * check whether the receiver is null or not. Actually, there should be three 
 * kinds of message sends, because there are also primitive message sends 
 * which execute primitive VM operation. They look like normal message 
 * sends but have a selector starting with `_`.
 */
abstract class Code {
  /// Executes this instruction in the context of the given [activation].
  SelfValue execute(Self self, SelfObject activation);
}

/**
 * Represents a (primitive) literal value.
 *
 * Executing a literal code returns its value.
 */
class Lit extends Code {
  final SelfValue value;

  Lit(this.value);

  @override
  SelfValue execute(Self self, SelfObject activation) => value;

  @override
  String toString() => value is String ? "'$value'" : '$value';
}

/**
 * Represents a method literal.
 *
 * Executing a method code executes the method literal's code and returns its value.
 */
class Mth extends Code {
  final SelfMethod method;

  Mth(this.method);

  @override
  SelfValue execute(Self self, SelfObject activation) {
    return method.codes.fold(self.nilObject, (result, code) => code.execute(self, activation));
  }

  @override
  String toString() => method.toString();
}

/**
 * Represents a block literal.
 *
 * Executing a block code clones the block and initializes its `lexicalParent` slot.
 */
class Blk extends Code {
  final SelfObject block;

  Blk(this.block);

  @override
  SelfValue execute(Self self, SelfObject activation) {
    return block.clone()..slots[1].value = activation;
  }
}

/**
 * Represents an implicit or explicit message send. Implicit message sends 
 * don't have a receiver and use the activation object instead. Local variable
 * (a.k.a. slot) access is implemented this way. Because the activation 
 * object is typically a method object which has a self-parent slot, a method
 * body can access instance variables (a.k.a. slots) because they are 
 * inherited via `self*`.
 *
 * Executing a message code will search for the selected method, activate it and execute it.
 *
 * TODO there should be IMsg (implicit) and EMsg (explicit) and PMsg (primitive)
 */
class Msg extends Code {
  final Code? receiver;
  final String selector;
  final List<Code> arguments;

  Msg(this.receiver, this.selector, this.arguments);

  @override
  SelfValue execute(Self self, SelfObject activation) {
    // recursively evaluate the receiver
    final r = receiver?.execute(self, activation) ?? activation;

    // recursively evaluate the arguments
    final a = arguments.map((arg) => arg.execute(self, activation));

    // deal with primitives
    if (selector.startsWith('_')) {
      final p = self.primitives[selector];
      if (p != null) {
        return p([r, ...a]);
      }
      throw 'UnknownPrimitive($selector)';
    }

    // search for the method starting with the receiver
    // an error is thrown if there is no matching slot
    Slot? slot = self.findSlot(r, selector);
    final v = slot.value;

    // if the slot found is a mutator, search for the matching data slot
    // (which stores the value) which must exist and mutate it
    if (v is Mutator) {
      slot = self._findSlot(r, v.name, {});
      if (slot == null) {
        throw 'MutatorWithoutDataSlot($selector)';
      }
      return slot.value = a.first;
    }

    // if the slot contains a method, activate it (this will execute the method)
    if (v is SelfMethod) {
      // in case of implicit sends, we need to set self to the original self
      final rr = receiver == null ? self.findSlot(r, 'self').value : r;

      return v.activate(self, [rr, ...a]);
    }

    // otherwise, the slot contains a literal
    return v;
  }

  @override
  String toString() => '{$selector $receiver${arguments.isNotEmpty ? ' ' : ''}${arguments.join(' ')}}';
}

/**
 * Represents a non-local return. Must occur only in blocks. Executing a 
 * non-local return will abort the current execution and return from the 
 * method the block was defined in. See [SelfMethod.execute] for details.
 */
class Ret extends Code {
  final Code code;

  Ret(this.code);

  @override
  SelfValue execute(Self self, SelfObject activation) {
    var target = activation as SelfMethod;
    // search for the method context to return from
    while (target.isBlock) {
      target = target.slots[0].value as SelfMethod; // TODO cast
    }
    throw NonLocalReturn(target, code.execute(self, activation));
  }
}

class NonLocalReturn {
  final SelfMethod target;
  final SelfValue value;
  NonLocalReturn(this.target, this.value);
}

// ------------------------------------------------------------------------------------------------------------------
// parser
// ------------------------------------------------------------------------------------------------------------------

/// Private class to represent a pair of token type and token value.
class _Token {
  final _T type;
  final String value;
  final int pos;

  _Token(this.type, this.value, this.pos);

  // coverage:ignore-start
  @override
  String toString() => '{$type $value}';
  // coverage:ignore-end
}

/// Token types - conceptually belonging to [_Token].
enum _T { end, num, str, nam, op, kw1, kw2, lp, rp, col, dot, lbr, rbr, ret }

/**
 * Parses Self source code into object literals or message expressions.
 *
 * Grammar:
 * 
 *     program = message {"." message} ["."]
 *     body = program ["^" message] ["."]
 *     message = binaryMessage {KEYWORD binaryMessage}
 *     binaryMessage = unaryMessage {OPERATOR unaryMessage}
 *     unaryMessage = [primary] NAME {NAME}
 *     primary = literal | object | block | "resend"
 *     literal = NUMBER | STRING
 *     object = "(" [slots] [body] ")"
 *     block = "[" [slots] [body] "]"
 *     slots = "|" slot {"." slot} ["."] "|"
 *     slot = argumentSlot | constantSlot | dataSlot | methodSlot
 *     argumentSlot = ":" NAME ["*"]
 *     constantSlot = NAME ["*"] ["=" message]
 *     dataSlot = NAME ["*"] ["<-" message]
 *     methodSlot = (unaryMethodSlot | binaryMethodSlot | keywordMethodSlot) "=" object
 *     unaryMethodSlot = NAME
 *     binaryMethodSlot = OPERATOR [NAME]
 *     keywordMethodSlot = KEYWORD NAME {KEYWORD NAME} | KEYWORD {KEYWORD}
 *
 * Each Self program is a sequence of message expressions. Such an 
 * expression is either a literal number or literal string, a normal object 
 * or a block object or an implicit or explicit message send. Although
 * possible with the grammar above, a message send expression must not be 
 * empty. Literal objects with a body are immediately executed like 
 * parenthesized expressions in other languages. This does not happen if the
 * object is assigned to a slot. The grammar cannot distinguish constant 
 * slots that get an object assigned and unary method slots. An unary method 
 * is assumed in this case. If the assigned value is computed from a
 * message expression, even if the result is an object, it's a constant slot.
 * Therefore, you need to always use parenthesizes when defining methods.
 *
 *     constant slot:
 *         not = true.
 *
 *     unary method slot:
 *         not = (true).
 *
 * The parser needs access to the Self runtime system. It needs to know the 
 * [Self.lobby] and use it to execute message expressions to compute literal 
 * objects. It needs to know [Self.nilObject] to initialize uninitialized data
 * slots and create empty blocks. It needs to know the `traits block` object 
 * to construct blocks (although this could also be done by the runtime).
 */
class Parser {
  /// Creates a list of tokens from the [source].
  static Iterable<_Token> _tokenize(String source) sync* {
    const kTOKEN = r'(-?\d+(?:\.\d+)?)|'
        r"'((?:\\[bfnrtu\']|[^'])*)'|"
        r'(\w+:?)|([-+*/%!=<>~&|,]+)|'
        r'([():.[\]^])|"[^"]*"|\s+';
    for (final m in RegExp(kTOKEN).allMatches(source)) {
      if (m[1] != null) {
        yield _Token(_T.num, m[1]!, m.start);
      } else if (m[2] != null) {
        yield _Token(_T.str, _unescape(m[2]!), m.start);
      } else if (m[3] != null) {
        _T type;
        if (m[3]!.endsWith(':')) {
          type = m[3]!.startsWith(RegExp('[A-Z]')) ? _T.kw2 : _T.kw1;
        } else {
          type = _T.nam;
        }
        yield _Token(type, m[3]!, m.start);
      } else if (m[4] != null) {
        yield _Token(_T.op, m[4]!, m.start);
      } else if (m[5] != null) {
        const ts = [_T.lp, _T.rp, _T.col, _T.dot, _T.lbr, _T.rbr, _T.ret];
        yield _Token(ts['():.[]^'.indexOf(m[5]!)], m[5]!, m.start);
      }
    }
    yield _Token(_T.end, '', source.length);
  }

  /// Returns a new string with the usual string escape sequences replaced.
  static String _unescape(String s) {
    const kTOKEN = "\\\\(?:([bfnrt\\\\'])|u([0-9a-fA-F]{4}))";
    return s.replaceAllMapped(RegExp(kTOKEN), (m) {
      if (m[2] != null) {
        return String.fromCharCode(int.parse(m[2]!, radix: 16));
      } else {
        switch (m[1]) {
          case 'b':
            return '\b';
          case 'f':
            return '\f';
          case 'n':
            return '\n';
          case 'r':
            return '\r';
          case 't':
            return '\t';
          default:
            return m[1]!;
        }
      }
    });
  }

  final Self self;
  final List<_Token> _tokens;
  int index;

  /// Constructs a new parser to parse [source].
  Parser(this.self, String source)
      : _tokens = _tokenize(source).toList(),
        index = 0;

  /// Returns the type of the current token.
  _T get _type => _tokens[index].type;

  /// Returns true if the current token is the operator [op].
  bool _at(String op) => _type == _T.op && _tokens[index].value == op;

  /// Returns the value of the current token and advances to the next token.
  String value() => _tokens[index++].value;

  /// Returns a throwable syntax error message.
  String syntaxError(String message) => 'SyntaxError: $message at ${_tokens[index].pos}';

  /// Converts the source code into a global Self method.
  SelfMethod parse() {
    final codes = <Code>[];
    while (_type != _T.end) {
      codes.add(parseMessage());
      if (_type == _T.dot) {
        index++; // skip .
      } else if (_type != _T.end) {
        throw syntaxError('End of input expected');
      }
    }
    return SelfMethod([Slot.a('self', self.lobby, parent: true)], codes);
  }

  /// Returns a literal (a number, string or object) parsed from the source.
  /// Parenthesized expressions are mistaken as method objects.
  SelfValue parseLiteral() {
    if (_type == _T.num) {
      return num.parse(value());
    }
    if (_type == _T.str) {
      return value();
    }
    if (_type == _T.lp) {
      return parseObject();
    }
    if (_type == _T.lbr) {
      return parseBlock();
    }
    throw syntaxError('number, string, (, or [ expected');
  }

  /// Returns a Self object or Self method parsed from the source.
  /// The current token must be `(`.
  SelfObject parseObject() {
    index++; // skip (
    final slots = _at('|') ? parseSlots() : <Slot>[];
    if (slots.isEmpty && _at('||')) index++;
    final codes = <Code>[];
    while (_type != _T.rp) {
      codes.add(parseMessage());
      if (_type == _T.dot) {
        index++; // skip .
      } else if (_type != _T.rp) {
        throw syntaxError(') expected');
      }
    }
    index++; // skip )
    return codes.isEmpty ? SelfObject(slots) : SelfMethod(slots, codes);
  }

  /// Returns a Self block object parsed from the source.
  /// The current token must be `[`.
  SelfObject parseBlock() {
    index++; // skip [
    final slots = _at('|') ? parseSlots() : <Slot>[];
    if (slots.isEmpty && _at('||')) index++;
    final codes = <Code>[];
    while (_type != _T.rbr) {
      if (_type == _T.ret) {
        index++; // skip ^
        codes.add(Ret(parseMessage()));
        if (_type == _T.dot) {
          index++; // skip .
        }
        if (_type != _T.rbr) {
          throw syntaxError('] expected');
        }
        break;
      }
      codes.add(parseMessage());
      if (_type == _T.dot) {
        index++; // skip .
      } else if (_type != _T.rbr) {
        throw syntaxError('] expected');
      }
    }
    index++; // skip ]
    // an empty block should return nil
    if (codes.isEmpty) {
      codes.add(Lit(self.nilObject));
    }
    // create the block method's selector name
    var selector = 'value';
    for (var i = 0; i < slots.length; i++) {
      if (slots[i].argument) {
        if (selector == 'value') {
          selector = 'value:';
        } else {
          selector += 'With:';
        }
      }
    }
    slots.insert(0, Slot.a('(parent)', self.nilObject, parent: true));
    return SelfObject([
      Slot.c('parent', self.traitsBlock, parent: true),
      Slot.a('lexicalParent', self.nilObject),
      Slot.c(selector, SelfMethod(slots, codes))
    ]);
  }

  /// Returns a list of Slot objects parsed from the source.
  /// The current token must be `|`.
  List<Slot> parseSlots() {
    index++; // skip |
    final slots = <Slot>[];
    while (!_at('|')) {
      final slot = parseSlot();
      slots.add(slot);
      if (slot.data) {
        slots.add(Slot.m(slot.name));
      }
      if (_type == _T.dot) {
        index++; // skip .
      } else if (!_at('|')) {
        throw syntaxError('| expected');
      }
    }
    index++; // skip |
    return slots;
  }

  /// Returns a Slot object parsed from the source.
  Slot parseSlot() {
    // argument slots are prefixed with `:`
    bool argument;
    if (_type == _T.col) {
      index++; // skip :
      argument = true;
    } else {
      argument = false;
    }

    // name is either an unary selector, binary selector or at least one keyword selector;
    // binary selectors and keyword selectors may have inline arguments which are names
    String name;
    final args = <String>[];
    if (_type == _T.nam) {
      // unary selector
      name = value();
    } else if (_type == _T.op) {
      // binary selector
      name = value();
      if (_type == _T.nam) {
        // inline argument
        args.add(value());
      }
    } else if (_type == _T.kw1) {
      // keyword selector
      name = value();
      if (_type == _T.nam) {
        // inline argument
        args.add(value());
      }
      while (_type == _T.kw2) {
        name += value();
        if (_type == _T.nam) {
          if (args.isEmpty) {
            throw syntaxError('inconsistent use of inline parameters');
          }
          args.add(value());
        } else if (args.isNotEmpty) {
          throw syntaxError('inconsistent use of inline parameters');
        }
      }
    } else {
      throw syntaxError('name, operator or keyword expected');
    }

    // parent slots are marked with `*`
    bool parent;
    if (_at('*')) {
      index++; // skip *
      parent = true;
    } else {
      parent = false;
    }

    Object? val;
    bool data;
    if (_at('=')) {
      index++; // skip =
      // we need to distinguish method and literal definitions here
      // - a Lit or Mth will become its value
      // - a Msg will become its executed value
      val = parseMessage();
      if (val is Lit) {
        val = val.value;
      } else if (val is Mth) {
        val = val.method;
      } else if (val is Msg) {
        val = val.execute(self, self.lobby);
      }
      // methods may need argument slots
      if (val is SelfMethod) {
        _injectMethodArgs(val, args);
      } else if (args.isNotEmpty) {
        val = SelfMethod([], [Lit(val)]);
        _injectMethodArgs(val, args);
      }
      // this is a constant slot
      data = false;
    } else if (_at('<-')) {
      index++; // skip <-
      // we cannot define methods with `<-` so we will always execute the code
      if (args.isNotEmpty) {
        throw syntaxError('No inline parameters with <- allowed');
      }
      val = parseMessage().execute(self, self.lobby);
      // argument slots are never data slots
      data = !argument;
    } else {
      val = self.nilObject;
      data = !argument;
    }
    if (argument) {
      return Slot.a(name, val, parent: parent);
    }
    if (data) {
      return Slot.d(name, val, parent: parent);
    }
    return Slot.c(name, val, parent: parent);
  }

  /// Prepends a ":self*" slot if missing and inject optional inline arguments before method's local slots.
  void _injectMethodArgs(SelfMethod m, List<String> args) {
    if (m.slots.isEmpty || m.slots[0].name != 'self') {
      m.slots.insert(0, Slot.a('self', self.nilObject, parent: true));
      for (var i = 0; i < args.length; i++) {
        m.slots.insert(i + 1, Slot.a(args[i], self.nilObject));
      }
    }
  }

  /// Returns the next message parsed from the source.
  Code parseMessage() {
    var m = parseBinaryMessage();
    if (_type == _T.kw1) {
      var name = value();
      final args = [parseMessage()];
      while (_type == _T.kw2) {
        name += value();
        args.add(parseMessage());
      }
      m = Msg(m, name, args);
    } else if (m == null) {
      throw syntaxError('message expected');
    }
    return m;
  }

  Code? parseBinaryMessage() {
    var m = parseUnaryMessage();
    while (_type == _T.op && !_at('|')) {
      m = Msg(m, value(), [parseUnaryMessage()!]); // TODO !
    }
    return m;
  }

  Code? parseUnaryMessage() {
    Code? m;
    if (_type == _T.num || _type == _T.str || _type == _T.lp) {
      // explicit receiver
      final v = parseLiteral();
      if (v is SelfMethod) {
        m = Mth(v);
      } else {
        m = Lit(v);
      }
    } else if (_type == _T.lbr) {
      m = Blk(parseBlock());
    } else {
      m = null; // implicit message send (or an error which is checked later)
    }
    while (_type == _T.nam) {
      m = Msg(m, value(), []);
    }
    return m;
  }
}

// ------------------------------------------------------------------------------------------------------------------
// runtime system
// ------------------------------------------------------------------------------------------------------------------

/**
 * For now, this class has static methods that represents the Self runtime 
 * system. It knows the [lobby] and a few other important objects like `nil`,
 * `true`, and `false` as well as the `traits` for all primitive objects and 
 * blocks. It also knows [primitives], a map from primitive message 
 * selectors to Dart functions taking the method arguments including the 
 * receiver. There's no error handling yet.
 */
class Self {
  final SelfObject traitsNumber = SelfObject([]);

  final SelfObject traitsString = SelfObject([]);

  final SelfObject traitsVector = SelfObject([]);

  final SelfObject traitsBlock = SelfObject([]);

  final SelfObject nilObject = SelfObject([]);

  final SelfObject trueObject = SelfObject([]);

  final SelfObject falseObject = SelfObject([]);

  final SelfObject lobby = SelfObject([]);

  final Map<String, SelfValue Function(List<SelfValue> a)> primitives = {};

  /**
   * Bootstraps the runtime system.
   * 
   * It initializes the [lobby] with three slots `lobby`, `globals`, and `traits`.
   * 
   * The lobby needs to refer to itself to give itself its name. The `globals`
   * object has slots for `nil`, `true` and `false`. The `traits` object has 
   * slots for `number`, `string`, `vector`, and `block` which are the 
   * primitive types the runtime system knows of.
   *
   * Strictly speaking, most of the lobby could be created with Self code. 
   * Because empty blocks must return nil, this is a way to get that object. 
   * By comparing it to itself or any other object, we get true and false. Any
   * block also knows its trait.
   *
   * This method also sets up a number of primitive functions.
   */
  void initialize() {
    // reset everything
    for (final object in [
      nilObject,
      trueObject,
      falseObject,
      traitsBlock,
      traitsNumber,
      traitsString,
      traitsVector,
      lobby,
    ]) {
      object.slots.clear();
    }
    primitives.clear();

    // define everything
    final globals = SelfObject([
      Slot.c('nil', nilObject),
      Slot.c('true', trueObject),
      Slot.c('false', falseObject),
    ]);
    final traits = SelfObject([
      Slot.c('number', traitsNumber),
      Slot.c('string', traitsString),
      Slot.c('vector', traitsVector),
      Slot.c('block', traitsBlock),
    ]);
    lobby.slots.addAll([
      Slot.c('lobby', lobby),
      Slot.c('globals', globals, parent: true),
      Slot.c('traits', traits),
    ]);

    primitives.addAll({
      '_AddSlotsIfAbsent:': (a) {
        final r = a[0] as SelfObject;
        (a[1] as SelfObject).slots.forEach(r.addSlotIfAbsent);
        return r;
      },
      '_Clone': (a) => (a[0] as SelfObject).clone(),
      '_NumToString': (a) => '${a[0]}',
      '_NumAdd:': (a) => (a[0] as num) + (a[1] as num),
      '_NumSub:': (a) => (a[0] as num) - (a[1] as num),
      '_NumMul:': (a) => (a[0] as num) * (a[1] as num),
      '_NumDiv:': (a) => (a[0] as num) / (a[1] as num),
      '_NumMod:': (a) => (a[0] as num) % (a[1] as num),
      '_Equal:': (a) => a[0] == a[1] ? trueObject : falseObject,
      '_NumLt:': (a) => (a[0] as num) < (a[1] as num) ? trueObject : falseObject,
      '_StringSize': (a) => (a[0] as String).length,
      '_StringAt:': (a) => (a[0] as String)[a[1] as int],
      '_StringConcat:': (a) => (a[0] as String) + (a[1] as String),
      '_StringFrom:To:': (a) => (a[0] as String).substring(a[1] as int, a[2] as int),
      '_VectorClone:': (a) => List<SelfValue>.filled(a[1] as int, nilObject, growable: true),
      '_VectorSize': (a) => (a[0] as List<SelfValue>).length,
      '_VectorAdd:': (a) {
        (a[0] as List<SelfValue>).add(a[1]);
        return a[1];
      },
      '_VectorAt:': (a) => (a[0] as List<SelfValue>)[a[1] as int],
      '_VectorAt:Put:': (a) {
        (a[0] as List<SelfValue>)[a[1] as int] = a[2];
        return a[2];
      },
      '_VectorFrom:To:': (a) => (a[0] as List<SelfValue>).sublist(a[1] as int, a[2] as int),
    });

    // now do the rest of the initialization using Self
    execute("""
      traits number _AddSlotsIfAbsent: (|
        parent* = lobby.
        clone = (self).
        printString = (self _NumToString).
        negate = (0 - self).
        + n = (self _NumAdd: n).
        - n = (self _NumSub: n).
        * n = (self _NumMul: n).
        / n = (self _NumDiv: n).
        % n = (self _NumMod: n).
        = n = (self _Equal: n).
        < n = (self _NumLt: n).
        > n = (n < self).
        <= n = ((self > n) not).
        >= n = ((self < n) not).
        != n = ((self = n) not).
        to: end Do: block = (self to: end By: 1 Do: block).
        to: end By: step Do: block = (|i| i: self. [i <= end] whileTrue: [block value: i. i: i + step]).
      |).
      nil _AddSlotsIfAbsent: (|
        parent* = lobby.
        clone = nil.
        printString = 'nil'.
        isNil = true.
      |). 
      true _AddSlotsIfAbsent: (|
        parent* = lobby.
        clone = true.
        printString = 'true'.
        ifTrue: t = (t value).
        ifTrue: t False: f = (t value).
        ifFalse: f = nil.
        && b = (b value).
        || b = true.
        not = false.
      |).
      false _AddSlotsIfAbsent: (|
        parent* = lobby.
        clone = false.
        printString = 'false'.
        ifTrue: t = nil.
        ifTrue: t False: f = (f value).
        ifFalse: f = (f value).
        && b = false.
        || b = (b value).
        not = true.
      |).
      traits block _AddSlotsIfAbsent: (|
        parent* = lobby.
        printString = 'a block'.
        whileTrue: b = (self value ifTrue: [b value. self whileTrue: b]).
        whileFalse: b = (self value ifFalse: [b value. self whileFalse: b]).
      |).
      traits string _AddSlotsIfAbsent: (|
        parent* = lobby.
        clone = (self).
        printString = (self).
        size = (self _StringSize).
        at: index = (self _StringAt: index).
        , other = (self _StringConcat: other).
        from: start To: end = (self _StringFrom: start To: end).
        = other = (self _Equal: other).
        != other = ((self = other) not).
      |).
      traits vector _AddSlotsIfAbsent: (|
        parent* = lobby.
        clone = (clone: 0).
        clone: size = (self _VectorClone: size).
        printString = ('(' , ((collect: [|:each| each printString]) join: ', ') , ')').
        size = (self _VectorSize).
        add: obj = (self _VectorAdd: obj).
        at: index = (self _VectorAt: index).
        at: index Put: object = (self _VectorAt: index Put: object).
        from: start To: end = (self _VectorFrom: start To: end).
        do: block = (|i| i: 0. [i < self size] whileTrue: [block value: (self at: i). i: i + 1]).
        select: block = (|v| v: clone. do: [|:each| (block value: each) ifTrue: [v add: each]]. v).
        collect: block = (|v| v: clone. do: [|:each| v add: (block value: each)]. v).
        join: s = (|v| do:[|:each| v isNil ifTrue: [v: each] False: [v: v , s , each]]. v).
        & obj = (add: obj. self).
      |).
      lobby _AddSlotsIfAbsent: (|
        printString = 'lobby'.
        isNil = false.
        & obj = (|v| v: traits vector clone. v add: self. v add: obj. v).
      |). 
    """);
  }

  /**
   * Parses the given [source] and executes it in the context of the [lobby].
   */
  SelfValue execute(String source) {
    return Parser(this, source).parse().execute(this);
  }

  /**
   * Sends message [name] to the receiver object at the first position in
   * [arguments], passing the remaining elements as [arguments]. This
   * must match the arity of the selector [name].
   */
  SelfValue send(String name, List<SelfValue> arguments) {
    final value = findSlot(arguments[0], name).value;
    if (value is SelfMethod) return value.activate(this, arguments);
    return value;
  }

  /**
   * Returns a slot named [name] of [obj].
   * Throws a runtime exception if there is no such slot.
   * Throws a runtime exception if there is more than one such slot.
   */
  Slot findSlot(SelfValue obj, String name) {
    final slot = _findSlot(obj, name, {});
    if (slot == null) {
      throw 'UnknownMessageSend($name)';
    }
    return slot;
  }

  Slot? _findSlot(SelfValue obj, String name, Set<SelfValue> visited) {
    if (!visited.contains(obj)) {
      visited.add(obj);
      final slots = _getSlots(obj);
      //print("$name: $slots");
      for (final slot in slots) {
        if (slot.name == name) {
          return slot;
        }
      }
      Slot? foundSlot;
      for (final slot in slots) {
        if (slot.parent) {
          final s = _findSlot(slot.value, name, visited);
          if (s != null) {
            if (foundSlot != null) {
              throw 'AmbiguousMessageSend($name)';
            }
            foundSlot = s;
          }
        }
      }
      return foundSlot;
    }
    return null;
  }

  /**
   * Returns the list of slots of any object, not only [SelfObject]s.
   * We special case numbers, strings and lists here.
   */
  List<Slot> _getSlots(SelfValue obj) {
    if (obj is num) return traitsNumber.slots;
    if (obj is String) return traitsString.slots;
    if (obj is List) return traitsVector.slots;
    if (obj is SelfObject) return obj.slots;
    return const <Slot>[];
  }
}
