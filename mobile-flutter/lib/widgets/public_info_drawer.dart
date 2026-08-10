import 'package:flutter/material.dart';

import '../screens/contact_screen.dart';

class PublicInfoDrawer extends StatelessWidget {
  const PublicInfoDrawer({super.key});

  static const legalNotice =
      'CYNA est une societe fictive editee dans le cadre d un projet d etude. '
      'Aucune offre commerciale reelle. Donnees personnelles : mots de passe '
      'stockes haches, numeros de carte jamais conserves. Droits RGPD via la '
      'page Contact.';

  static const terms =
      'Plateforme de demonstration. La commande necessite un compte confirme '
      'par e-mail et une double authentification. Paiement simule : aucune '
      'somme debitee. Abonnements 1, 12 ou 24 mois. Service fourni en l etat '
      'a des fins pedagogiques.';

  void openPage(BuildContext context, Widget page) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute(builder: (_) => page));
  }

  void showInformation(BuildContext context, String title, String body) {
    final navigator = Navigator.of(context);
    navigator.pop();
    showDialog<void>(
      context: navigator.context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const DrawerHeader(
              margin: EdgeInsets.zero,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    child: Icon(Icons.shield_outlined, size: 30),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CYNA',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800),
                        ),
                        Text('Aide et informations'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.support_agent),
              title: const Text('Contacter le support'),
              subtitle: const Text('Assistant et formulaire de contact'),
              onTap: () => openPage(context, const ContactScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.gavel_outlined),
              title: const Text('Mentions legales'),
              onTap: () => showInformation(
                context,
                'Mentions legales',
                legalNotice,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('CGU'),
              onTap: () => showInformation(
                context,
                'Conditions generales d utilisation',
                terms,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Instagram : @h3hitema'),
              subtitle: const Text('instagram.com/h3hitema'),
              onTap: () => showInformation(
                context,
                'Instagram',
                'Retrouvez H3 HITEMA sur instagram.com/h3hitema.',
              ),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Ces informations sont accessibles sans connexion.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
