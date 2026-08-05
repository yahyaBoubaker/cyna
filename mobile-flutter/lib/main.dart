import 'package:flutter/material.dart';

import 'screens/account_screen.dart';
import 'screens/catalog_screen.dart';
import 'screens/cart_checkout_screen.dart';
import 'screens/home_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/product_detail_screen.dart';
import 'services/api_service.dart';
import 'widgets/state_widgets.dart';

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

// Coquille : 5 onglets (Accueil, Catalogue, Panier, Compte, Commandes).

class CynaShell extends StatefulWidget {
  const CynaShell({super.key});

  @override
  State<CynaShell> createState() => _CynaShellState();
}

class _CynaShellState extends State<CynaShell> {
  int index = 0;
  Map<String, dynamic>? user;
  final cart = <CartLine>[];
  bool sessionLoading = true;
  String? sessionError;

  @override
  void initState() {
    super.initState();
    restoreSession();
  }

  Future<void> restoreSession() async {
    setState(() {
      sessionLoading = true;
      sessionError = null;
    });

    try {
      final token = await api.readToken();
      if (token == null || token.isEmpty) {
        if (mounted) setState(() => sessionLoading = false);
        return;
      }

      final data = await api.get('/me');
      final restoredUser = data['user'];
      if (!mounted) return;
      setState(() {
        user = restoredUser is Map
            ? Map<String, dynamic>.from(restoredUser)
            : null;
        sessionLoading = false;
      });
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await api.clearToken();
        if (mounted) {
          setState(() {
            user = null;
            sessionLoading = false;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          sessionLoading = false;
          sessionError =
              'Impossible de verifier votre session. Verifiez votre connexion puis reessayez.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          sessionLoading = false;
          sessionError =
              'Impossible de verifier votre session. Verifiez votre connexion puis reessayez.';
        });
      }
    }
  }

  void addToCart(Map<String, dynamic> product, int durationMonths) {
    setState(() {
      final existing = cart.indexWhere(
        (line) =>
            '${line.product['id']}' == '${product['id']}' &&
            line.durationMonths == durationMonths,
      );
      if (existing >= 0) {
        cart[existing].quantity++;
      } else {
        cart.add(CartLine(product: product, durationMonths: durationMonths));
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product['name']} ajoute au panier')),
    );
  }

  void openProduct(int id) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductDetailScreen(productId: id, onAdd: addToCart),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cartItemCount = cart.fold<int>(0, (sum, line) => sum + line.quantity);
    if (sessionLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (sessionError != null) {
      return Scaffold(
        body: ErrorState(message: sessionError!, onRetry: restoreSession),
      );
    }

    final pages = [
      HomeScreen(onOpenProduct: openProduct, onSeeCatalog: () => setState(() => index = 1)),
      CatalogScreen(onOpenProduct: openProduct),
      CartScreen(
        cart: cart,
        isLoggedIn: user != null,
        onCartChanged: () => setState(() {}),
        onNeedLogin: () => setState(() => index = 3),
      ),
      AccountScreen(
        user: user,
        onLogin: (nextUser) => setState(() => user = nextUser),
        onLogout: () async {
          await api.clearToken();
          if (mounted) setState(() => user = null);
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
          IconButton(
            onPressed: () => setState(() => index = 2),
            icon: Badge(
              isLabelVisible: cartItemCount > 0,
              label: Text('$cartItemCount'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: index,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Catalogue'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: 'Panier'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Compte'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Commandes'),
        ],
      ),
    );
  }
}
