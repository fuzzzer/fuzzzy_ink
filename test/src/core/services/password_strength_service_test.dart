import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_seal/src/core/services/password_strength_service/password_strength_service.dart';
import 'package:fuzzzy_seal/src/fuzzy_vault/data/models/password_strength.dart';

void main() {
  late PasswordStrengthService service;

  setUp(() {
    service = PasswordStrengthService();
  });

  test('assess returns weak for empty password', () {
    final result = service.assess('');
    expect(result.score, 0);
    expect(result.level, PasswordStrengthLevel.weak);
    expect(result.criteriaResults.values.every((v) => v == false), isTrue);
  });

  test('assess returns strong for complex password', () {
    final result = service.assess('Strong!2Password');
    expect(result.level, PasswordStrengthLevel.strong);
    expect(result.criteriaResults['Length >= 8'], isTrue);
    expect(result.criteriaResults['Has uppercase'], isTrue);
    expect(result.criteriaResults['Has lowercase'], isTrue);
    expect(result.criteriaResults['Has numbers'], isTrue);
    expect(result.criteriaResults['Has special characters'], isTrue);
  });

  test('assess deducts points for common patterns', () {
    final result1 = service.assess('password123');
    expect(result1.score, lessThan(40));
    expect(result1.level, PasswordStrengthLevel.weak);
  });
}
