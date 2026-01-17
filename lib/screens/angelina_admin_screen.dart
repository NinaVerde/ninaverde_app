import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
class AngelinaAdminScreen extends StatefulWidget {
  const AngelinaAdminScreen({super.key});

  @override
  State<AngelinaAdminScreen> createState() => _AngelinaAdminScreenState();
}

class _AngelinaAdminScreenState extends State<AngelinaAdminScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;

  bool _onlineEnabled = false;

  final _personaName = TextEditingController();
  final _personaBioEn = TextEditingController();
  final _personaBioEs = TextEditingController();
  final _greetingEn = TextEditingController();
  final _greetingEs = TextEditingController();
  final _voiceEn = TextEditingController();
  final _voiceEs = TextEditingController();
  final _endpointUrl = TextEditingController();
  final _modelUrl = TextEditingController();

  final List<_KnowledgeEntry> _knowledge = [];
  final List<_MediaEntry> _media = [];

  DocumentReference<Map<String, dynamic>> get _configRef =>
      _db.collection('ai_hostess').doc('angelina');

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _personaName.dispose();
    _personaBioEn.dispose();
    _personaBioEs.dispose();
    _greetingEn.dispose();
    _greetingEs.dispose();
    _voiceEn.dispose();
    _voiceEs.dispose();
    _endpointUrl.dispose();
    _modelUrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final doc = await _configRef.get();
      if (!doc.exists) {
        _applyDefaults(_defaultConfig());
      } else {
        _applyFromDoc(doc.data()!);
      }
    } catch (_) {
      _applyDefaults(_defaultConfig());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyDefaults(_AiConfig config) {
    _onlineEnabled = config.onlineEnabled;
    _personaName.text = config.personaName;
    _personaBioEn.text = config.personaBioEn;
    _personaBioEs.text = config.personaBioEs;
    _greetingEn.text = config.greetingEn;
    _greetingEs.text = config.greetingEs;
    _voiceEn.text = config.voiceEn;
    _voiceEs.text = config.voiceEs;
    _endpointUrl.text = config.endpointUrl;
    _modelUrl.text = config.modelUrl;

    _knowledge
      ..clear()
      ..addAll(config.knowledge);
    _media
      ..clear()
      ..addAll(config.media);
  }

  void _applyFromDoc(Map<String, dynamic> data) {
    _onlineEnabled = data['onlineEnabled'] == true;
    _personaName.text = (data['personaName'] as String?) ?? 'Angelina';
    _personaBioEn.text = (data['personaBioEn'] as String?) ?? '';
    _personaBioEs.text = (data['personaBioEs'] as String?) ?? '';
    _greetingEn.text = (data['greetingEn'] as String?) ?? '';
    _greetingEs.text = (data['greetingEs'] as String?) ?? '';
    _voiceEn.text = (data['voiceEn'] as String?) ?? '';
    _voiceEs.text = (data['voiceEs'] as String?) ?? '';
    _endpointUrl.text = (data['endpointUrl'] as String?) ?? '';
    _modelUrl.text = (data['modelUrl'] as String?) ?? '';

    _knowledge
      ..clear()
      ..addAll(
        (data['knowledge'] as List? ?? [])
            .whereType<Map>()
            .map((raw) => _KnowledgeEntry.fromMap(raw.cast<String, dynamic>())),
      );
    _media
      ..clear()
      ..addAll(
        (data['media'] as List? ?? [])
            .whereType<Map>()
            .map((raw) => _MediaEntry.fromMap(raw.cast<String, dynamic>())),
      );
  }

  Future<void> _saveConfig() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _configRef.set({
        'onlineEnabled': _onlineEnabled,
        'personaName': _personaName.text.trim(),
        'personaBioEn': _personaBioEn.text.trim(),
        'personaBioEs': _personaBioEs.text.trim(),
        'greetingEn': _greetingEn.text.trim(),
        'greetingEs': _greetingEs.text.trim(),
        'voiceEn': _voiceEn.text.trim(),
        'voiceEs': _voiceEs.text.trim(),
        'endpointUrl': _endpointUrl.text.trim(),
        'modelUrl': _modelUrl.text.trim(),
        'knowledge': _knowledge.map((k) => k.toMap()).toList(),
        'media': _media.map((m) => m.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              en: 'Angelina settings saved.',
              es: 'Configuracion de Angelina guardada.',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              en: 'Save failed: $e',
              es: 'Error al guardar: $e',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _seedDefaults() async {
    final defaults = _defaultConfig();
    setState(() {
      _applyDefaults(defaults);
    });
    await _saveConfig();
  }

  Future<void> _uploadMedia({required bool video}) async {
    final source = ImageSource.gallery;
    final XFile? picked = video
        ? await _picker.pickVideo(source: source)
        : await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    final ext = picked.path.split('.').last;
    final filename =
        'ai_hostess/angelina/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _storage.ref().child(filename);

    UploadTask task;
    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      task = ref.putData(bytes);
    } else {
      task = ref.putFile(File(picked.path));
    }

    await task;
    final url = await ref.getDownloadURL();
    if (!mounted) return;
    final title = tr(
      context,
      en: video ? 'Angelina Video' : 'Angelina Image',
      es: video ? 'Video de Angelina' : 'Imagen de Angelina',
    );
    setState(() {
      _media.add(_MediaEntry(
        title: title,
        url: url,
        type: video ? 'video' : 'image',
      ));
    });
  }

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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userDocStream(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final admin = _isAdmin(data);
        return ValueListenableBuilder<String>(
          valueListenable: AppState.of(context).languageCode,
          builder: (_, code, __) {
            final isEs = code == 'es';
            final title =
                isEs ? 'Panel de Angelina' : 'Angelina Control Panel';
            final denied = isEs
                ? 'Acceso denegado. Configura role="admin" o isAdmin=true en tu usuario de Firestore para habilitar este panel.'
                : 'Access denied. Set role="admin" or isAdmin=true on your user document in Firestore to unlock this panel.';
            final seedLabel = isEs ? 'Restaurar default' : 'Seed defaults';
            final saveLabel = isEs ? 'Guardar' : 'Save';
            final statusTitle = isEs ? 'Estado' : 'Status';
            final onlineLabel =
                isEs ? 'AI en linea activado' : 'Online AI enabled';
            final offlineLabel =
                isEs ? 'Por defecto esta offline.' : 'Default is offline.';
            final endpointLabel =
                isEs ? 'URL del endpoint AI' : 'AI endpoint URL';
            final endpointHelp = isEs
                ? 'URL de Firebase Functions para llamadas online.'
                : 'Firebase Functions URL for online AI calls.';
            final personaTitle = isEs ? 'Persona' : 'Persona';
            final nameLabel = isEs ? 'Nombre' : 'Name';
            final personaEnLabel =
                isEs ? 'Persona (Ingles)' : 'Persona (English)';
            final personaEsLabel =
                isEs ? 'Persona (Espanol)' : 'Persona (Spanish)';
            final greetEnLabel =
                isEs ? 'Saludo (Ingles)' : 'Greeting (English)';
            final greetEsLabel =
                isEs ? 'Saludo (Espanol)' : 'Greeting (Spanish)';
            final voiceEnLabel =
                isEs ? 'Voz (Ingles)' : 'Voice hint (English)';
            final voiceEsLabel =
                isEs ? 'Voz (Espanol)' : 'Voice hint (Spanish)';
            final voiceHelp = isEs
                ? 'Ejemplo: en-US, warm, confident'
                : 'Example: en-US, warm, confident';
            final voiceHelpEs = isEs
                ? 'Ejemplo: es-NI, warm, confident'
                : 'Example: es-NI, warm, confident';
            final modelLabel = isEs
                ? 'URL del modelo 3D/4D (opcional)'
                : '3D/4D model URL (optional)';
            final modelHelp = isEs
                ? 'Pega un URL GLB/GLTF/Rive/Lottie para Angelina.'
                : 'Paste a GLB/GLTF/Rive/Lottie URL for Angelina.';
            final knowledgeTitle =
                isEs ? 'Base de conocimiento' : 'Knowledge Base';
            final addKnowledge =
                isEs ? 'Agregar conocimiento' : 'Add knowledge entry';
            final mediaTitle =
                isEs ? 'Biblioteca de medios' : 'Media Library';
            final uploadImage = isEs ? 'Subir imagen' : 'Upload image';
            final uploadVideo = isEs ? 'Subir video' : 'Upload video';
            final savingLabel = isEs ? 'Guardando...' : 'Saving...';
            final saveChanges = isEs ? 'Guardar cambios' : 'Save changes';

            if (!admin) {
              return Scaffold(
                appBar: NvAppBar(title: title, showBack: true),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      denied,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            return Scaffold(
              appBar: NvAppBar(
                title: title,
                showBack: true,
                extraActions: [
                  IconButton(
                    tooltip: seedLabel,
                    onPressed: _seedDefaults,
                    icon: const Icon(Icons.auto_fix_high),
                  ),
                  IconButton(
                    tooltip: saveLabel,
                    onPressed: _saveConfig,
                    icon: const Icon(Icons.save),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionTitle(statusTitle),
                  SwitchListTile(
                    title: Text(onlineLabel),
                    subtitle: Text(offlineLabel),
                    value: _onlineEnabled,
                    onChanged: (v) => setState(() => _onlineEnabled = v),
                  ),
                  TextField(
                    controller: _endpointUrl,
                    decoration: InputDecoration(
                      labelText: endpointLabel,
                      helperText: endpointHelp,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle(personaTitle),
                  TextField(
                    controller: _personaName,
                    decoration: InputDecoration(labelText: nameLabel),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _personaBioEn,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: personaEnLabel,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _personaBioEs,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: personaEsLabel,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _greetingEn,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: greetEnLabel,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _greetingEs,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: greetEsLabel,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _voiceEn,
                    decoration: InputDecoration(
                      labelText: voiceEnLabel,
                      helperText: voiceHelp,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _voiceEs,
                    decoration: InputDecoration(
                      labelText: voiceEsLabel,
                      helperText: voiceHelpEs,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _modelUrl,
                    decoration: InputDecoration(
                      labelText: modelLabel,
                      helperText: modelHelp,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle(knowledgeTitle),
                  ..._knowledge.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return _knowledgeCard(index, item);
                  }),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _knowledge.add(_KnowledgeEntry.empty());
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: Text(addKnowledge),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle(mediaTitle),
                  ..._media.map(_mediaTile),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _uploadMedia(video: false),
                          icon: const Icon(Icons.image_outlined),
                          label: Text(uploadImage),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _uploadMedia(video: true),
                          icon: const Icon(Icons.videocam_outlined),
                          label: Text(uploadVideo),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _saveConfig,
                    child: Text(_saving ? savingLabel : saveChanges),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _knowledgeCard(int index, _KnowledgeEntry item) {
    final isEs = AppState.of(context).languageCode.value == 'es';
    final titleLabel = isEs ? 'Titulo' : 'Title';
    final keywordLabel = isEs
        ? 'Palabras clave (separadas por coma)'
        : 'Keywords (comma separated)';
    final contentEnLabel =
        isEs ? 'Contenido (Ingles)' : 'Content (English)';
    final contentEsLabel =
        isEs ? 'Contenido (Espanol)' : 'Content (Spanish)';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: item.title,
                    decoration: InputDecoration(labelText: titleLabel),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() => _knowledge.removeAt(index));
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            TextField(
              controller: item.keywords,
              decoration: InputDecoration(labelText: keywordLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: item.contentEn,
              maxLines: 3,
              decoration: InputDecoration(labelText: contentEnLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: item.contentEs,
              maxLines: 3,
              decoration: InputDecoration(labelText: contentEsLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaTile(_MediaEntry entry) {
    final isImage = entry.type == 'image';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: isImage
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                entry.url,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            )
          : const Icon(Icons.videocam_outlined),
      title: Text(entry.title),
      subtitle: Text(entry.type),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => setState(() => _media.remove(entry)),
      ),
    );
  }

  _AiConfig _defaultConfig() {
    return _AiConfig(
      onlineEnabled: false,
      endpointUrl: '',
      modelUrl: '',
      personaName: 'Angelina',
      personaBioEn:
          'Glam, confident Latina host. Warm, playful, lightly flirty, and '
          'always classy. Bilingual and deeply knowledgeable about Niña Verde, '
          'Granada, and Nicaragua.',
      personaBioEs:
          'Anfitriona latina, glamorosa y segura. Calida, divertida, con un '
          'toque coqueto y siempre con clase. Bilingue y conocedora de Niña '
          'Verde, Granada y Nicaragua.',
      greetingEn:
          'Welcome to Niña Verde. I am Angelina, your concierge. What are you in the mood for?',
      greetingEs:
          'Bienvenido a Niña Verde. Soy Angelina, tu anfitriona. Que se te antoja hoy?',
      voiceEn: 'en-US, warm, playful, confident',
      voiceEs: 'es-NI, warm, playful, confident',
      knowledge: [
        _KnowledgeEntry.seed(
          title: 'About Niña Verde',
          keywords: 'niña verde, restaurant, vibe, host',
          contentEn:
              'Niña Verde is a vibrant spot in Granada known for warm service, '
              'bold flavors, and a welcoming community vibe.',
          contentEs:
              'Niña Verde es un lugar vibrante en Granada con servicio cálido, '
              'sabores intensos y ambiente comunitario.',
        ),
        _KnowledgeEntry.seed(
          title: 'Granada highlights',
          keywords: 'granada, city, lake, islets, mercado',
          contentEn:
              'Granada is famous for its colonial architecture, the islets of '
              'Lake Nicaragua, and colorful markets.',
          contentEs:
              'Granada es famosa por su arquitectura colonial, los isletas del '
              'Lago de Nicaragua y sus mercados coloridos.',
        ),
        _KnowledgeEntry.seed(
          title: 'Nicaragua essentials',
          keywords: 'nicaragua, travel, culture, safety',
          contentEn:
              'Nicaragua offers volcano hikes, lakes, and rich culture. Always '
              'carry sun protection and stay hydrated.',
          contentEs:
              'Nicaragua ofrece volcanes, lagos y cultura rica. Lleva protección '
              'solar y mantente hidratado.',
        ),
        _KnowledgeEntry.seed(
          title: 'Events and reservations',
          keywords: 'event, reservation, party, booking',
          contentEn:
              'We can host events and reservations. Share your date, time, and '
              'guest count for a tailored plan.',
          contentEs:
              'Podemos organizar eventos y reservas. Comparte fecha, hora y '
              'numero de invitados.',
        ),
      ],
      media: [],
    );
  }
}

class _KnowledgeEntry {
  _KnowledgeEntry({
    required this.title,
    required this.keywords,
    required this.contentEn,
    required this.contentEs,
  });

  final TextEditingController title;
  final TextEditingController keywords;
  final TextEditingController contentEn;
  final TextEditingController contentEs;

  factory _KnowledgeEntry.empty() {
    return _KnowledgeEntry(
      title: TextEditingController(),
      keywords: TextEditingController(),
      contentEn: TextEditingController(),
      contentEs: TextEditingController(),
    );
  }

  factory _KnowledgeEntry.seed({
    required String title,
    required String keywords,
    required String contentEn,
    required String contentEs,
  }) {
    return _KnowledgeEntry(
      title: TextEditingController(text: title),
      keywords: TextEditingController(text: keywords),
      contentEn: TextEditingController(text: contentEn),
      contentEs: TextEditingController(text: contentEs),
    );
  }

  factory _KnowledgeEntry.fromMap(Map<String, dynamic> data) {
    return _KnowledgeEntry(
      title: TextEditingController(text: data['title'] as String? ?? ''),
      keywords: TextEditingController(text: data['keywords'] as String? ?? ''),
      contentEn:
          TextEditingController(text: data['contentEn'] as String? ?? ''),
      contentEs:
          TextEditingController(text: data['contentEs'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title.text.trim(),
        'keywords': keywords.text.trim(),
        'contentEn': contentEn.text.trim(),
        'contentEs': contentEs.text.trim(),
      };
}

class _MediaEntry {
  _MediaEntry({
    required this.title,
    required this.url,
    required this.type,
  });

  final String title;
  final String url;
  final String type;

  factory _MediaEntry.fromMap(Map<String, dynamic> data) {
    return _MediaEntry(
      title: data['title'] as String? ?? 'Angelina Media',
      url: data['url'] as String? ?? '',
      type: data['type'] as String? ?? 'image',
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'url': url,
        'type': type,
      };
}

class _AiConfig {
  _AiConfig({
    required this.onlineEnabled,
    required this.endpointUrl,
    required this.modelUrl,
    required this.personaName,
    required this.personaBioEn,
    required this.personaBioEs,
    required this.greetingEn,
    required this.greetingEs,
    required this.voiceEn,
    required this.voiceEs,
    required this.knowledge,
    required this.media,
  });

  final bool onlineEnabled;
  final String endpointUrl;
  final String modelUrl;
  final String personaName;
  final String personaBioEn;
  final String personaBioEs;
  final String greetingEn;
  final String greetingEs;
  final String voiceEn;
  final String voiceEs;
  final List<_KnowledgeEntry> knowledge;
  final List<_MediaEntry> media;
}

