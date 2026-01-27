// import 'dart:io'; // Unused

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';


// import '../main.dart'; // Removing to avoid ambiguity
import '../state/app_state.dart';
import '../models/event_promo_model.dart';
// import '../services/translation_service.dart'; // Unused
import '../widgets/nv_widgets.dart';
import '../widgets/admin/event_editor_sheet.dart';

class EventPromoAdminScreen extends StatefulWidget {
  const EventPromoAdminScreen({super.key});

  @override
  State<EventPromoAdminScreen> createState() => _EventPromoAdminScreenState();
}

class _EventPromoAdminScreenState extends State<EventPromoAdminScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  // final _storage = FirebaseStorage.instance; // Unused
  // final _picker = ImagePicker(); // Unused

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userDocStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _db.collection('users').doc(user.uid).snapshots();
  }

  bool _isAdmin(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['isAdmin'] == true) return true;
    if ((data['role'] as String?)?.toLowerCase() == 'admin') return true;
    return false;
  }


  Future<void> _openEditor({EventPromo? promo}) async {
    await EventEditorSheet.show(context, promo: promo);
  }

  Future<void> _deletePromo(EventPromo promo) async {
    await _db.collection('events_promotions').doc(promo.id).delete();
  }

  @override
  Widget build(BuildContext context) {
    final title = tr(context, en: 'Events & Promotions', es: 'Eventos y promos');
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
            stream:
                FirebaseFirestore.instance.collection('events_promotions').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    tr(context, en: 'No events yet.', es: 'Sin eventos.'),
                  ),
                );
              }
              final items =
                  docs.map((doc) => EventPromo.fromFirestore(doc)).toList();
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final promo = items[index];
                  return Card(
                    child: ListTile(
                      leading: promo.imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                promo.imageUrl,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(Icons.event),
                      title: Text(promo.title),
                      subtitle: Text(promo.type),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: tr(context, en: 'Edit', es: 'Editar'),
                            onPressed: () => _openEditor(promo: promo),
                            icon: const Icon(Icons.edit),
                          ),
                          IconButton(
                            tooltip: tr(context, en: 'Delete', es: 'Eliminar'),
                            onPressed: () => _deletePromo(promo),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add),
            label: Text(tr(context, en: 'Add event', es: 'Agregar evento')),
          ),
        );
      },
    );
  }
}

