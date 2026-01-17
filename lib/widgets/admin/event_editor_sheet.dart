import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/event_promo_model.dart';
import '../../services/translation_service.dart';
import '../../state/app_state.dart'; // Added for tr()
import '../../widgets/nv_widgets.dart';

class EventEditorSheet extends StatefulWidget {
  final EventPromo? promo;

  const EventEditorSheet({super.key, this.promo});

  static Future<void> show(BuildContext context, {EventPromo? promo}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => EventEditorSheet(promo: promo),
    );
  }

  @override
  State<EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends State<EventEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  String _type = 'promo';
  String _imageUrl = '';
  String _videoUrl = '';
  bool _active = true;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;
  
  final _picker = ImagePicker();
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  late DocumentReference<Map<String, dynamic>> _docRef;

  @override
  void initState() {
    super.initState();
    _docRef = widget.promo == null
        ? _db.collection('events_promotions').doc()
        : _db.collection('events_promotions').doc(widget.promo!.id);

    _title = TextEditingController(text: widget.promo?.title ?? '');
    _description = TextEditingController(text: widget.promo?.description ?? '');
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

  Future<String?> _uploadBytes({
    required Uint8List bytes,
    required String path,
    required String contentType,
  }) async {
    final ref = _storage.ref().child(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  Future<String?> _pickAndUpload(bool isVideo) async {
    try {
      final XFile? file = isVideo 
        ? await _picker.pickVideo(source: ImageSource.gallery)
        : await _picker.pickImage(source: ImageSource.gallery);
      
      if (file == null) return null;
      
      final bytes = await file.readAsBytes();
      final ext = isVideo ? 'mp4' : 'jpg';
      final type = isVideo ? 'video/mp4' : 'image/jpeg';
      
      return _uploadBytes(
        bytes: bytes,
        path: 'event_media/${_docRef.id}/${isVideo ? 'video' : 'image'}.$ext',
        contentType: type,
      );
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _title.text.trim();
    final description = _description.text.trim();
    if (title.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required.')),
      );
      return;
    }
    
    setState(() => _saving = true);

    try {
      // AUTO-TRANSLATE TO ENGLISH FOR STORAGE STANDARD
      final enTitle = await TranslationService().translate(title, 'en');
      final enDesc = await TranslationService().translate(description, 'en');

      final isNew = widget.promo == null;
      final data = <String, dynamic>{
        'title': enTitle,
        'description': enDesc,
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
      await _docRef.set(data, SetOptions(merge: true));
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, en: 'Event saved.', es: 'Guardado.')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, en: 'Error saving event.', es: 'Error al guardar.')),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _saving = false);
      }
    }
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
              value: _type,
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
                      final url = await _pickAndUpload(false);
                      if (url != null) setState(() => _imageUrl = url);
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
                      final url = await _pickAndUpload(true);
                      if (url != null) setState(() => _videoUrl = url);
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
