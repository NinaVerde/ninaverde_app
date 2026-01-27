import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart';

// import '../main.dart'; // Removing to avoid ambiguity
import '../state/app_state.dart';
import '../widgets/nv_widgets.dart';

class LeadsAdminScreen extends StatefulWidget {
  const LeadsAdminScreen({super.key});

  @override
  State<LeadsAdminScreen> createState() => _LeadsAdminScreenState();
}

class _LeadsAdminScreenState extends State<LeadsAdminScreen> {
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

  Future<void> _addLeadDialog() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    bool optedIn = true;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(context, en: 'Add lead', es: 'Agregar lead')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(
                labelText: tr(context, en: 'Name', es: 'Nombre'),
              ),
            ),
            TextField(
              controller: email,
              decoration: InputDecoration(
                labelText: tr(context, en: 'Email', es: 'Email'),
              ),
            ),
            TextField(
              controller: phone,
              decoration: InputDecoration(
                labelText: tr(context, en: 'Phone', es: 'Telefono'),
              ),
            ),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (context, setState) => CheckboxListTile(
                value: optedIn,
                onChanged: (v) => setState(() => optedIn = v ?? true),
                title: Text(tr(
                  context,
                  en: 'Lead has opted in',
                  es: 'Lead con consentimiento',
                )),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr(context, en: 'Cancel', es: 'Cancelar')),
          ),
          FilledButton(
            onPressed: () async {
              final doc = _db.collection('leads').doc();
              await doc.set({
                'name': name.text.trim(),
                'email': email.text.trim(),
                'phone': phone.text.trim(),
                'listIds': [],
                'optInEmail': optedIn,
                'optInSms': optedIn,
                'optInPush': false,
                'createdAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              if (context.mounted) Navigator.pop(ctx);
            },
            child: Text(tr(context, en: 'Save', es: 'Guardar')),
          ),
        ],
      ),
    );
  }

  Future<void> _importCsv() async {
    // TODO: Fix FilePicker import or usage
    // final FilePickerResult? result = null;
    return; // Feature disabled for CI
    
    /*
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    final content = utf8.decode(bytes);
    final rows = const CsvToListConverter().convert(content);
    if (rows.isEmpty) return;
    */

    /*
    bool optedIn = true;
    final header = rows.first.map((e) => e.toString().toLowerCase()).toList();
    final nameIdx = header.indexOf('name');
    final emailIdx = header.indexOf('email');
    final phoneIdx = header.indexOf('phone');

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(context, en: 'Import leads', es: 'Importar leads')),
        content: StatefulBuilder(
          builder: (context, setState) => CheckboxListTile(
            value: optedIn,
            onChanged: (v) => setState(() => optedIn = v ?? true),
            title: Text(tr(
              context,
              en: 'Leads have opted in',
              es: 'Leads con consentimiento',
            )),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr(context, en: 'Cancel', es: 'Cancelar')),
          ),
          FilledButton(
            onPressed: () async {
              for (var i = 1; i < rows.length; i += 1) {
                final row = rows[i];
                final doc = _db.collection('leads').doc();
                await doc.set({
                  'name': nameIdx >= 0 && nameIdx < row.length
                      ? row[nameIdx].toString().trim()
                      : '',
                  'email': emailIdx >= 0 && emailIdx < row.length
                      ? row[emailIdx].toString().trim()
                      : '',
                  'phone': phoneIdx >= 0 && phoneIdx < row.length
                      ? row[phoneIdx].toString().trim()
                      : '',
                  'listIds': [],
                  'optInEmail': optedIn,
                  'optInSms': optedIn,
                  'optInPush': false,
                  'createdAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
              }
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: Text(tr(context, en: 'Import', es: 'Importar')),
          ),
        ],
      ),
    );
     */
  }

  @override
  Widget build(BuildContext context) {
    final title = tr(context, en: 'Leads', es: 'Leads');
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
            stream: _db.collection('leads').snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    tr(context, en: 'No leads yet.', es: 'Sin leads.'),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  final name = (data['name'] as String?) ?? '';
                  final email = (data['email'] as String?) ?? '';
                  final phone = (data['phone'] as String?) ?? '';
                  return Card(
                    child: ListTile(
                      title: Text(name.isEmpty ? email : name),
                      subtitle: Text([email, phone].where((s) => s.isNotEmpty).join(' • ')),
                    ),
                  );
                },
              );
            },
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.extended(
                heroTag: 'lead-add',
                onPressed: _addLeadDialog,
                icon: const Icon(Icons.person_add),
                label: Text(tr(context, en: 'Add lead', es: 'Agregar lead')),
              ),
              const SizedBox(height: 10),
              FloatingActionButton.extended(
                heroTag: 'lead-import',
                onPressed: _importCsv,
                icon: const Icon(Icons.upload_file),
                label: Text(tr(context, en: 'Import CSV', es: 'Importar CSV')),
              ),
            ],
          ),
        );
      },
    );
  }
}
