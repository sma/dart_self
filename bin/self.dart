import 'dart:io';

import 'package:self/self.dart';

void main(List<String> arguments) {
  Self.initialize();
  for (;;) {
    stdout.write('> ');
    final line = stdin.readLineSync();
    if (line == null) {
      stdout.writeln();
      break;
    }
    try {
      final result = Self.execute(line);
      try {
        stdout.writeln(Self.send('printString', [result]));
      } on String catch (exception) {
        if (exception == 'UnknownMessageSend(printString)') {
          stdout.writeln('$result (no printString)');
        } else {
          rethrow;
        }
      }
    } catch (exception) {
      stdout.writeln('Exception: $exception');
    }
  }
}
