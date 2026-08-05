import 'package:cyna_mobile/screens/cart_checkout_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CartLine calcule le total selon la duree et la quantite', () {
    final line = CartLine(
      product: {'monthly_price': '12.50'},
      durationMonths: 12,
      quantity: 3,
    );

    expect(line.monthlyPrice, 12.5);
    expect(line.total, 450);
  });
}
