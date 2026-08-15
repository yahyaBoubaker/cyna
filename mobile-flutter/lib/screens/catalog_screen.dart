import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/product_widgets.dart';
import '../widgets/state_widgets.dart';

String buildCatalogSearchPath({
  required String query,
  required String mode,
  required String sort,
  String scope = 'all',
  String? minPrice,
  String? maxPrice,
  bool inStockOnly = false,
  String? category,
}) {
  final parameters = <String, String>{
    'sort': sort,
    if (query.trim().isNotEmpty) 'q': query.trim(),
    if (query.trim().isNotEmpty) 'mode': mode,
    if (query.trim().isNotEmpty) 'scope': scope,
    if (minPrice != null && minPrice.isNotEmpty) 'minPrice': minPrice,
    if (maxPrice != null && maxPrice.isNotEmpty) 'maxPrice': maxPrice,
    if (inStockOnly) 'inStock': '1',
    if (category != null && category.isNotEmpty) 'category': category,
  };
  return Uri(path: '/search', queryParameters: parameters).toString();
}

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    required this.isActive,
    required this.onOpenProduct,
    this.categorySlug,
  });

  final bool isActive;
  final void Function(int id) onOpenProduct;
  final String? categorySlug;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  List<Map<String, dynamic>> products = [];
  bool loading = true;
  String? errorMessage;
  String? validationMessage;
  final queryController = TextEditingController();
  final minPriceController = TextEditingController();
  final maxPriceController = TextEditingController();
  String mode = 'contains';
  String scope = 'all';
  String sort = 'newest';
  bool inStockOnly = false;
  int _requestVersion = 0;
  Timer? syncTimer;
  String? categorySlug;
  List<Map<String, dynamic>> categories = [];

  @override
  void initState() {
    super.initState();
    categorySlug = widget.categorySlug;
    load();
    loadCategories();
    startSync();
  }

  @override
  void didUpdateWidget(covariant CatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      startSync();
      if (widget.isActive) load(showLoading: false);
    }
    if (oldWidget.categorySlug != widget.categorySlug) {
      categorySlug = widget.categorySlug;
      load();
    }
  }

  void startSync() {
    syncTimer?.cancel();
    if (!widget.isActive) return;
    syncTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => load(showLoading: false),
    );
  }

  @override
  void dispose() {
    syncTimer?.cancel();
    queryController.dispose();
    minPriceController.dispose();
    maxPriceController.dispose();
    super.dispose();
  }

  String? normalizedPrice(TextEditingController controller) {
    final value = controller.text.trim().replaceAll(',', '.');
    return value.isEmpty ? null : value;
  }

  Future<void> loadCategories() async {
    try {
      final items = await api.items('/categories');
      if (mounted) setState(() => categories = items);
    } catch (_) {
      // Le catalogue reste utilisable sans ce filtre.
    }
  }

  Future<void> load({bool showLoading = true}) async {
    final requestVersion = ++_requestVersion;
    if (showLoading) {
      setState(() {
        loading = true;
        errorMessage = null;
        validationMessage = null;
      });
    }

    try {
      final minPrice = normalizedPrice(minPriceController);
      final maxPrice = normalizedPrice(maxPriceController);
      final minValue = minPrice == null ? null : double.tryParse(minPrice);
      final maxValue = maxPrice == null ? null : double.tryParse(maxPrice);
      if ((minPrice != null && minValue == null) ||
          (maxPrice != null && maxValue == null) ||
          (minValue != null && minValue < 0) ||
          (maxValue != null && maxValue < 0) ||
          (minValue != null && maxValue != null && minValue > maxValue)) {
        if (!mounted || requestVersion != _requestVersion) return;
        setState(() {
          loading = false;
          validationMessage =
              'Verifiez les prix : ils doivent etre positifs et le minimum ne peut pas depasser le maximum.';
        });
        return;
      }
      final path = buildCatalogSearchPath(
        query: queryController.text,
        mode: mode,
        scope: scope,
        sort: sort,
        minPrice: minPrice,
        maxPrice: maxPrice,
        inStockOnly: inStockOnly,
        category: categorySlug,
      );
      final items = await api.items(path);
      if (!mounted || requestVersion != _requestVersion) return;

      setState(() {
        products = items;
        loading = false;
        errorMessage = null;
        validationMessage = null;
      });
    } catch (_) {
      if (!mounted || requestVersion != _requestVersion) return;
      if (showLoading || products.isEmpty) {
        setState(() {
          loading = false;
          errorMessage =
              'Impossible de charger le catalogue. Verifiez votre connexion puis reessayez.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: queryController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            labelText: 'Rechercher SOC, EDR, XDR',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: load,
            ),
          ),
          onSubmitted: (_) => load(),
        ),
        const SizedBox(height: 10),
        if (categories.isNotEmpty) ...[
          DropdownButtonFormField<String?>(
            initialValue: categorySlug,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.category_outlined),
              labelText: 'Categorie',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(
                  value: null, child: Text('Toutes les categories')),
              ...categories.map((category) => DropdownMenuItem(
                    value: '${category['slug']}',
                    child: Text('${category['name']}'),
                  )),
            ],
            onChanged: (value) {
              setState(() => categorySlug = value);
              load();
            },
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey(sort),
                initialValue: sort,
                decoration: const InputDecoration(
                  labelText: 'Trier par',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'newest', child: Text('Nouveaute')),
                  DropdownMenuItem(
                    value: 'price_asc',
                    child: Text('Prix croissant'),
                  ),
                  DropdownMenuItem(
                    value: 'price_desc',
                    child: Text('Prix decroissant'),
                  ),
                  DropdownMenuItem(value: 'name', child: Text('Nom (A-Z)')),
                ],
                onChanged: (value) {
                  sort = value ?? 'newest';
                  load();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.tune),
            title: const Text('Recherche avancee'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: scope,
                decoration: const InputDecoration(
                  labelText: 'Rechercher dans',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'all', child: Text('Tous les champs')),
                  DropdownMenuItem(value: 'name', child: Text('Nom')),
                  DropdownMenuItem(
                      value: 'description', child: Text('Description')),
                  DropdownMenuItem(
                      value: 'specs',
                      child: Text('Caracteristiques techniques')),
                ],
                onChanged: (value) => setState(() => scope = value ?? 'all'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(mode),
                initialValue: mode,
                decoration: const InputDecoration(
                  labelText: 'Correspondance du texte',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'contains', child: Text('Contient')),
                  DropdownMenuItem(
                      value: 'starts', child: Text('Commence par')),
                  DropdownMenuItem(
                      value: 'exact', child: Text('Correspondance exacte')),
                  DropdownMenuItem(
                      value: 'fuzzy', child: Text('Orthographe proche')),
                ],
                onChanged: (value) =>
                    setState(() => mode = value ?? 'contains'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minPriceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Prix minimum',
                        suffixText: 'EUR',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: maxPriceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Prix maximum',
                        suffixText: 'EUR',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title:
                    const Text('Afficher uniquement les services disponibles'),
                value: inStockOnly,
                onChanged: (value) => setState(() => inStockOnly = value),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          mode = 'contains';
                          scope = 'all';
                          sort = 'newest';
                          inStockOnly = false;
                          categorySlug = null;
                          queryController.clear();
                          minPriceController.clear();
                          maxPriceController.clear();
                        });
                        load();
                      },
                      child: const Text('Reinitialiser'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: load,
                      child: const Text('Appliquer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
        if (!loading && errorMessage != null)
          ErrorState(message: errorMessage!, onRetry: load, compact: true),
        if (!loading && validationMessage != null)
          Card(
            color: const Color(0xfffff3e0),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(validationMessage!),
            ),
          ),
        if (!loading &&
            errorMessage == null &&
            validationMessage == null &&
            products.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Aucun resultat.'),
          ),
        if (!loading && errorMessage == null && validationMessage == null)
          ...products.map(
            (product) => ProductCard(
              product: product,
              onOpen: widget.onOpenProduct,
            ),
          ),
      ],
    );
  }
}
