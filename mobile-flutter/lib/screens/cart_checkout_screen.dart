import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/form_widgets.dart';
import '../widgets/state_widgets.dart';

class CartLine {
  final Map<String, dynamic> product;
  int durationMonths;
  int quantity;

  CartLine({
    required this.product,
    required this.durationMonths,
    this.quantity = 1,
  });

  double get monthlyPrice => double.tryParse('${product['monthly_price']}') ?? 0;
  double get total => monthlyPrice * durationMonths * quantity;
}

class CartScreen extends StatelessWidget {
  final List<CartLine> cart;
  final bool isLoggedIn;
  final VoidCallback onCartChanged;
  final VoidCallback onNeedLogin;

  const CartScreen({
    super.key,
    required this.cart,
    required this.isLoggedIn,
    required this.onCartChanged,
    required this.onNeedLogin,
  });

  double get total => cart.fold(0.0, (sum, line) => sum + line.total);

  @override
  Widget build(BuildContext context) {
    if (cart.isEmpty) {
      return const EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Panier vide',
        text: 'Ajoute un service depuis le catalogue pour preparer une commande.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Panier', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        ...cart.asMap().entries.map((entry) {
          final line = entry.value;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${line.product['name']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          cart.removeAt(entry.key);
                          onCartChanged();
                        },
                      ),
                    ],
                  ),
                  Text('${euros(line.monthlyPrice)}/mois'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: line.durationMonths,
                          decoration: const InputDecoration(
                            labelText: 'Duree',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('1 mois')),
                            DropdownMenuItem(value: 12, child: Text('12 mois')),
                            DropdownMenuItem(value: 24, child: Text('24 mois')),
                          ],
                          onChanged: (value) {
                            line.durationMonths = value ?? line.durationMonths;
                            onCartChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        children: [
                          const Text('Quantite'),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Diminuer',
                                onPressed: line.quantity > 1
                                    ? () {
                                        line.quantity--;
                                        onCartChanged();
                                      }
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text(
                                '${line.quantity}',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              IconButton(
                                tooltip: 'Augmenter',
                                onPressed: line.quantity < 99
                                    ? () {
                                        line.quantity++;
                                        onCartChanged();
                                      }
                                    : null,
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${line.total.toStringAsFixed(2)} EUR',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xff102033),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(child: Text('Total estime', style: TextStyle(color: Colors.white))),
                Text('${total.toStringAsFixed(2)} EUR',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () {
            if (!isLoggedIn) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Connectez-vous pour finaliser la commande.')),
              );
              onNeedLogin();
              return;
            }
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CheckoutScreen(cart: cart, onDone: onCartChanged),
            ));
          },
          icon: const Icon(Icons.lock_outline),
          label: const Text('Passer au checkout'),
        ),
      ],
    );
  }
}

class CheckoutScreen extends StatefulWidget {
  final List<CartLine> cart;
  final VoidCallback onDone;

  const CheckoutScreen({super.key, required this.cart, required this.onDone});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final line1 = TextEditingController();
  final city = TextEditingController();
  final postalCode = TextEditingController();
  final country = TextEditingController(text: 'France');
  final phone = TextEditingController();
  final cardName = TextEditingController();
  final cardNumber = TextEditingController();
  final cardExpiry = TextEditingController();
  final cvv = TextEditingController();
  String error = '';
  bool loading = false;
  Map<String, dynamic>? order;

  @override
  void initState() {
    super.initState();
    // Pre-remplit avec l'adresse deja enregistree cote profil / checkout web.
    api.get('/me/address').then((data) {
      final a = data['address'];
      if (a is Map && mounted) {
        setState(() {
          firstName.text = '${a['first_name'] ?? ''}';
          lastName.text = '${a['last_name'] ?? ''}';
          line1.text = '${a['line1'] ?? ''}';
          city.text = '${a['city'] ?? ''}';
          postalCode.text = '${a['postal_code'] ?? ''}';
          country.text = '${a['country'] ?? 'France'}';
          phone.text = '${a['phone'] ?? ''}';
        });
      }
    }).catchError((_) {});
  }

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    line1.dispose();
    city.dispose();
    postalCode.dispose();
    country.dispose();
    phone.dispose();
    cardName.dispose();
    cardNumber.dispose();
    cardExpiry.dispose();
    cvv.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      error = '';
      loading = true;
    });
    try {
      for (final lineItem in widget.cart) {
        await api.post('/cart/items', {
          'productId': lineItem.product['id'],
          'quantity': lineItem.quantity,
          'durationMonths': lineItem.durationMonths,
        });
      }
      final result = await api.post('/checkout', {
        'address': {
          'firstName': firstName.text,
          'lastName': lastName.text,
          'line1': line1.text,
          'city': city.text,
          'postalCode': postalCode.text,
          'country': country.text,
          'phone': phone.text,
        },
        'payment': {
          'cardName': cardName.text,
          'cardNumber': cardNumber.text,
          'cardExpiry': cardExpiry.text,
          'cvv': cvv.text,
        },
      });
      widget.cart.clear();
      widget.onDone();
      if (mounted) setState(() => order = result);
    } catch (e) {
      if (mounted) setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (order != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirmation')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle, size: 64, color: Color(0xff2e7d32)),
              const SizedBox(height: 16),
              Text('Commande #${order!['orderId']} confirmee',
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Payee avec la carte de ${order!['payment']?['cardName']} se terminant par ${order!['payment']?['last4']}. Retrouvez la facture dans l onglet Commandes.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Retour')),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Adresse de facturation', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Field(controller: firstName, label: 'Prenom')),
            const SizedBox(width: 10),
            Expanded(child: Field(controller: lastName, label: 'Nom')),
          ]),
          Field(controller: line1, label: 'Adresse'),
          Row(children: [
            Expanded(child: Field(controller: postalCode, label: 'Code postal')),
            const SizedBox(width: 10),
            Expanded(child: Field(controller: city, label: 'Ville')),
          ]),
          Row(children: [
            Expanded(child: Field(controller: country, label: 'Pays')),
            const SizedBox(width: 10),
            Expanded(child: Field(controller: phone, label: 'Telephone (optionnel)')),
          ]),
          const SizedBox(height: 14),
          Text('Paiement (simulation)', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Aucune carte reelle n est debitee : le numero complet et le CVV ne sont jamais stockes.'),
          const SizedBox(height: 10),
          Field(controller: cardName, label: 'Nom sur la carte'),
          Field(controller: cardNumber, label: 'Numero de carte (16 chiffres)', keyboard: TextInputType.number),
          Row(children: [
            Expanded(child: Field(controller: cardExpiry, label: 'MM/AA')),
            const SizedBox(width: 10),
            Expanded(child: Field(controller: cvv, label: 'CVV', keyboard: TextInputType.number)),
          ]),
          if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: loading ? null : submit,
            icon: loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.lock_outline),
            label: const Text('Valider la commande'),
          ),
        ],
      ),
    );
  }
}
