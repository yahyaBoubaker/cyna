import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/product_widgets.dart';
import '../widgets/state_widgets.dart';

class HomeScreen extends StatefulWidget {
  final bool isActive;
  final void Function(int id) onOpenProduct;
  final VoidCallback onSeeCatalog;
  final void Function(Map<String, dynamic> category) onSelectCategory;

  const HomeScreen({
    super.key,
    required this.isActive,
    required this.onOpenProduct,
    required this.onSeeCatalog,
    required this.onSelectCategory,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> slides = [];
  List<Map<String, dynamic>> texts = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> featured = [];
  bool loading = true;
  String? errorMessage;
  Timer? syncTimer;

  @override
  void initState() {
    super.initState();
    load();
    startSync();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      startSync();
      if (widget.isActive) load(showLoading: false);
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
    super.dispose();
  }

  Future<void> load({bool showLoading = true}) async {
    if (mounted && showLoading) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }
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
        errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      if (showLoading ||
          (slides.isEmpty &&
              texts.isEmpty &&
              categories.isEmpty &&
              featured.isEmpty)) {
        setState(() {
          loading = false;
          errorMessage =
              'Impossible de charger l accueil. Verifiez votre connexion puis reessayez.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (errorMessage != null &&
        slides.isEmpty &&
        texts.isEmpty &&
        categories.isEmpty &&
        featured.isEmpty) {
      return ErrorState(message: errorMessage!, onRetry: load);
    }
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (errorMessage != null)
            ErrorState(message: errorMessage!, onRetry: load, compact: true),
          if (slides.isNotEmpty)
            HomeCarousel(slides: slides, onCta: widget.onSeeCatalog),
          const SizedBox(height: 16),
          ...texts.map((t) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${t['title']}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xff18a4bc))),
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
                  .map((c) => CategoryTile(
                        category: c,
                        onTap: () => widget.onSelectCategory(c),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          Text('Top produits du moment',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...featured.map(
              (p) => ProductCard(product: p, onOpen: widget.onOpenProduct)),
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
  Timer? timer;
  int page = 0;

  @override
  void initState() {
    super.initState();
    startAutoPlay();
  }

  void startAutoPlay() {
    timer?.cancel();
    if (widget.slides.length < 2) return;
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !controller.hasClients) return;
      final nextPage = (page + 1) % widget.slides.length;
      controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void didUpdateWidget(covariant HomeCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slides.length != widget.slides.length) {
      page = 0;
      startAutoPlay();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

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
                    colorFilter: ColorFilter.mode(
                      Colors.black.withValues(alpha: 0.45),
                      BlendMode.darken,
                    ),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${s['title']}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('${s['subtitle'] ?? ''}',
                        style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 8),
                    FilledButton(
                        onPressed: widget.onCta,
                        child: const Text('Voir les services')),
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
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.4),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
        padding: const EdgeInsets.all(12),
        alignment: Alignment.bottomLeft,
        child: Text('${category['name']}',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
