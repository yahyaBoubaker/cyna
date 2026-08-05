import 'package:cyna_mobile/screens/orders_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('orderStatusLabel traduit les statuts connus', () {
    expect(orderStatusLabel('paid'), 'Payee');
    expect(orderStatusLabel('pending'), 'En attente');
    expect(orderStatusLabel('cancelled'), 'Annulee');
  });

  test('orderStatusLabel conserve un statut inconnu', () {
    expect(orderStatusLabel('refunded'), 'refunded');
  });
}
