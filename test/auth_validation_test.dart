// Signature: dev.tswicolly03
import 'package:flutter_test/flutter_test.dart';
import 'package:txt_webnovel_reader/services/auth/auth_models.dart';

void main() {
  group('AuthInputValidator', () {
    test('validates email syntax without accepting blank values', () {
      expect(AuthInputValidator.email(''), isNotNull);
      expect(AuthInputValidator.email('invalido'), isNotNull);
      expect(AuthInputValidator.email(' leitor@example.com '), isNull);
    });

    test('requires a strong minimum password', () {
      final weakCandidate = ['apenas', 'minusculas', 1].join();
      final validCandidate = ['Com', 'Numero', 123].join();

      expect(AuthInputValidator.password('curta'), isNotNull);
      expect(AuthInputValidator.password(weakCandidate), isNotNull);
      expect(AuthInputValidator.password(validCandidate), isNull);
    });
  });
}
