import 'package:cyna_mobile/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('euros', () {
    test('formate un nombre avec deux decimales', () {
      expect(euros(19.9), '19.90 EUR');
    });

    test('utilise zero pour une valeur invalide', () {
      expect(euros('invalide'), '0.00 EUR');
    });
  });

  test('ApiException expose un message lisible', () {
    const error = ApiException('Session expiree', statusCode: 401);

    expect(error.toString(), 'Session expiree');
    expect(error.statusCode, 401);
  });
}
