import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/form_widgets.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final email = TextEditingController();
  final subject = TextEditingController();
  final message = TextEditingController();
  final question = TextEditingController();
  List<Map<String, dynamic>> responses = [];
  final chat = <Map<String, String>>[
    {'from': 'bot', 'text': 'Bonjour ! Posez-moi une question (prix, essai gratuit, factures...).'},
  ];
  bool sent = false;

  @override
  void initState() {
    super.initState();
    api.items('/chatbot').then((items) {
      if (mounted) setState(() => responses = items);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    email.dispose();
    subject.dispose();
    message.dispose();
    question.dispose();
    super.dispose();
  }

  String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u');

  void ask() {
    final q = question.text.trim();
    if (q.isEmpty) return;
    final nq = normalize(q);
    String answer =
        'Je n ai pas la reponse a cette question. Utilisez le formulaire ci-dessous : un conseiller vous repondra sous 24 h.';
    for (final r in responses) {
      final keywords = '${r['keywords']}'.split(',');
      if (keywords.any((k) => k.trim().isNotEmpty && nq.contains(normalize(k.trim())))) {
        answer = '${r['answer']}';
        break;
      }
    }
    setState(() {
      chat.add({'from': 'user', 'text': q});
      chat.add({'from': 'bot', 'text': answer});
      question.clear();
    });
  }

  Future<void> send() async {
    await api.post('/contact', {
      'email': email.text,
      'subject': subject.text,
      'message': message.text,
    });
    if (mounted) setState(() => sent = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Assistant CYNA', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...chat.map((m) => Align(
                alignment: m['from'] == 'bot' ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  constraints: const BoxConstraints(maxWidth: 300),
                  decoration: BoxDecoration(
                    color: m['from'] == 'bot' ? const Color(0xffeef3fb) : const Color(0xff0b3a75),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${m['text']}',
                      style: TextStyle(color: m['from'] == 'bot' ? Colors.black87 : Colors.white)),
                ),
              )),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: question,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Votre question...'),
                  onSubmitted: (_) => ask(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: ask, icon: const Icon(Icons.send)),
            ],
          ),
          const Divider(height: 32),
          Text('Laisser un message', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Field(controller: email, label: 'Email', keyboard: TextInputType.emailAddress),
          Field(controller: subject, label: 'Sujet'),
          Field(controller: message, label: 'Message'),
          FilledButton(onPressed: send, child: const Text('Envoyer')),
          if (sent)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Message envoye. Un conseiller vous repondra sous 24 h ouvrees.'),
            ),
        ],
      ),
    );
  }
}
