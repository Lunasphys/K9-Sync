import 'package:flutter_test/flutter_test.dart';
import 'package:k9sync/core/extensions/string_ext.dart';

void main() {
  group('StringExt.isNotBlank', () {
    test('a normal non-empty string is not blank', () {
      expect('Nami'.isNotBlank, isTrue);
    });

    test('an empty string is blank', () {
      expect(''.isNotBlank, isFalse);
    });

    test('a whitespace-only string is blank', () {
      expect('   '.isNotBlank, isFalse);
    });

    test('a string with leading/trailing whitespace around real content is not blank', () {
      expect('  Nami  '.isNotBlank, isTrue);
    });

    test('a tab/newline-only string is blank', () {
      expect('\t\n'.isNotBlank, isFalse);
    });
  });

  group('StringExt.capitalize', () {
    test('capitalizes the first letter and lowercases the rest', () {
      expect('nami'.capitalize, 'Nami');
    });

    test('an already-capitalized word is unchanged', () {
      expect('Nami'.capitalize, 'Nami');
    });

    test('an all-uppercase word is normalized to a single capital', () {
      expect('NAMI'.capitalize, 'Nami');
    });

    test('an empty string is returned unchanged', () {
      expect(''.capitalize, '');
    });

    test('a single character is uppercased', () {
      expect('n'.capitalize, 'N');
    });

    test('a mixed-case word is normalized', () {
      expect('nAmI'.capitalize, 'Nami');
    });
  });
}
