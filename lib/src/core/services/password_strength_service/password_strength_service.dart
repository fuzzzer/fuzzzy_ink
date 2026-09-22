import '../../../fuzzy_vault/data/models/password_strength.dart';

class PasswordStrengthService {
  static const kMinLength = 'Length >= 8';
  static const kHasUppercase = 'Has uppercase';
  static const kHasLowercase = 'Has lowercase';
  static const kHasNumbers = 'Has numbers';
  static const kHasSpecialChars = 'Has special characters';

  static const _commonPasswords = <String>{
    '123456',
    'password',
    '12345678',
    'qwerty',
    '123456789',
    '12345',
    '1234',
    '111111',
    '1234567',
    'dragon',
    '123123',
    'baseball',
    'abc123',
    'football',
    'monkey',
    'letmein',
    'shadow',
    'master',
    'qwerty123',
    'mustang',
    'michael',
    'login',
    'admin',
    'welcome',
    'princess',
    'starwars',
    'passw0rd',
    'hello',
    'charlie',
    'donald',
    'trustno1',
    'iloveyou',
    'sunshine',
    '654321',
    'batman',
    'access',
  };

  static final _sequentialPattern = RegExp(
    '(012|123|234|345|456|567|678|789|abc|bcd|cde|def|efg|fgh|ghi|hij|ijk|jkl|klm|lmn|mno|nop|opq|pqr|qrs|rst|stu|tuv|uvw|vwx|wxy|xyz)',
    caseSensitive: false,
  );
  static final _repeatingPattern = RegExp(r'(.)\1{2,}');
  static final _nonLetterEdgesPattern = RegExp(r'^[^a-z]+|[^a-z]+$');

  PasswordStrength assess(String password) {
    final criteria = _evaluateCriteria(password);

    if (password.isEmpty || _isCommonPassword(password)) {
      return PasswordStrength(
        score: 0,
        level: PasswordStrengthLevel.weak,
        criteriaResults: criteria,
      );
    }

    final score = _calculateScore(password, criteria);

    return PasswordStrength(
      score: score,
      level: _scoreToLevel(score),
      criteriaResults: criteria,
    );
  }

  /// A common password padded with digits/symbols (`password123`, `!Qwerty1`)
  /// is still that common password.
  bool _isCommonPassword(String password) {
    final lowercased = password.toLowerCase();
    final core = lowercased.replaceAll(_nonLetterEdgesPattern, '');
    return _commonPasswords.contains(lowercased) ||
        _commonPasswords.contains(core);
  }

  Map<String, bool> _evaluateCriteria(String password) {
    return {
      kMinLength: password.length >= 8,
      kHasUppercase: password.contains(RegExp('[A-Z]')),
      kHasLowercase: password.contains(RegExp('[a-z]')),
      kHasNumbers: password.contains(RegExp('[0-9]')),
      kHasSpecialChars:
          password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{};:"|\\,.<>/?~`]')),
    };
  }

  int _calculateScore(String password, Map<String, bool> criteria) {
    var score = 0.0;

    score += (password.length * 5).clamp(0, 40);

    if (criteria[kHasUppercase]!) score += 15;
    if (criteria[kHasLowercase]!) score += 15;
    if (criteria[kHasNumbers]!) score += 15;
    if (criteria[kHasSpecialChars]!) score += 15;

    if (_sequentialPattern.hasMatch(password.toLowerCase())) score -= 15;
    if (_repeatingPattern.hasMatch(password)) score -= 15;
    if (password.length < 6) score -= 20;

    return score.round().clamp(0, 100);
  }

  PasswordStrengthLevel _scoreToLevel(int score) {
    if (score < 30) return PasswordStrengthLevel.weak;
    if (score < 55) return PasswordStrengthLevel.fair;
    if (score < 75) return PasswordStrengthLevel.good;
    return PasswordStrengthLevel.strong;
  }
}
