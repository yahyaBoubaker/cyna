import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

// L'app consomme exactement la même API Symfony que le site web et le back-office.
// - Émulateur Android : 10.0.2.2 = localhost de la machine hôte.
// - Flutter web / desktop (flutter run -d chrome) : localhost directement.
// - Surchargeable : flutter run --dart-define=API_URL=http://192.168.x.x:8000/api (téléphone réel).
const _envApiUrl = String.fromEnvironment('API_URL');
final apiUrl = _envApiUrl.isNotEmpty
    ? _envApiUrl
    : (kIsWeb ? 'http://localhost:8000/api' : 'http://10.0.2.2:8000/api');

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

  Future<List<Map<String, dynamic>>> items(String path) async {
    final data = await get(path);
    return (data['items'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> clearToken() => storage.delete(key: 'token');

  Map<String, dynamic> _decode(http.Response response) {
    final data = jsonDecode(response.body.isEmpty ? '{}' : response.body)
        as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      // Erreurs de validation champ par champ (422) : afficher les messages
      // détaillés ("Le mot de passe doit contenir...") plutôt que juste "validation".
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        throw Exception(errors.values.join('\n'));
      }
      throw Exception(data['message'] ?? data['error'] ?? 'Erreur API');
    }
    return data;
  }
}

final api = ApiService();

String euros(dynamic value) =>
    '${(double.tryParse('$value') ?? 0).toStringAsFixed(2)} EUR';

// ---------------------------------------------------------------------------
// Coquille : 5 onglets (Accueil, Catalogue, Panier, Compte, Commandes)
// ---------------------------------------------------------------------------

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
    setState(() => cart.add(CartLine(product: product, durationMonths: durationMonths)));
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
          IconButton(
            onPressed: () => setState(() => index = 2),
            icon: Badge(
              isLabelVisible: cart.isNotEmpty,
              label: Text('${cart.length}'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: pages[index],
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

// ---------------------------------------------------------------------------
// Accueil : carrousel + textes + categories + top produits (memes API que le web)
// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  final void Function(int id) onOpenProduct;
  final VoidCallback onSeeCatalog;

  const HomeScreen({super.key, required this.onOpenProduct, required this.onSeeCatalog});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> slides = [];
  List<Map<String, dynamic>> texts = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> featured = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final results = await Future.wait([
        api.items('/home-carousel'),
        api.items('/home-texts'),
        api.items('/categories'),
        api.items('/featured-products'),
      ]);
      if (!mounted) return; // l'écran a pu être fermé pendant l'appel réseau
      setState(() {
        slides = results[0];
        texts = results[1];
        categories = results[2];
        featured = results[3];
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (slides.isNotEmpty) HomeCarousel(slides: slides, onCta: widget.onSeeCatalog),
          const SizedBox(height: 16),
          ...texts.map((t) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${t['title']}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xff18a4bc))),
                      const SizedBox(height: 6),
                      Text('${t['content']}'),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 8),
          Text('Nos categories', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: categories
                  .map((c) => CategoryTile(category: c, onTap: widget.onSeeCatalog))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          Text('Top produits du moment', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...featured.map((p) => ProductCard(product: p, onOpen: widget.onOpenProduct)),
        ],
      ),
    );
  }
}

class HomeCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> slides;
  final VoidCallback onCta;

  const HomeCarousel({super.key, required this.slides, required this.onCta});

  @override
  State<HomeCarousel> createState() => _HomeCarouselState();
}

class _HomeCarouselState extends State<HomeCarousel> {
  final controller = PageController();
  int page = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView(
            controller: controller,
            onPageChanged: (value) => setState(() => page = value),
            children: widget.slides.map((s) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  image: DecorationImage(
                    image: NetworkImage('${s['image_url']}'),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.45), BlendMode.darken),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${s['title']}',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('${s['subtitle'] ?? ''}', style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 8),
                    FilledButton(onPressed: widget.onCta, child: const Text('Voir les services')),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.slides.length,
            (i) => Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == page ? const Color(0xff18a4bc) : Colors.black26,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CategoryTile extends StatelessWidget {
  final Map<String, dynamic> category;
  final VoidCallback onTap;

  const CategoryTile({super.key, required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final image = category['image_url'];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xff102033),
          image: image != null
              ? DecorationImage(
                  image: NetworkImage('$image'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
                )
              : null,
        ),
        padding: const EdgeInsets.all(12),
        alignment: Alignment.bottomLeft,
        child: Text('${category['name']}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Catalogue : recherche serveur, tri, stock
// ---------------------------------------------------------------------------

class CatalogScreen extends StatefulWidget {
  final void Function(int id) onOpenProduct;

  const CatalogScreen({super.key, required this.onOpenProduct});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  List<Map<String, dynamic>> products = [];
  bool loading = true;
  String query = '';
  String sort = 'newest';
  bool inStockOnly = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final path = query.trim().isEmpty
          ? '/products?sort=$sort'
          : '/search?q=${Uri.encodeComponent(query)}&sort=$sort${inStockOnly ? '&inStock=1' : ''}';
      final items = await api.items(path);
      if (!mounted) return; // l'écran a pu être fermé pendant l'appel réseau
      setState(() {
        products = items;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            labelText: 'Rechercher SOC, EDR, XDR',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: load),
          ),
          onChanged: (value) => query = value,
          onSubmitted: (_) => load(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: sort,
                decoration: const InputDecoration(labelText: 'Trier par', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'newest', child: Text('Nouveaute')),
                  DropdownMenuItem(value: 'price_asc', child: Text('Prix croissant')),
                  DropdownMenuItem(value: 'price_desc', child: Text('Prix decroissant')),
                  DropdownMenuItem(value: 'name', child: Text('Nom (A-Z)')),
                ],
                onChanged: (value) {
                  sort = value ?? 'newest';
                  load();
                },
              ),
            ),
            const SizedBox(width: 10),
            FilterChip(
              label: const Text('En stock'),
              selected: inStockOnly,
              onSelected: (value) {
                inStockOnly = value;
                load();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
        if (!loading && products.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Aucun resultat.')),
        ...products.map((p) => ProductCard(product: p, onOpen: widget.onOpenProduct)),
      ],
    );
  }
}

class StockChip extends StatelessWidget {
  final dynamic stock;

  const StockChip({super.key, required this.stock});

  @override
  Widget build(BuildContext context) {
    if (stock == null) return const SizedBox.shrink();
    final s = int.tryParse('$stock') ?? 0;
    final ok = s > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ok ? const Color(0xffe7f6ec) : const Color(0xfffdecea),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        ok ? 'En stock ($s)' : 'Indisponible',
        style: TextStyle(
          color: ok ? const Color(0xff2e7d32) : const Color(0xffb42318),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final void Function(int id) onOpen;

  const ProductCard({super.key, required this.product, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final image = product['image_url'];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpen(int.parse('${product['id']}')),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image != null)
              Image.network('$image', height: 130, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('${product['category_name'] ?? 'SaaS'}',
                          style: const TextStyle(color: Color(0xff18a4bc), fontWeight: FontWeight.w800, fontSize: 12)),
                      const Spacer(),
                      StockChip(stock: product['stock']),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('${product['name']}', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('${product['description']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('${euros(product['monthly_price'])}/mois',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const Spacer(),
                      const Text('Voir le detail >', style: TextStyle(color: Color(0xff0b3a75), fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fiche produit : images, caracteristiques, dispo, CTA, similaires
// ---------------------------------------------------------------------------

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  final void Function(Map<String, dynamic> product, int durationMonths) onAdd;

  const ProductDetailScreen({super.key, required this.productId, required this.onAdd});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Map<String, dynamic>? product;
  String error = '';
  int duration = 12;

  @override
  void initState() {
    super.initState();
    api.get('/products/${widget.productId}').then((data) {
      if (mounted) setState(() => product = data);
    }).catchError((e) {
      if (mounted) setState(() => error = '$e');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(product?['name'] as String? ?? 'Produit')),
      body: product == null
          ? Center(child: error.isEmpty ? const CircularProgressIndicator() : Text(error))
          : buildDetail(context, product!),
    );
  }

  Widget buildDetail(BuildContext context, Map<String, dynamic> p) {
    final images = (p['images'] as List<dynamic>? ?? [])
        .map((i) => Map<String, dynamic>.from(i as Map))
        .toList();
    final similar = (p['similar'] as List<dynamic>? ?? [])
        .map((i) => Map<String, dynamic>.from(i as Map))
        .toList();
    final specs = '${p['technical_specs'] ?? ''}'
        .split('·')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final price = double.tryParse('${p['monthly_price']}') ?? 0;
    final available = (int.tryParse('${p['stock'] ?? 1}') ?? 0) > 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (images.isNotEmpty)
          SizedBox(
            height: 180,
            child: PageView(
              children: images
                  .map((i) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network('${i['url']}', fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                      ))
                  .toList(),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('${p['category_name'] ?? ''}',
                style: const TextStyle(color: Color(0xff18a4bc), fontWeight: FontWeight.w800)),
            const Spacer(),
            StockChip(stock: p['stock']),
          ],
        ),
        const SizedBox(height: 6),
        Text('${p['name']}', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('${p['description']}'),
        if (specs.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Caracteristiques techniques', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          ...specs.map((s) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check, size: 18, color: Color(0xff18a4bc)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(s)),
                ],
              )),
        ],
        const SizedBox(height: 14),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('1 mois')),
            ButtonSegment(value: 12, label: Text('12 mois')),
            ButtonSegment(value: 24, label: Text('24 mois')),
          ],
          selected: {duration},
          onSelectionChanged: (values) => setState(() => duration = values.first),
        ),
        const SizedBox(height: 10),
        Text('Total : ${(price * duration).toStringAsFixed(2)} EUR',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: available
              ? () {
                  widget.onAdd(p, duration);
                  Navigator.of(context).pop();
                }
              : null,
          icon: const Icon(Icons.add_shopping_cart),
          label: Text(available ? 'Ajouter au panier' : 'Indisponible'),
        ),
        if (similar.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Services similaires', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...similar.map((s) => Card(
                child: ListTile(
                  title: Text('${s['name']}'),
                  subtitle: Text('${euros(s['monthly_price'])}/mois'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(productId: int.parse('${s['id']}'), onAdd: widget.onAdd),
                  )),
                ),
              )),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Panier + checkout complet (adresse + paiement simule, comme le web)
// ---------------------------------------------------------------------------

class CartLine {
  final Map<String, dynamic> product;
  final int durationMonths;

  CartLine({required this.product, required this.durationMonths});

  double get monthlyPrice => double.tryParse('${product['monthly_price']}') ?? 0;
  double get total => monthlyPrice * durationMonths;
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

  double get total => cart.fold(0, (sum, line) => sum + line.total);

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
            child: ListTile(
              title: Text('${line.product['name']}'),
              subtitle: Text('${line.durationMonths} mois — ${euros(line.monthlyPrice)}/mois'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(line.total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      cart.removeAt(entry.key);
                      onCartChanged();
                    },
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

  Future<void> submit() async {
    setState(() {
      error = '';
      loading = true;
    });
    try {
      for (final lineItem in widget.cart) {
        await api.post('/cart/items', {
          'productId': lineItem.product['id'],
          'quantity': 1,
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

class Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboard;
  final bool obscure;

  const Field({super.key, required this.controller, required this.label, this.keyboard, this.obscure = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: obscure,
        decoration: InputDecoration(border: const OutlineInputBorder(), labelText: label),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compte : inscription (confirmation e-mail), connexion 2FA, mot de passe oublie,
// profil + abonnements + infos legales / contact / Instagram
// ---------------------------------------------------------------------------

class AccountScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  final void Function(Map<String, dynamic> user) onLogin;
  final Future<void> Function() onLogout;

  const AccountScreen({super.key, required this.user, required this.onLogin, required this.onLogout});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final code = TextEditingController();
  String error = '';
  String info = '';
  String mode = 'login'; // login | register | code | forgot
  bool loading = false;

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      error = '';
      loading = true;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // Etape 1 : le mot de passe seul ne suffit plus, l'API envoie un code 2FA par e-mail.
  Future<void> login() => run(() async {
        final data = await api.post('/auth/login', {'email': email.text, 'password': password.text});
        if (data['status'] == '2fa_required') {
          setState(() {
            info = '${data['message']}';
            mode = 'code';
          });
        }
      });

  // Etape 2 : le code a 6 chiffres delivre le jeton JWT.
  Future<void> verifyCode() => run(() async {
        final data = await api.post('/auth/verify-2fa', {'email': email.text, 'code': code.text});
        await api.storage.write(key: 'token', value: '${data['token']}');
        widget.onLogin(Map<String, dynamic>.from(data['user'] as Map));
        code.clear();
        setState(() => mode = 'login');
      });

  // L'inscription ne connecte pas : le compte doit d'abord etre confirme par e-mail.
  Future<void> register() => run(() async {
        final data = await api.post('/auth/register', {
          'email': email.text,
          'password': password.text,
          'firstName': firstName.text,
          'lastName': lastName.text,
        });
        setState(() {
          info = '${data['message']}';
          mode = 'login';
        });
      });

  Future<void> forgot() => run(() async {
        final data = await api.post('/auth/forgot-password', {'email': email.text});
        setState(() => info = '${data['message']} Saisissez ensuite le code recu sur la page de connexion du site web pour reinitialiser.');
      });

  @override
  Widget build(BuildContext context) {
    if (widget.user != null) return buildProfile(context, widget.user!);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          switch (mode) {
            'register' => 'Creation de compte',
            'code' => 'Verification en deux etapes',
            'forgot' => 'Mot de passe oublie',
            _ => 'Connexion',
          },
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        if (info.isNotEmpty)
          Card(
            color: const Color(0xffe5f7fb),
            child: Padding(padding: const EdgeInsets.all(12), child: Text(info)),
          ),
        const SizedBox(height: 8),
        if (mode == 'code') ...[
          Field(controller: code, label: 'Code a 6 chiffres recu par e-mail', keyboard: TextInputType.number),
          FilledButton(onPressed: loading ? null : verifyCode, child: const Text('Se connecter')),
          TextButton(onPressed: loading ? null : login, child: const Text('Renvoyer un code')),
          TextButton(
            onPressed: () => setState(() {
              mode = 'login';
              info = '';
            }),
            child: const Text('Retour'),
          ),
        ] else ...[
          if (mode == 'register') ...[
            Field(controller: firstName, label: 'Prenom'),
            Field(controller: lastName, label: 'Nom'),
          ],
          Field(controller: email, label: 'Email', keyboard: TextInputType.emailAddress),
          if (mode != 'forgot') Field(controller: password, label: 'Mot de passe', obscure: true),
          if (mode == 'register')
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Au moins 8 caracteres, une majuscule, une minuscule, un chiffre et un caractere special. Un e-mail de confirmation sera envoye.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          FilledButton(
            onPressed: loading
                ? null
                : switch (mode) {
                    'register' => register,
                    'forgot' => forgot,
                    _ => login,
                  },
            child: Text(switch (mode) {
              'register' => 'Creer le compte',
              'forgot' => 'Envoyer le code',
              _ => 'Se connecter',
            }),
          ),
          TextButton(
            onPressed: () => setState(() {
              mode = mode == 'register' ? 'login' : 'register';
              info = '';
            }),
            child: Text(mode == 'register' ? 'J ai deja un compte' : 'Creer un compte'),
          ),
          if (mode == 'login')
            TextButton(
              onPressed: () => setState(() {
                mode = 'forgot';
                info = '';
              }),
              child: const Text('Mot de passe oublie'),
            ),
          if (mode == 'forgot')
            TextButton(
              onPressed: () => setState(() {
                mode = 'login';
                info = '';
              }),
              child: const Text('Retour a la connexion'),
            ),
        ],
        if (error.isNotEmpty) Text(error, style: const TextStyle(color: Colors.red)),
      ],
    );
  }

  Widget buildProfile(BuildContext context, Map<String, dynamic> user) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text('${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'),
            subtitle: Text('${user['email']}'),
          ),
        ),
        const SizedBox(height: 8),
        Text('Mes abonnements', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const SubscriptionsList(),
        const SizedBox(height: 16),
        Text('Aide et informations', style: Theme.of(context).textTheme.titleLarge),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.support_agent),
                title: const Text('Contacter le support'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.gavel_outlined),
                title: const Text('Mentions legales'),
                onTap: () => showInfoDialog(
                  context,
                  'Mentions legales',
                  'CYNA est une societe fictive editee dans le cadre d un projet d etude. Aucune offre commerciale reelle. Donnees personnelles : mots de passe stockes haches, numeros de carte jamais conserves. Droits RGPD via la page Contact.',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('CGU'),
                onTap: () => showInfoDialog(
                  context,
                  'Conditions generales d utilisation',
                  'Plateforme de demonstration. La commande necessite un compte confirme par e-mail et une double authentification. Paiement simule : aucune somme debitee. Abonnements 1, 12 ou 24 mois. Service fourni en l etat a des fins pedagogiques.',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Instagram : @h3hitema'),
                subtitle: const Text('instagram.com/h3hitema'),
                onTap: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: widget.onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Deconnexion'),
        ),
      ],
    );
  }

  void showInfoDialog(BuildContext context, String title, String body) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fermer'))],
      ),
    );
  }
}

class SubscriptionsList extends StatefulWidget {
  const SubscriptionsList({super.key});

  @override
  State<SubscriptionsList> createState() => _SubscriptionsListState();
}

class _SubscriptionsListState extends State<SubscriptionsList> {
  List<Map<String, dynamic>>? subs;

  @override
  void initState() {
    super.initState();
    api.items('/me/subscriptions').then((items) {
      if (mounted) setState(() => subs = items);
    }).catchError((_) {
      if (mounted) setState(() => subs = []);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (subs == null) return const Center(child: CircularProgressIndicator());
    if (subs!.isEmpty) return const Text('Aucun abonnement actif pour le moment.');
    return Column(
      children: subs!.map((s) {
        final active = s['status'] == 'active' && DateTime.tryParse('${s['ends_at']}')?.isAfter(DateTime.now()) == true;
        return Card(
          child: ListTile(
            leading: Icon(active ? Icons.verified : Icons.history, color: active ? const Color(0xff2e7d32) : Colors.grey),
            title: Text('${s['product_name']}'),
            subtitle: Text('Jusqu au ${'${s['ends_at']}'.split(' ').first}'),
            trailing: Text(active ? 'Actif' : 'Expire'),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Contact + chatbot (memes reponses que le web, gerees en back-office)
// ---------------------------------------------------------------------------

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final email = TextEditingController();
  final subject = TextEditingController();
  final message = TextEditingController();
  final question = TextEditingController();
  List<Map<String, dynamic>> responses = [];
  final chat = <Map<String, String>>[
    {'from': 'bot', 'text': 'Bonjour ! Posez-moi une question (prix, essai gratuit, factures...).'},
  ];
  bool sent = false;

  @override
  void initState() {
    super.initState();
    api.items('/chatbot').then((items) {
      if (mounted) setState(() => responses = items);
    }).catchError((_) {});
  }

  String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u');

  void ask() {
    final q = question.text.trim();
    if (q.isEmpty) return;
    final nq = normalize(q);
    String answer =
        'Je n ai pas la reponse a cette question. Utilisez le formulaire ci-dessous : un conseiller vous repondra sous 24 h.';
    for (final r in responses) {
      final keywords = '${r['keywords']}'.split(',');
      if (keywords.any((k) => k.trim().isNotEmpty && nq.contains(normalize(k.trim())))) {
        answer = '${r['answer']}';
        break;
      }
    }
    setState(() {
      chat.add({'from': 'user', 'text': q});
      chat.add({'from': 'bot', 'text': answer});
      question.clear();
    });
  }

  Future<void> send() async {
    await api.post('/contact', {
      'email': email.text,
      'subject': subject.text,
      'message': message.text,
    });
    setState(() => sent = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Assistant CYNA', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...chat.map((m) => Align(
                alignment: m['from'] == 'bot' ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  constraints: const BoxConstraints(maxWidth: 300),
                  decoration: BoxDecoration(
                    color: m['from'] == 'bot' ? const Color(0xffeef3fb) : const Color(0xff0b3a75),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${m['text']}',
                      style: TextStyle(color: m['from'] == 'bot' ? Colors.black87 : Colors.white)),
                ),
              )),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: question,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Votre question...'),
                  onSubmitted: (_) => ask(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: ask, icon: const Icon(Icons.send)),
            ],
          ),
          const Divider(height: 32),
          Text('Laisser un message', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Field(controller: email, label: 'Email', keyboard: TextInputType.emailAddress),
          Field(controller: subject, label: 'Sujet'),
          Field(controller: message, label: 'Message'),
          FilledButton(onPressed: send, child: const Text('Envoyer')),
          if (sent)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Message envoye. Un conseiller vous repondra sous 24 h ouvrees.'),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Historique des commandes : date, duree, statut, total
// ---------------------------------------------------------------------------

class OrdersScreen extends StatefulWidget {
  final bool isLoggedIn;

  const OrdersScreen({super.key, required this.isLoggedIn});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  Future<List<Map<String, dynamic>>>? orders;

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoggedIn) {
      return const EmptyState(
        icon: Icons.lock_outline,
        title: 'Connexion requise',
        text: 'Connectez-vous pour afficher vos commandes.',
      );
    }
    orders ??= api.items('/me/orders');
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
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => orders = api.items('/me/orders'));
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Mes commandes', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              ...snapshot.data!.map((order) {
                final status = switch ('${order['status']}') {
                  'paid' => 'Payee',
                  'pending' => 'En attente',
                  'cancelled' => 'Annulee',
                  _ => '${order['status']}',
                };
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: Text('Commande #${order['id']} — ${order['first_item'] ?? ''}'),
                    subtitle: Text(
                      '${'${order['created_at']}'.split(' ').first} · ${order['duration_months'] ?? '-'} mois · $status',
                    ),
                    trailing: Text(euros(order['total']), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const EmptyState({super.key, required this.icon, required this.title, required this.text});

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
