import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/form_widgets.dart';
import '../widgets/state_widgets.dart';

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final company = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final line1 = TextEditingController();
  final line2 = TextEditingController();
  final city = TextEditingController();
  final region = TextEditingController();
  final postalCode = TextEditingController();
  final phone = TextEditingController();
  final country = TextEditingController(text: 'France');
  bool loading = true;
  bool saving = false;
  String? loadError;
  String message = '';
  String saveError = '';

  @override
  void initState() {
    super.initState();
    firstName.text = '${widget.user['firstName'] ?? ''}';
    lastName.text = '${widget.user['lastName'] ?? ''}';
    load();
  }

  @override
  void dispose() {
    company.dispose();
    firstName.dispose();
    lastName.dispose();
    line1.dispose();
    line2.dispose();
    city.dispose();
    region.dispose();
    postalCode.dispose();
    phone.dispose();
    country.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final data = await api.get('/me/address');
      if (!mounted) return;
      final address = data['address'];
      if (address is Map) fill(Map<String, dynamic>.from(address));
      setState(() => loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError =
            'Impossible de charger votre adresse. Verifiez votre connexion puis reessayez.';
      });
    }
  }

  void fill(Map<String, dynamic> address) {
    company.text = '${address['company'] ?? ''}';
    firstName.text = '${address['first_name'] ?? firstName.text}';
    lastName.text = '${address['last_name'] ?? lastName.text}';
    line1.text = '${address['line1'] ?? ''}';
    line2.text = '${address['line2'] ?? ''}';
    city.text = '${address['city'] ?? ''}';
    region.text = '${address['region'] ?? ''}';
    postalCode.text = '${address['postal_code'] ?? ''}';
    phone.text = '${address['phone'] ?? ''}';
    country.text = '${address['country'] ?? 'France'}';
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      saveError = '';
      message = '';
    });
    try {
      final data = await api.put('/me/address', {
        'company': company.text.trim(),
        'firstName': firstName.text.trim(),
        'lastName': lastName.text.trim(),
        'line1': line1.text.trim(),
        'line2': line2.text.trim(),
        'city': city.text.trim(),
        'region': region.text.trim(),
        'postalCode': postalCode.text.trim(),
        'phone': phone.text.trim(),
        'country': country.text.trim(),
      });
      if (!mounted) return;
      final address = data['address'];
      if (address is Map) fill(Map<String, dynamic>.from(address));
      setState(() => message = 'Adresse de facturation enregistree.');
    } catch (exception) {
      if (mounted) {
        setState(() {
          saveError = '$exception'.replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adresse de facturation')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : loadError != null
              ? ErrorState(message: loadError!, onRetry: load)
              : buildForm(context),
    );
  }

  Widget buildForm(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Cette adresse sera proposee automatiquement lors du checkout.',
        ),
        const SizedBox(height: 16),
        Field(controller: company, label: 'Entreprise (optionnel)'),
        Row(
          children: [
            Expanded(child: Field(controller: firstName, label: 'Prenom')),
            const SizedBox(width: 10),
            Expanded(child: Field(controller: lastName, label: 'Nom')),
          ],
        ),
        Field(controller: line1, label: 'Adresse'),
        Field(controller: line2, label: 'Complement (optionnel)'),
        Row(
          children: [
            Expanded(child: Field(controller: postalCode, label: 'Code postal')),
            const SizedBox(width: 10),
            Expanded(child: Field(controller: city, label: 'Ville')),
          ],
        ),
        Field(controller: region, label: 'Region (optionnel)'),
        Row(
          children: [
            Expanded(child: Field(controller: country, label: 'Pays')),
            const SizedBox(width: 10),
            Expanded(
              child: Field(
                controller: phone,
                label: 'Telephone',
                keyboard: TextInputType.phone,
              ),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: saving ? null : save,
          icon: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Enregistrer l adresse'),
        ),
        if (message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(message, style: const TextStyle(color: Color(0xff2e7d32))),
          ),
        if (saveError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(saveError, style: const TextStyle(color: Colors.red)),
          ),
      ],
    );
  }
}
