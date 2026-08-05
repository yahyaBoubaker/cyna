import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cyna_mobile/widgets/state_widgets.dart';

void main() {
  testWidgets('EmptyState affiche son contenu', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Aucune commande',
            text: 'Les commandes apparaitront ici.',
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
    expect(find.text('Aucune commande'), findsOneWidget);
    expect(find.text('Les commandes apparaitront ici.'), findsOneWidget);
  });

  testWidgets('ErrorState permet de relancer le chargement', (tester) async {
    var retries = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorState(
            message: 'Le catalogue est indisponible.',
            onRetry: () => retries++,
          ),
        ),
      ),
    );

    expect(find.text('Connexion impossible'), findsOneWidget);
    expect(find.text('Le catalogue est indisponible.'), findsOneWidget);

    await tester.tap(find.text('Reessayer'));
    expect(retries, 1);
  });
}
