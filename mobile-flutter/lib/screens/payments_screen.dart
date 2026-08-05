import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/state_widgets.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<Map<String, dynamic>>? payments;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      payments = null;
      errorMessage = null;
    });
    try {
      final items = await api.items('/me/payments');
      if (!mounted) return;
      setState(() => payments = items);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage =
            'Impossible de charger les paiements. Verifiez votre connexion puis reessayez.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique des paiements')),
      body: errorMessage != null
          ? ErrorState(message: errorMessage!, onRetry: load)
          : payments == null
              ? const Center(child: CircularProgressIndicator())
              : buildList(context),
    );
  }

  Widget buildList(BuildContext context) {
    if (payments!.isEmpty) {
      return const EmptyState(
        icon: Icons.credit_card_off_outlined,
        title: 'Aucun paiement',
        text: 'Les paiements de vos commandes apparaitront ici.',
      );
    }

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Pour votre securite, seuls le nom du porteur et les quatre derniers chiffres sont conserves.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...payments!.map((payment) {
            final status = '${payment['status']}' == 'paid' ? 'Paye' : '${payment['status']}';
            final date = '${payment['created_at'] ?? ''}'.split(' ').first;
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.credit_card)),
                title: Text('**** **** **** ${payment['card_last4'] ?? '----'}'),
                subtitle: Text(
                  '${payment['card_name'] ?? 'Porteur non renseigne'}\n'
                  'Commande #${payment['order_id']} - $date',
                ),
                isThreeLine: true,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      euros(payment['amount']),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(status, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
