import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:8000/api',
);

void main() => runApp(const CynaApp());

class CynaApp extends StatelessWidget {
  const CynaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CYNA Mobile',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff0b3a75),
          primary: const Color(0xff0b3a75),
          secondary: const Color(0xff18a4bc),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfff4f7fb),
      ),
      home: const CynaShell(),
    );
  }
}

class ApiService {
  final storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> get(String path) async {
    final token = await storage.read(key: 'token');
    final response = await http.get(
      Uri.parse('$apiUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final token = await storage.read(key: 'token');
    final response = await http.post(
      Uri.parse('$apiUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<void> clearToken() => storage.delete(key: 'token');

  Map<String, dynamic> _decode(http.Response response) {
    final data = jsonDecode(response.body.isEmpty ? '{}' : response.body)
        as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? data['error'] ?? 'Erreur API');
    }
    return data;
  }
}

final api = ApiService();

const demoProducts = [
  {
    'id': 1,
    'name': 'Cyna SOC',
    'category_name': 'SOC',
    'description':
        'Supervision cyber 24/7, alerting, rapports mensuels et accompagnement analyste.',
    'monthly_price': '499.00',
  },
  {
    'id': 2,
    'name': 'Cyna EDR',
    'category_name': 'EDR',
    'description':
        'Protection endpoint avec detection comportementale et isolation machine.',
    'monthly_price': '19.90',
  },
  {
    'id': 3,
    'name': 'Cyna XDR',
    'category_name': 'XDR',
    'description':
        'Correlation endpoint, cloud, identite et reseau dans une vue unifiee.',
    'monthly_price': '899.00',
  },
];

class CynaShell extends StatefulWidget {
  const CynaShell({super.key});

  @override
  State<CynaShell> createState() => _CynaShellState();
}

class _CynaShellState extends State<CynaShell> {
  int index = 0;
  Map<String, dynamic>? user;
  final cart = <CartLine>[];

  void addToCart(Map<String, dynamic> product, int durationMonths) {
    setState(() {
      cart.add(CartLine(product: product, durationMonths: durationMonths));
      index = 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product['name']} ajoute au panier')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      CatalogScreen(onAdd: addToCart),
      CartScreen(cart: cart, onCartChanged: () => setState(() {})),
      AccountScreen(
        user: user,
        onLogin: (nextUser) => setState(() => user = nextUser),
        onLogout: () async {
          await api.clearToken();
          setState(() => user = null);
        },
      ),
      OrdersScreen(isLoggedIn: user != null),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined),
            SizedBox(width: 8),
            Text('CYNA'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('${cart.length} service(s)')),
          ),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Catalogue',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Panier',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Compte',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Commandes',
          ),
        ],
      ),
    );
  }
}

class CatalogScreen extends StatefulWidget {
  final void Function(Map<String, dynamic> product, int durationMonths) onAdd;

  const CatalogScreen({super.key, required this.onAdd});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late Future<List<Map<String, dynamic>>> products;
  String query = '';

  @override
  void initState() {
    super.initState();
    products = loadProducts();
  }

  Future<List<Map<String, dynamic>>> loadProducts() async {
    try {
      final data = await api.get('/products');
      final items = (data['items'] as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      return items;
    } catch (_) {
      return demoProducts.map((item) => Map<String, dynamic>.from(item)).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: products,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final filtered = snapshot.data!
            .where(
              (p) => '${p['name']} ${p['category_name']} ${p['description']}'
                  .toLowerCase()
                  .contains(query.toLowerCase()),
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const HeroPanel(),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Rechercher SOC, EDR, XDR',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                Chip(label: Text('SOC')),
                Chip(label: Text('EDR')),
                Chip(label: Text('XDR')),
                Chip(label: Text('Abonnement SaaS')),
              ],
            ),
            const SizedBox(height: 16),
            ...filtered.map(
              (product) => ProductCard(product: product, onAdd: widget.onAdd),
            ),
          ],
        );
      },
    );
  }
}

class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        gradient: LinearGradient(
          colors: [Color(0xff0b3a75), Color(0xff18a4bc)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CYNA Mobile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Acheter et suivre ses services SOC, EDR et XDR depuis une app mobile.',
            style: TextStyle(color: Colors.white, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class ProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final void Function(Map<String, dynamic> product, int durationMonths) onAdd;

  const ProductCard({super.key, required this.product, required this.onAdd});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  int duration = 12;

  @override
  Widget build(BuildContext context) {
    final price = double.tryParse('${widget.product['monthly_price']}') ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryBadge(text: '${widget.product['category_name'] ?? 'SaaS'}'),
                const Spacer(),
                Text(
                  '${price.toStringAsFixed(2)} EUR/mois',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.product['name']}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('${widget.product['description']}'),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1m')),
                ButtonSegment(value: 12, label: Text('12m')),
                ButtonSegment(value: 24, label: Text('24m')),
              ],
              selected: {duration},
              onSelectionChanged: (values) => setState(() => duration = values.first),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total estime: ${(price * duration).toStringAsFixed(2)} EUR',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => widget.onAdd(widget.product, duration),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryBadge extends StatelessWidget {
  final String text;

  const CategoryBadge({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xffe5f7fb),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xff0b3a75),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class CartLine {
  final Map<String, dynamic> product;
  final int durationMonths;

  CartLine({required this.product, required this.durationMonths});

  double get monthlyPrice => double.tryParse('${product['monthly_price']}') ?? 0;
  double get total => monthlyPrice * durationMonths;
}

class CartScreen extends StatefulWidget {
  final List<CartLine> cart;
  final VoidCallback onCartChanged;

  const CartScreen({
    super.key,
    required this.cart,
    required this.onCartChanged,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  String status = '';
  bool loading = false;

  double get total => widget.cart.fold(0, (sum, line) => sum + line.total);

  Future<void> checkout() async {
    setState(() {
      loading = true;
      status = '';
    });
    try {
      for (final line in widget.cart) {
        await api.post('/cart/items', {
          'productId': line.product['id'],
          'quantity': 1,
          'durationMonths': line.durationMonths,
        });
      }
      final order = await api.post('/checkout', {});
      widget.cart.clear();
      widget.onCartChanged();
      setState(() => status = 'Commande #${order['orderId']} validee');
    } catch (_) {
      setState(
        () => status =
            'Mode demo: checkout mock presente. Connecte Symfony pour creer la vraie commande.',
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cart.isEmpty) {
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
        ...widget.cart.asMap().entries.map((entry) {
          final index = entry.key;
          final line = entry.value;
          return Card(
            child: ListTile(
              title: Text('${line.product['name']}'),
              subtitle: Text('${line.durationMonths} mois'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  setState(() => widget.cart.removeAt(index));
                  widget.onCartChanged();
                },
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
                const Expanded(
                  child: Text(
                    'Total calcule par le backend au checkout',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                Text(
                  '${total.toStringAsFixed(2)} EUR',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: loading ? null : checkout,
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_outline),
          label: const Text('Valider la commande'),
        ),
        if (status.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(status),
        ],
      ],
    );
  }
}

class AccountScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  final void Function(Map<String, dynamic> user) onLogin;
  final Future<void> Function() onLogout;

  const AccountScreen({
    super.key,
    required this.user,
    required this.onLogin,
    required this.onLogout,
  });

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final email = TextEditingController(text: 'user@cyna.local');
  final password = TextEditingController(text: 'User123!');
  final firstName = TextEditingController(text: 'Demo');
  final lastName = TextEditingController(text: 'Mobile');
  String error = '';
  bool registerMode = false;

  Future<void> submit() async {
    setState(() => error = '');
    try {
      final data = await api.post(registerMode ? '/auth/register' : '/auth/login', {
        'email': email.text,
        'password': password.text,
        'firstName': firstName.text,
        'lastName': lastName.text,
      });
      await api.storage.write(key: 'token', value: data['token']);
      widget.onLogin(Map<String, dynamic>.from(data['user'] as Map));
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user != null) {
      final user = widget.user!;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const HeroPanel(),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text('${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'),
              subtitle: Text('${user['email']}'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Role'),
              subtitle: Text('${user['roles']}'),
            ),
          ),
          FilledButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('Deconnexion'),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          registerMode ? 'Creation de compte' : 'Connexion',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        if (registerMode) ...[
          TextField(
            controller: firstName,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Prenom',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: lastName,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Nom',
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: email,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Email',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: password,
          obscureText: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Mot de passe',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: submit,
          child: Text(registerMode ? 'Creer le compte' : 'Se connecter'),
        ),
        TextButton(
          onPressed: () => setState(() => registerMode = !registerMode),
          child: Text(
            registerMode ? 'Jai deja un compte' : 'Creer un compte',
          ),
        ),
        if (error.isNotEmpty)
          Text(error, style: const TextStyle(color: Colors.red)),
      ],
    );
  }
}

class OrdersScreen extends StatefulWidget {
  final bool isLoggedIn;

  const OrdersScreen({super.key, required this.isLoggedIn});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  Future<List<Map<String, dynamic>>>? orders;

  @override
  void didUpdateWidget(covariant OrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoggedIn && orders == null) {
      orders = loadOrders();
    }
  }

  Future<List<Map<String, dynamic>>> loadOrders() async {
    try {
      final data = await api.get('/me/orders');
      return (data['items'] as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return [
        {
          'id': 1001,
          'status': 'demo',
          'total': '5988.00',
          'created_at': 'presentation',
        },
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoggedIn) {
      return const EmptyState(
        icon: Icons.lock_outline,
        title: 'Connexion requise',
        text: 'Connecte-toi pour afficher les commandes depuis l API Symfony.',
      );
    }
    orders ??= loadOrders();
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: orders,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Aucune commande',
            text: 'Les commandes creees par le checkout apparaitront ici.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Commandes', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            ...snapshot.data!.map(
              (order) => Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: Text('Commande #${order['id']}'),
                  subtitle: Text('${order['status']} - ${order['created_at']}'),
                  trailing: Text('${order['total']} EUR'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: const Color(0xff0b3a75)),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
