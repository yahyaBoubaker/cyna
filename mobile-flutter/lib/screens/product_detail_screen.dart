import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/product_widgets.dart';
import '../widgets/state_widgets.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  final void Function(Map<String, dynamic> product, int durationMonths) onAdd;

  const ProductDetailScreen(
      {super.key, required this.productId, required this.onAdd});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Map<String, dynamic>? product;
  String error = '';
  int duration = 12;
  Timer? syncTimer;

  @override
  void initState() {
    super.initState();
    load();
    syncTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => load(showLoading: false),
    );
  }

  @override
  void dispose() {
    syncTimer?.cancel();
    super.dispose();
  }

  Future<void> load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        product = null;
        error = '';
      });
    }

    try {
      final data = await api.get('/products/${widget.productId}');
      if (mounted) setState(() => product = data);
    } catch (_) {
      if (mounted) {
        if (showLoading || product == null) {
          setState(() {
            error =
                'Impossible de charger ce produit. Verifiez votre connexion puis reessayez.';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(product?['name'] as String? ?? 'Produit')),
      body: product == null
          ? error.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ErrorState(message: error, onRetry: load)
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
                        child: Image.network('${i['url']}',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink()),
                      ))
                  .toList(),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('${p['category_name'] ?? ''}',
                style: const TextStyle(
                    color: Color(0xff18a4bc), fontWeight: FontWeight.w800)),
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
          Text('Caracteristiques techniques',
              style: Theme.of(context).textTheme.titleMedium),
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
          onSelectionChanged: (values) =>
              setState(() => duration = values.first),
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
          Text('Services similaires',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...similar.map((s) => Card(
                child: ListTile(
                  title: Text('${s['name']}'),
                  subtitle: Text('${euros(s['monthly_price'])}/mois'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(
                        productId: int.parse('${s['id']}'),
                        onAdd: widget.onAdd),
                  )),
                ),
              )),
        ],
      ],
    );
  }
}
