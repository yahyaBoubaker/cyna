import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/invoice_pdf_service.dart';
import '../widgets/state_widgets.dart';

String orderStatusLabel(dynamic value) => switch ('$value') {
      'paid' => 'Payee',
      'pending' => 'En attente',
      'cancelled' => 'Annulee',
      _ => '$value',
    };

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
    required this.isLoggedIn,
    required this.refreshVersion,
  });

  final bool isLoggedIn;
  final int refreshVersion;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  Future<List<Map<String, dynamic>>>? orders;
  String query = '';
  String? selectedYear;
  bool newestFirst = true;

  @override
  void didUpdateWidget(covariant OrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoggedIn != widget.isLoggedIn ||
        oldWidget.refreshVersion != widget.refreshVersion) {
      orders = null;
    }
  }

  Future<void> reload() async {
    final request = api.items('/me/orders');
    setState(() => orders = request);
    try {
      await request;
    } catch (_) {
      // FutureBuilder affiche l etat d erreur et le bouton de relance.
    }
  }

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
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ErrorState(
            message:
                'Impossible de charger les commandes. Verifiez votre connexion puis reessayez.',
            onRetry: reload,
          );
        }

        final items = snapshot.data ?? const <Map<String, dynamic>>[];
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Aucune commande',
            text: 'Les commandes creees par le checkout apparaitront ici.',
          );
        }

        final years = items
            .map((order) => '${order['created_at'] ?? ''}'.split('-').first)
            .where((year) => year.length == 4)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
        final normalizedQuery = query.trim().toLowerCase();
        final filtered = items.where((order) {
          final year = '${order['created_at'] ?? ''}'.split('-').first;
          if (selectedYear != null && year != selectedYear) return false;
          if (normalizedQuery.isEmpty) return true;
          return '${order['id']} ${order['first_item'] ?? ''} ${order['status'] ?? ''}'
              .toLowerCase()
              .contains(normalizedQuery);
        }).toList()
          ..sort((a, b) {
            final comparison =
                '${a['created_at']}'.compareTo('${b['created_at']}');
            return newestFirst ? -comparison : comparison;
          });

        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Mes commandes',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Rechercher un numero ou un service',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => query = value),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: selectedYear,
                      decoration: const InputDecoration(
                        labelText: 'Annee',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Toutes')),
                        ...years.map((year) =>
                            DropdownMenuItem(value: year, child: Text(year))),
                      ],
                      onChanged: (value) =>
                          setState(() => selectedYear = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    tooltip: newestFirst
                        ? 'Plus recentes en premier'
                        : 'Plus anciennes en premier',
                    onPressed: () => setState(() => newestFirst = !newestFirst),
                    icon: Icon(newestFirst
                        ? Icons.arrow_downward
                        : Icons.arrow_upward),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Aucune commande ne correspond aux filtres.'),
                ),
              ...filtered.map((order) {
                final status = orderStatusLabel(order['status']);
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: Text(
                      'Commande #${order['id']} - ${order['first_item'] ?? ''}',
                    ),
                    subtitle: Text(
                      '${'${order['created_at']}'.split(' ').first} - '
                      '${order['duration_months'] ?? '-'} mois - $status',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          euros(order['total']),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Icon(Icons.chevron_right, size: 20),
                      ],
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(
                          orderId: int.parse('${order['id']}'),
                        ),
                      ),
                    ),
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

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? order;
  String? errorMessage;
  bool loading = true;
  bool invoiceLoading = false;
  String? invoiceError;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      final data = await api.get('/me/orders/${widget.orderId}');
      if (!mounted) return;
      setState(() {
        order = data;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage =
            'Impossible de charger cette commande. Verifiez votre connexion puis reessayez.';
      });
    }
  }

  Future<void> downloadInvoice() async {
    setState(() {
      invoiceLoading = true;
      invoiceError = null;
    });
    try {
      final data = await api.get('/me/orders/${widget.orderId}/invoice');
      if (!mounted) return;
      await shareInvoicePdf(data);
    } catch (_) {
      if (mounted) {
        setState(() {
          invoiceError =
              'Impossible de generer la facture. Verifiez votre connexion puis reessayez.';
        });
      }
    } finally {
      if (mounted) setState(() => invoiceLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Commande #${widget.orderId}')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? ErrorState(message: errorMessage!, onRetry: load)
              : buildOrder(context, order!),
    );
  }

  Widget buildOrder(BuildContext context, Map<String, dynamic> data) {
    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    final createdAt = '${data['created_at'] ?? ''}'.split(' ').first;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recapitulatif',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _DetailRow(label: 'Numero', value: '#${data['id']}'),
                _DetailRow(label: 'Date', value: createdAt),
                _DetailRow(
                  label: 'Statut',
                  value: orderStatusLabel(data['status']),
                ),
                _DetailRow(label: 'Total', value: euros(data['total'])),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Services commandes',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucune ligne disponible pour cette commande.'),
            ),
          ),
        ...items.map(
          (item) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['product_name'] ?? 'Service CYNA'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _DetailRow(
                    label: 'Duree',
                    value: '${item['duration_months'] ?? '-'} mois',
                  ),
                  _DetailRow(
                    label: 'Quantite',
                    value: '${item['quantity'] ?? '-'}',
                  ),
                  _DetailRow(
                    label: 'Prix mensuel',
                    value: euros(item['unit_monthly_price']),
                  ),
                  _DetailRow(
                    label: 'Total de la ligne',
                    value: euros(item['line_total']),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: invoiceLoading ? null : downloadInvoice,
          icon: invoiceLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined),
          label: const Text('Telecharger la facture PDF'),
        ),
        if (invoiceError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              invoiceError!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child:
                  Text(label, style: const TextStyle(color: Colors.black54))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
