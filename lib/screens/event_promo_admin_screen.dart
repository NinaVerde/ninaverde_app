import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../models/event_promo_model.dart';

class EventPromoAdminScreen extends StatefulWidget {
  const EventPromoAdminScreen({super.key});

  @override
  State<EventPromoAdminScreen> createState() => _EventPromoAdminScreenState();
}

class _EventPromoAdminScreenState extends State<EventPromoAdminScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

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

  Future<String?> _uploadBytes({
    required Uint8List bytes,
    required String path,
    required String contentType,
  }) async {
    final ref = _storage.ref().child(path);
    await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return ref.getDownloadURL();
  }

  Future<String?> _pickAndUploadImage(String promoId) async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return _uploadBytes(
      bytes: bytes,
      path: 'event_media/$promoId/image.jpg',
      contentType: 'image/jpeg',
    );
  }

  Future<String?> _pickAndUploadVideo(String promoId) async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return _uploadBytes(
      bytes: bytes,
      path: 'event_media/$promoId/video.mp4',
      contentType: 'video/mp4',
    );
  }

  Future<void> _openEditor({EventPromo? promo}) async {
    final docRef = promo == null
        ? _db.collection('events_promotions').doc()
        : _db.collection('events_promotions').doc(promo.id);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _EventPromoEditorSheet(
          docRef: docRef,
          promo: promo,
          pickImage: () => _pickAndUploadImage(docRef.id),
          pickVideo: () => _pickAndUploadVideo(docRef.id),
        );
      },
    );
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
            appBar: NvAppBar(title: title, showBack: true),
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
          appBar: NvAppBar(title: title, showBack: true),
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

class _EventPromoEditorSheet extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> docRef;
  final EventPromo? promo;
  final Future<String?> Function() pickImage;
  final Future<String?> Function() pickVideo;

  const _EventPromoEditorSheet({
    required this.docRef,
    required this.promo,
    required this.pickImage,
    required this.pickVideo,
  });

  @override
  State<_EventPromoEditorSheet> createState() => _EventPromoEditorSheetState();
}

class _EventPromoEditorSheetState extends State<_EventPromoEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  String _type = 'promo';
  String _imageUrl = '';
  String _videoUrl = '';
  bool _active = true;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.promo?.title ?? '');
    _description =
        TextEditingController(text: widget.promo?.description ?? '');
    _type = widget.promo?.type ?? 'promo';
    _imageUrl = widget.promo?.imageUrl ?? '';
    _videoUrl = widget.promo?.videoUrl ?? '';
    _active = widget.promo?.active ?? true;
    _startDate = widget.promo?.startDate;
    _endDate = widget.promo?.endDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = start ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _title.text.trim();
    final description = _description.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    final isNew = widget.promo == null;
    final data = <String, dynamic>{
      'title': title,
      'description': description,
      'type': _type,
      'imageUrl': _imageUrl,
      'videoUrl': _videoUrl,
      'active': _active,
      'startDate': _startDate == null
          ? null
          : Timestamp.fromDate(_startDate!),
      'endDate':
          _endDate == null ? null : Timestamp.fromDate(_endDate!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (isNew) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await widget.docRef.set(data, SetOptions(merge: true));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final titleLabel = widget.promo == null
        ? tr(context, en: 'New event', es: 'Nuevo evento')
        : tr(context, en: 'Edit event', es: 'Editar evento');

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titleLabel, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: InputDecoration(
                labelText: tr(context, en: 'Title', es: 'Titulo'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: tr(context, en: 'Description', es: 'Descripcion'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              items: [
                DropdownMenuItem(
                  value: 'promo',
                  child: Text(tr(context, en: 'Promotion', es: 'Promocion')),
                ),
                DropdownMenuItem(
                  value: 'event',
                  child: Text(tr(context, en: 'Event', es: 'Evento')),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _type = value);
              },
              decoration: InputDecoration(
                labelText: tr(context, en: 'Type', es: 'Tipo'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(start: true),
                    icon: const Icon(Icons.event_available),
                    label: Text(
                      _startDate == null
                          ? tr(context, en: 'Start date', es: 'Inicio')
                          : _formatDate(_startDate),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(start: false),
                    icon: const Icon(Icons.event_busy),
                    label: Text(
                      _endDate == null
                          ? tr(context, en: 'End date', es: 'Fin')
                          : _formatDate(_endDate),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: Text(tr(context, en: 'Active', es: 'Activo')),
            ),
            const SizedBox(height: 12),
            Text(
              tr(context, en: 'Media', es: 'Multimedia'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final url = await widget.pickImage();
                      if (url != null) {
                        setState(() => _imageUrl = url);
                      }
                    },
                    icon: const Icon(Icons.image),
                    label:
                        Text(tr(context, en: 'Upload image', es: 'Subir imagen')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final url = await widget.pickVideo();
                      if (url != null) {
                        setState(() => _videoUrl = url);
                      }
                    },
                    icon: const Icon(Icons.videocam),
                    label:
                        Text(tr(context, en: 'Upload video', es: 'Subir video')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_imageUrl.isNotEmpty)
              Text(tr(context, en: 'Image ready', es: 'Imagen lista')),
            if (_videoUrl.isNotEmpty)
              Text(tr(context, en: 'Video ready', es: 'Video listo')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(
                  _saving
                      ? tr(context, en: 'Saving...', es: 'Guardando...')
                      : tr(context, en: 'Save', es: 'Guardar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
