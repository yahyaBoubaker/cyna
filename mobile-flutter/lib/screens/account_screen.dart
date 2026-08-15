import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/form_widgets.dart';
import 'address_screen.dart';
import 'contact_screen.dart';
import 'payments_screen.dart';

class AccountScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  final void Function(Map<String, dynamic> user) onLogin;
  final Future<void> Function() onLogout;

  const AccountScreen(
      {super.key,
      required this.user,
      required this.onLogin,
      required this.onLogout});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final code = TextEditingController();
  final resetCode = TextEditingController();
  final resetPassword = TextEditingController();
  String error = '';
  String info = '';
  String mode = 'login'; // login | register | code | forgot | reset
  bool loading = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    firstName.dispose();
    lastName.dispose();
    code.dispose();
    resetCode.dispose();
    resetPassword.dispose();
    super.dispose();
  }

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
        final data = await api.post(
            '/auth/login', {'email': email.text, 'password': password.text});
        if (!mounted) return;
        if (data['status'] == '2fa_required') {
          setState(() {
            info = '${data['message']}';
            mode = 'code';
          });
        }
      });

  // Etape 2 : le code a 6 chiffres delivre le jeton JWT.
  Future<void> verifyCode() => run(() async {
        final data = await api
            .post('/auth/verify-2fa', {'email': email.text, 'code': code.text});
        await api.saveToken('${data['token']}');
        if (!mounted) return;
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
        if (!mounted) return;
        setState(() {
          info = '${data['message']}';
          mode = 'login';
        });
      });

  Future<void> forgot() => run(() async {
        final data =
            await api.post('/auth/forgot-password', {'email': email.text});
        if (!mounted) return;
        setState(() {
          info = '${data['message']}';
          mode = 'reset';
        });
      });

  Future<void> resetForgottenPassword() => run(() async {
        final data = await api.post('/auth/reset-password', {
          'email': email.text,
          'code': resetCode.text,
          'newPassword': resetPassword.text,
        });
        if (!mounted) return;
        resetCode.clear();
        resetPassword.clear();
        password.clear();
        setState(() {
          info = '${data['message']}';
          mode = 'login';
        });
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
            'reset' => 'Nouveau mot de passe',
            _ => 'Connexion',
          },
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        if (info.isNotEmpty)
          Card(
            color: const Color(0xffe5f7fb),
            child:
                Padding(padding: const EdgeInsets.all(12), child: Text(info)),
          ),
        const SizedBox(height: 8),
        if (mode == 'code') ...[
          Field(
              controller: code,
              label: 'Code a 6 chiffres recu par e-mail',
              keyboard: TextInputType.number),
          FilledButton(
              onPressed: loading ? null : verifyCode,
              child: const Text('Se connecter')),
          TextButton(
              onPressed: loading ? null : login,
              child: const Text('Renvoyer un code')),
          TextButton(
            onPressed: () => setState(() {
              mode = 'login';
              info = '';
            }),
            child: const Text('Retour'),
          ),
        ] else if (mode == 'reset') ...[
          Text('Adresse : ${email.text}'),
          const SizedBox(height: 10),
          Field(
            controller: resetCode,
            label: 'Code de reinitialisation a 6 chiffres',
            keyboard: TextInputType.number,
          ),
          Field(
            controller: resetPassword,
            label: 'Nouveau mot de passe',
            obscure: true,
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Au moins 8 caracteres, avec majuscule, minuscule, chiffre et caractere special.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          FilledButton(
            onPressed: loading ? null : resetForgottenPassword,
            child: const Text('Reinitialiser le mot de passe'),
          ),
          TextButton(
            onPressed: loading
                ? null
                : () => setState(() {
                      mode = 'forgot';
                      info = '';
                    }),
            child: const Text('Renvoyer un code'),
          ),
          TextButton(
            onPressed: loading
                ? null
                : () => setState(() {
                      mode = 'login';
                      info = '';
                    }),
            child: const Text('Annuler'),
          ),
        ] else ...[
          if (mode == 'register') ...[
            Field(controller: firstName, label: 'Prenom'),
            Field(controller: lastName, label: 'Nom'),
          ],
          Field(
              controller: email,
              label: 'Email',
              keyboard: TextInputType.emailAddress),
          if (mode != 'forgot')
            Field(controller: password, label: 'Mot de passe', obscure: true),
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
            child: Text(
                mode == 'register' ? 'J ai deja un compte' : 'Creer un compte'),
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
        if (error.isNotEmpty)
          Text(error, style: const TextStyle(color: Colors.red)),
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
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileSettingsScreen(
                  user: user,
                  onUserUpdated: widget.onLogin,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Adresse de facturation'),
            subtitle: const Text(
                'Ajouter ou modifier l adresse utilisee au checkout'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AddressScreen(user: user)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.credit_card_outlined),
            title: const Text('Paiements'),
            subtitle:
                const Text('Consulter les paiements et les cartes masquees'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PaymentsScreen()),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Mes abonnements', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const SubscriptionsList(),
        const SizedBox(height: 16),
        Text('Aide et informations',
            style: Theme.of(context).textTheme.titleLarge),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.support_agent),
                title: const Text('Contacter le support'),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ContactScreen())),
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
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'))
        ],
      ),
    );
  }
}

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  final Map<String, dynamic> user;
  final void Function(Map<String, dynamic> user) onUserUpdated;

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late final TextEditingController firstName;
  late final TextEditingController lastName;
  late final TextEditingController newEmail;
  final emailPassword = TextEditingController();
  final currentPassword = TextEditingController();
  final newPassword = TextEditingController();
  String error = '';
  String info = '';
  bool loading = false;

  @override
  void initState() {
    super.initState();
    firstName =
        TextEditingController(text: '${widget.user['firstName'] ?? ''}');
    lastName = TextEditingController(text: '${widget.user['lastName'] ?? ''}');
    newEmail = TextEditingController(text: '${widget.user['email'] ?? ''}');
  }

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    newEmail.dispose();
    emailPassword.dispose();
    currentPassword.dispose();
    newPassword.dispose();
    super.dispose();
  }

  Future<void> run(Future<String?> Function() action) async {
    setState(() {
      loading = true;
      error = '';
      info = '';
    });
    try {
      final message = await action();
      if (mounted && message != null) setState(() => info = message);
    } catch (exception) {
      if (mounted) {
        setState(() {
          error = '$exception'.replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> saveIdentity() => run(() async {
        final data = await api.patch('/me', {
          'firstName': firstName.text.trim(),
          'lastName': lastName.text.trim(),
        });
        if (!mounted) return null;
        final rawUser = data['user'];
        if (rawUser is Map) {
          widget.onUserUpdated(Map<String, dynamic>.from(rawUser));
        }
        return 'Vos informations personnelles ont ete mises a jour.';
      });

  Future<void> requestEmailChange() => run(() async {
        final data = await api.post('/me/email', {
          'newEmail': newEmail.text.trim(),
          'password': emailPassword.text,
        });
        if (!mounted) return null;
        emailPassword.clear();
        return '${data['message']}';
      });

  Future<void> changePassword() => run(() async {
        final data = await api.post('/me/password', {
          'currentPassword': currentPassword.text,
          'newPassword': newPassword.text,
        });
        if (!mounted) return null;
        currentPassword.clear();
        newPassword.clear();
        return '${data['message']}';
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parametres du profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Informations personnelles',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Field(controller: firstName, label: 'Prenom'),
          Field(controller: lastName, label: 'Nom'),
          FilledButton(
            onPressed: loading ? null : saveIdentity,
            child: const Text('Enregistrer le profil'),
          ),
          const Divider(height: 40),
          Text('Changer d e-mail',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text(
              'Un lien de confirmation sera envoye a la nouvelle adresse.'),
          const SizedBox(height: 10),
          Field(
            controller: newEmail,
            label: 'Nouvelle adresse e-mail',
            keyboard: TextInputType.emailAddress,
          ),
          Field(
            controller: emailPassword,
            label: 'Mot de passe actuel',
            obscure: true,
          ),
          FilledButton.tonal(
            onPressed: loading ? null : requestEmailChange,
            child: const Text('Envoyer la confirmation'),
          ),
          const Divider(height: 40),
          Text('Changer de mot de passe',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Field(
            controller: currentPassword,
            label: 'Mot de passe actuel',
            obscure: true,
          ),
          Field(
            controller: newPassword,
            label: 'Nouveau mot de passe',
            obscure: true,
          ),
          const Text(
            'Au moins 8 caracteres, avec majuscule, minuscule, chiffre et caractere special.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          FilledButton.tonal(
            onPressed: loading ? null : changePassword,
            child: const Text('Modifier le mot de passe'),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (info.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child:
                  Text(info, style: const TextStyle(color: Color(0xff2e7d32))),
            ),
          if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(error, style: const TextStyle(color: Colors.red)),
            ),
        ],
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
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => error = null);
    api.items('/me/subscriptions').then((items) {
      if (mounted) setState(() => subs = items);
    }).catchError((_) {
      if (mounted) {
        setState(() => error = 'Impossible de charger les abonnements.');
      }
    });
  }

  Future<void> action(int id, String action) async {
    try {
      await api.patch('/me/subscriptions/$id', {'action': action});
      await load();
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Text(error!, style: const TextStyle(color: Colors.red));
    }
    if (subs == null) return const Center(child: CircularProgressIndicator());
    if (subs!.isEmpty) {
      return const Text('Aucun abonnement actif pour le moment.');
    }
    return Column(
      children: subs!.map((s) {
        final active = s['status'] == 'active' &&
            DateTime.tryParse('${s['ends_at']}')?.isAfter(DateTime.now()) ==
                true;
        return Card(
          child: ListTile(
            leading: Icon(active ? Icons.verified : Icons.history,
                color: active ? const Color(0xff2e7d32) : Colors.grey),
            title: Text('${s['product_name']}'),
            subtitle: Text('Jusqu au ${'${s['ends_at']}'.split(' ').first}'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => action(int.parse('${s['id']}'), value),
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'renew', child: Text('Renouveler 12 mois')),
                if (active)
                  const PopupMenuItem(value: 'cancel', child: Text('Resilier')),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
