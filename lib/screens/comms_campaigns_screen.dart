import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// import '../main.dart'; // Removing to avoid ambiguity
import '../state/app_state.dart';
import '../widgets/nv_widgets.dart';

class CommsCampaignsScreen extends StatefulWidget {
  const CommsCampaignsScreen({super.key});

  @override
  State<CommsCampaignsScreen> createState() => _CommsCampaignsScreenState();
}

class _CommsCampaignsScreenState extends State<CommsCampaignsScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userDocStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _db.collection('users').doc(user.uid).snapshots();
  }

  bool _isAdmin(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['isAdmin'] == true) return true;
    if ((data['role'] as String?)?.toLowerCase() == 'admin') return true;
    return false;
  }

  Future<void> _newCampaignDialog() async {
    final name = TextEditingController();
    final title = TextEditingController();
    final subject = TextEditingController();
    final body = TextEditingController();
    String channel = 'email';
    String audience = 'all_users';
    DateTime? scheduledAt;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(context, en: 'New campaign', es: 'Nueva campana')),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: tr(context, en: 'Name', es: 'Nombre'),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: channel,
                items: const [
                  DropdownMenuItem(value: 'email', child: Text('Email')),
                  DropdownMenuItem(value: 'sms', child: Text('SMS')),
                  DropdownMenuItem(value: 'push', child: Text('Push')),
                ],
                onChanged: (v) => channel = v ?? 'email',
                decoration: InputDecoration(
                  labelText: tr(context, en: 'Channel', es: 'Canal'),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: audience,
                items: [
                  DropdownMenuItem(
                    value: 'all_users',
                    child: Text(tr(context, en: 'All users', es: 'Usuarios')),
                  ),
                  DropdownMenuItem(
                    value: 'all_leads',
                    child: Text(tr(context, en: 'All leads', es: 'Leads')),
                  ),
                ],
                onChanged: (v) => audience = v ?? 'all_users',
                decoration: InputDecoration(
                  labelText: tr(context, en: 'Audience', es: 'Audiencia'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: title,
                decoration: InputDecoration(
                  labelText: tr(context, en: 'Title (push)', es: 'Titulo (push)'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: subject,
                decoration: InputDecoration(
                  labelText: tr(context, en: 'Subject (email)', es: 'Asunto'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: body,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: tr(context, en: 'Message', es: 'Mensaje'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await _pickSchedule();
                  if (picked == null) return;
                  scheduledAt = picked;
                },
                icon: const Icon(Icons.schedule),
                label: Text(tr(context, en: 'Schedule', es: 'Programar')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr(context, en: 'Cancel', es: 'Cancelar')),
          ),
          FilledButton(
            onPressed: () async {
              final navigator = Navigator.of(ctx);
              final doc = _db.collection('campaigns').doc();
              await doc.set({
                'name': name.text.trim(),
                'channel': channel,
                'audienceType': audience,
                'title': title.text.trim(),
                'subject': subject.text.trim(),
                'body': body.text.trim(),
                'status': 'scheduled',
                'scheduleAt': scheduledAt == null
                    ? FieldValue.serverTimestamp()
                    : Timestamp.fromDate(scheduledAt!),
                'createdAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              if (!ctx.mounted) return;
              navigator.pop();
            },
            child: Text(tr(context, en: 'Save', es: 'Guardar')),
          ),
        ],
      ),
    );
  }

  Future<DateTime?> _pickSchedule() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return null;
    if (!mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return null;
    return DateTime(
      picked.year,
      picked.month,
      picked.day,
      time.hour,
      time.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = tr(context, en: 'Campaigns', es: 'Campanas');
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userDocStream(),
      builder: (context, snapshot) {
        final admin = _isAdmin(snapshot.data?.data());
        if (!admin) {
          return Scaffold(
            appBar: NvAppBar(tickerVisible: AppState.of(context).showTicker.value, title: title, showBack: true),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr(
                    context,
                    en:
                        'Access denied. Set role="admin" or isAdmin=true on your user document in Firestore.',
                    es:
                        'Acceso denegado. Configura role="admin" o isAdmin=true en tu usuario de Firestore.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: NvAppBar(tickerVisible: AppState.of(context).showTicker.value, title: title, showBack: true),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _db.collection('campaigns').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Text(tr(context, en: 'No campaigns yet.', es: 'Sin campanas.')),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  final name = (data['name'] as String?) ?? '';
                  final channel = (data['channel'] as String?) ?? '';
                  final status = (data['status'] as String?) ?? '';
                  return Card(
                    child: ListTile(
                      title: Text(name.isEmpty ? channel : name),
                      subtitle: Text('$channel • $status'),
                    ),
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _newCampaignDialog,
            icon: const Icon(Icons.add),
            label: Text(tr(context, en: 'New campaign', es: 'Nueva campana')),
          ),
        );
      },
    );
  }
}
