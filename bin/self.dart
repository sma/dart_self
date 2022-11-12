import 'dart:io';

import 'package:self/self.dart';

void main(List<String> arguments) {
  final self = Self()..initialize();
  for (;;) {
    stdout.write('> ');
    final line = stdin.readLineSync();
    if (line == null) {
      stdout.writeln();
      break;
    }
    try {
      final result = self.execute(line);
      try {
        stdout.writeln(self.send('printString', [result]));
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
