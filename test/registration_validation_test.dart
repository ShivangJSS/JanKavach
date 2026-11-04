import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Beneficiary Name Validation Tests', () {
    final nameRegex = RegExp(r'^[a-zA-Z\s]+$');

    test('Valid alphabetical names with spaces pass validation', () {
      expect(nameRegex.hasMatch('John Doe'), isTrue);
      expect(nameRegex.hasMatch('Ramesh Kumar'), isTrue);
      expect(nameRegex.hasMatch('Anita'), isTrue);
      expect(nameRegex.hasMatch('Mary Jane Watson'), isTrue);
    });

    test('Names with digits are rejected', () {
      expect(nameRegex.hasMatch('user 5'), isFalse);
      expect(nameRegex.hasMatch('John2'), isFalse);
      expect(nameRegex.hasMatch('12345'), isFalse);
      expect(nameRegex.hasMatch('Rahul 123'), isFalse);
    });

    test('Names with special characters are rejected', () {
      expect(nameRegex.hasMatch('user@name'), isFalse);
      expect(nameRegex.hasMatch('John#Doe'), isFalse);
      expect(nameRegex.hasMatch('Ramesh-Kumar'), isFalse);
      expect(nameRegex.hasMatch('Test!'), isFalse);
      expect(nameRegex.hasMatch('Anita_Sharma'), isFalse);
    });
  });
}
