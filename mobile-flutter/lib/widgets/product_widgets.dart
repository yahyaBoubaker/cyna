import 'package:flutter/material.dart';

import '../services/api_service.dart';

class StockChip extends StatelessWidget {
  const StockChip({super.key, required this.stock});

  final dynamic stock;

  @override
  Widget build(BuildContext context) {
    if (stock == null) return const SizedBox.shrink();
    final value = int.tryParse('$stock') ?? 0;
    final available = value > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: available ? const Color(0xffe7f6ec) : const Color(0xfffdecea),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        available ? 'En stock ($value)' : 'Indisponible',
        style: TextStyle(
          color: available ? const Color(0xff2e7d32) : const Color(0xffb42318),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onOpen,
  });

  final Map<String, dynamic> product;
  final void Function(int id) onOpen;

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
              Image.network(
                '$image',
                height: 130,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${product['category_name'] ?? 'SaaS'}',
                        style: const TextStyle(
                          color: Color(0xff18a4bc),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      StockChip(stock: product['stock']),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${product['name']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product['description']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${euros(product['monthly_price'])}/mois',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      const Text(
                        'Voir le detail >',
                        style: TextStyle(
                          color: Color(0xff0b3a75),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
