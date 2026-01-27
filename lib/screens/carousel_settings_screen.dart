import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; // For picking assets
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import '../state/app_state.dart';
import '../services/user_prefs_service.dart';
import '../widgets/nv_widgets.dart';

class CarouselSettingsScreen extends StatefulWidget {
  const CarouselSettingsScreen({super.key});

  @override
  State<CarouselSettingsScreen> createState() => _CarouselSettingsScreenState();
}

class _CarouselSettingsScreenState extends State<CarouselSettingsScreen> {
  bool _saving = false;

  // Local state for editing
  late double _speed;
  late bool _autoPlay;
  late CarouselMode _globalMode; // Still unused essentially if effects override? Or keep as fallback?
  // Let's keep globalMode as the default fallback for "Still vs Scroll". 
  // But now we have "Effects". Global Mode is essentially "Default Effect"? 
  // Let's map GlobalMode to "Default Effect" logic.
  // Actually, we can keep global defaults simple.

  late List<String> _localOrder;
  late Map<String, CategoryConfig> _catConfigs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppState.of(context);
    
    _speed = app.carouselSpeed.value;
    _autoPlay = app.carouselAutoPlay.value;
    _globalMode = app.carouselGlobalMode.value;
    
    // Deep copy Configs
    _catConfigs = Map.from(app.categoryConfigs.value);
    
    // Copy Order
    _localOrder = List.from(app.categoryOrder.value);
    // Safety check: ensure all known categories are present?
    // If we have categories in Config but not in Order, append them?
    // Actually `HeroCategoryConfig.order` is the source of truth for "All Categories".
    // We should ensure _localOrder contains everything from that list, 
    // and remove duplicates/unknowns if necessary?
    // For now, assume sync is okay or trusted.
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    
    // 1. Update Global State
    final app = AppState.of(context);
    app.carouselSpeed.value = _speed;
    app.carouselAutoPlay.value = _autoPlay;
    // app.carouselGlobalMode.value = _globalMode; // We can deprecate this if we want, or keep it.
    app.categoryConfigs.value = _catConfigs;
    app.categoryOrder.value = _localOrder;

    // 2. Persist
    final configMap = {
      'speed': _speed,
      'autoPlay': _autoPlay,
      'globalMode': _globalMode.index,
      'order': _localOrder,
      'categories': _catConfigs.map((k, v) => MapEntry(k, v.toJson())),
    };

    try {
      await UserPrefsService.saveCarouselConfig(configMap);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, en: 'Settings saved successfully!', es: '¡Ajustes guardados exitosamente!'))),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr(context, en: 'Error saving: ', es: 'Error al guardar: ')}$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _localOrder.removeAt(oldIndex);
      _localOrder.insert(newIndex, item);
    });
  }

  void _editCategory(String category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CategoryEditorSheet(
        category: category,
        initialConfig: _catConfigs[category] ?? const CategoryConfig(),
        onSave: (newConfig) {
          setState(() => _catConfigs[category] = newConfig);
          // Navigator popped by sheet
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    final theme = Theme.of(context);
    
    return ValueListenableBuilder<String>(
      valueListenable: app.languageCode,
      builder: (context, lang, child) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: NvAppBar(
            tickerVisible: false,
            title: tr(context, en: 'Hero Settings', es: 'Ajustes del Héroe'),
            showBack: true,
            extraActions: [
               Padding(
                 padding: const EdgeInsets.only(right: 8.0),
                 child: FilledButton.icon(
                   style: FilledButton.styleFrom(
                     backgroundColor: Colors.greenAccent,
                     foregroundColor: Colors.black,
                   ),
                   icon: const Icon(Icons.save),
                   label: Text(_saving ? tr(context, en: 'Saving...', es: 'Guardando...') : tr(context, en: 'Save', es: 'Guardar')),
                   onPressed: _saving ? null : _save,
                 ),
               ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
               gradient: LinearGradient(
                 begin: Alignment.topLeft,
                 end: Alignment.bottomRight,
                 colors: theme.brightness == Brightness.dark 
                    ? [const Color(0xFF1a1a1a), const Color(0xFF000000)]
                    : [const Color(0xFFf5f5f5), const Color(0xFFe0e0e0)],
               ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Global Speed / AutoPlay Controls
                  _GlobalControls(
                    speed: _speed,
                    autoPlay: _autoPlay,
                    onSpeedChanged: (v) => setState(() => _speed = v),
                    onAutoPlayChanged: (v) => setState(() => _autoPlay = v),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.sort, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          tr(context, en: 'Reorder & Configure', es: 'Reordenar y Configurar'),
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                           tr(context, en: 'Drag to reorder • Press for settings', es: 'Arrastra para ordenar • Presiona para ajustes'),
                           style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  // Film Strip Container
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        border: Border.symmetric(
                          horizontal: BorderSide(color: Colors.white.withOpacity(0.2), width: 2),
                        ),
                      ),
                      child: ReorderableListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _localOrder.length,
                        onReorder: _onReorder,
                        itemBuilder: (context, index) {
                          final cat = _localOrder[index];
                          final cfg = _catConfigs[cat] ?? const CategoryConfig();
                          return _CategoryFilmFrame(
                            key: ValueKey(cat),
                            category: cat,
                            config: cfg,
                            index: index,
                            onTap: () => _editCategory(cat),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }
}

class _GlobalControls extends StatelessWidget {
  final double speed;
  final bool autoPlay;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<bool> onAutoPlayChanged;

  const _GlobalControls({
    required this.speed,
    required this.autoPlay,
    required this.onSpeedChanged,
    required this.onAutoPlayChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.speed),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(context, en: 'Rotation Speed', es: 'Velocidad de Rotación'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${speed.toInt()} ${tr(context, en: 'seconds', es: 'segundos')}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              Expanded(
                child: Slider(
                  value: speed.clamp(2.0, 120.0),
                  min: 2,
                  max: 120,
                  onChanged: onSpeedChanged,
                  activeColor: Colors.greenAccent,
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr(context, en: 'Auto-Play', es: 'Reproducción Automática'), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(tr(context, en: 'Automatically rotate through categories', es: 'Rotar automáticamente por categorías')),
            value: autoPlay,
<<<<<<< HEAD
            activeThumbColor: Colors.greenAccent,
=======
            activeColor: Colors.greenAccent,
>>>>>>> 2364cb6 (feat: On-the-fly Product Translation, Ticker Improvements, Search B… (#87))
            onChanged: onAutoPlayChanged,
          ),
        ],
      ),
    );
  }
}

class _CategoryFilmFrame extends StatelessWidget {
  final String category;
  final CategoryConfig config;
  final int index;
  final VoidCallback onTap;

  const _CategoryFilmFrame({
    required Key key,
    required this.category,
    required this.config,
    required this.index,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String status;

    switch (config.effect) {
      case CarouselEffect.still:
        icon = Icons.image;
        color = Colors.blueGrey;
        status = 'Still';
        break;
      case CarouselEffect.scrollSequence:
        icon = Icons.view_in_ar;
        color = Colors.purpleAccent;
        status = '3D Scroll';
        break;
      case CarouselEffect.stopMotion:
        icon = Icons.movie_filter;
        color = Colors.orangeAccent;
        status = 'Stop Motion';
        break;
      case CarouselEffect.video:
        icon = Icons.videocam;
        color = Colors.redAccent;
        status = 'Video';
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.4), blurRadius: 12, spreadRadius: 2),
          ],
        ),
        child: Column(
          children: [
            // Sprocket Holes Top
            _buildSprockets(),
            
            // Content Area
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  image: config.assetPath != null 
                    ? DecorationImage(
                        image: NetworkImage(config.assetPath!), 
                        fit: BoxFit.cover,
                        opacity: 0.7
                      ) 
                    : null,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       Container(
                         padding: const EdgeInsets.all(12),
                         decoration: BoxDecoration(
                           shape: BoxShape.circle,
                           color: Colors.black.withOpacity(0.6),
                           border: Border.all(color: color, width: 2),
                         ),
                         child: Icon(icon, color: color, size: 32),
                       ),
                       const SizedBox(height: 12),
                       Padding(
                         padding: const EdgeInsets.symmetric(horizontal: 8.0),
                         child: Text(
                           category,
                           textAlign: TextAlign.center,
                           style: const TextStyle(
                             color: Colors.white, 
                             fontWeight: FontWeight.bold,
                             fontSize: 16,
                             shadows: [Shadow(color: Colors.black, blurRadius: 4)]
                           ),
                           maxLines: 2,
                           overflow: TextOverflow.ellipsis,
                         ),
                       ),
                       const SizedBox(height: 4),
                       Text(status, style: TextStyle(color: color, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ),
            
            // Sprocket Holes Bottom
            _buildSprockets(),
          ],
        ),
      ),
    );
  }

  Widget _buildSprockets() {
    return Container(
      height: 24,
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(6, (i) => Container(
          width: 8, height: 12,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        )),
      ),
    );
  }
}

class _CategoryEditorSheet extends StatefulWidget {
  final String category;
  final CategoryConfig initialConfig;
  final ValueChanged<CategoryConfig> onSave;

  const _CategoryEditorSheet({
    required this.category,
    required this.initialConfig,
    required this.onSave,
  });

  @override
  State<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<_CategoryEditorSheet> {
  late CarouselEffect _effect;
  late TextEditingController _assetPathCtrl; // For Still Image URL
  late TextEditingController _videoUrlCtrl; // For Video URL
  late TextEditingController _folderOverrideCtrl; // For Sequence Folder Override
  
  bool _uploading = false;
  final _picker = ImagePicker(); // Requires file_picker or image_picker? 
  // Code mentions picking from local machine. `image_picker` is good for images/videos.

  @override
  void initState() {
    super.initState();
    _effect = widget.initialConfig.effect;
    _assetPathCtrl = TextEditingController(text: widget.initialConfig.assetPath);
    _videoUrlCtrl = TextEditingController(text: widget.initialConfig.videoUrl);
    _folderOverrideCtrl = TextEditingController(text: widget.initialConfig.folderOverride);
  }

  @override
  void dispose() {
    _assetPathCtrl.dispose();
    _videoUrlCtrl.dispose();
    _folderOverrideCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload(bool video) async {
    setState(() => _uploading = true);
    try {
      // Use file_picker for broader support or image_picker? 
      // ImagePicker supports video too.
      // Need `import 'package:image_picker/image_picker.dart';`
      // I commented out `file_picker` in imports initially but I should add `image_picker` import if not present.
      // It WAS imported in angelina_admin_screen.
      
      FilePickerResult? result; 
      // Actually let's use FilePicker for desktop support if needed, but ImagePicker is easier for standard "gallery".
      // Let's use FilePicker for "Uploading from local machine" which implies Desktop usually.
      // But let's check imports. `import 'package:file_picker/file_picker.dart';` was added at top.

      result = await FilePicker.platform.pickFiles(
        type: video ? FileType.video : FileType.image,
      );

      if (result != null) {
        final platformFile = result.files.first;
        final ext = platformFile.extension ?? (video ? 'mp4' : 'png');
        final bytes = platformFile.bytes;
        final path = platformFile.path;

        if (bytes == null && path == null) return; // Should not happen

        final filename = 'carousel/${DateTime.now().millisecondsSinceEpoch}.$ext';
        final ref = FirebaseStorage.instance.ref().child(filename);
        
        UploadTask task;
        if (kIsWeb || (bytes != null)) { // use bytes if available (often web/desktop memory)
           task = ref.putData(bytes!);
        } else {
           task = ref.putFile(File(path!)); 
        }

        await task;
        final url = await ref.getDownloadURL();
        
        setState(() {
          if (video) {
            _videoUrlCtrl.text = url;
          } else {
            _assetPathCtrl.text = url;
          }
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr(context, en: 'Upload failed: ', es: 'Error de carga: ')}$e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _submit() {
    final newConfig = CategoryConfig(
      effect: _effect,
      assetPath: _assetPathCtrl.text.trim().isEmpty ? null : _assetPathCtrl.text.trim(),
      videoUrl: _videoUrlCtrl.text.trim().isEmpty ? null : _videoUrlCtrl.text.trim(),
      folderOverride: _folderOverrideCtrl.text.trim().isEmpty ? null : _folderOverrideCtrl.text.trim(),
    );
    widget.onSave(newConfig);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${tr(context, en: 'Edit: ', es: 'Editar: ')}${widget.category}', style: Theme.of(context).textTheme.headlineSmall),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),
          // Effect Selector
          Text(tr(context, en: 'Visual Effect', es: 'Efecto Visual'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _EffectChip(
                  label: tr(context, en: 'Still Image', es: 'Imagen Fija'),
                  icon: Icons.image,
                  selected: _effect == CarouselEffect.still,
                  onTap: () => setState(() => _effect = CarouselEffect.still),
                ),
                _EffectChip(
                  label: tr(context, en: 'Scroll 3D', es: 'Despl. 3D'),
                  icon: Icons.view_in_ar,
                  selected: _effect == CarouselEffect.scrollSequence,
                  onTap: () => setState(() => _effect = CarouselEffect.scrollSequence),
                ),
                _EffectChip(
                  label: tr(context, en: 'Stop Motion', es: 'Stop Motion'),
                  icon: Icons.movie_filter,
                  selected: _effect == CarouselEffect.stopMotion,
                  onTap: () => setState(() => _effect = CarouselEffect.stopMotion),
                ),
                _EffectChip(
                  label: tr(context, en: 'Video', es: 'Video'),
                  icon: Icons.videocam,
                  selected: _effect == CarouselEffect.video,
                  onTap: () => setState(() => _effect = CarouselEffect.video),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildMediaPreview(),
          const SizedBox(height: 24),

          // Config Fields based on Effect
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_effect == CarouselEffect.still) ...[
                    Text(tr(context, en: 'Image Source', es: 'Fuente de Imagen'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _assetPathCtrl,
                      decoration: InputDecoration(
                        labelText: tr(context, en: 'Image URL or Asset Path', es: 'URL de imagen o ruta de activo'),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                           icon: const Icon(Icons.upload_file),
                           onPressed: _uploading ? null : () => _pickAndUpload(false),
                        ),
                      ),
                    ),
                    if (_assetPathCtrl.text.isNotEmpty && _assetPathCtrl.text.startsWith('http'))
                       const SizedBox.shrink() // Preview moved up
                  ] else if (_effect == CarouselEffect.video) ...[
                     Text(tr(context, en: 'Video Source', es: 'Fuente de Video'), style: const TextStyle(fontWeight: FontWeight.bold)),
                     const SizedBox(height: 8),
                     TextField(
                      controller: _videoUrlCtrl,
                      decoration: InputDecoration(
                        labelText: tr(context, en: 'Video URL', es: 'URL del Video'),
                        border: const OutlineInputBorder(),
                         suffixIcon: IconButton(
                           icon: const Icon(Icons.upload_file),
                           onPressed: _uploading ? null : () => _pickAndUpload(true),
                        ),
                      ),
                    ),
                  ] else ...[
                     // Sequence Options
                     Text(tr(context, en: 'Sequence Folder', es: 'Carpeta de Secuencia'), style: const TextStyle(fontWeight: FontWeight.bold)),
                     const SizedBox(height: 4),
                     Text(
                       tr(context, en: 'Folder name in assets/images/sequences/ (e.g. "microgreens").', es: 'Nombre de carpeta en assets/images/sequences/'),
                       style: const TextStyle(fontSize: 12, color: Colors.grey),
                     ),
                     const SizedBox(height: 8),
                     TextField(
                      controller: _folderOverrideCtrl,
                      decoration: InputDecoration(
                        labelText: tr(context, en: 'Folder Name (Optional)', es: 'Nombre de Carpeta (Opcional)'),
                        hintText: tr(context, en: 'Leave empty to use default map', es: 'Dejar vacío para usar predeterminado'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                      ],
                    ],
                  ),
                ),
              ),
              
              if (_uploading) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(tr(context, en: 'Apply Changes', es: 'Aplicar Cambios'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
      );
    }

  Widget _buildMediaPreview() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(context, en: 'Media Preview', es: 'Vista Previa de Medios'), style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _buildPreviewContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewContent() {
    switch (_effect) {
      case CarouselEffect.still:
        if (_assetPathCtrl.text.isEmpty) return _buildEmptyPreview(Icons.image);
        return Image.network(
          _assetPathCtrl.text,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildEmptyPreview(Icons.broken_image),
        );
      case CarouselEffect.video:
        if (_videoUrlCtrl.text.isEmpty) return _buildEmptyPreview(Icons.videocam);
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(color: Colors.black),
            const Icon(Icons.play_circle_fill, color: Colors.white, size: 64),
            Positioned(
              bottom: 10,
              child: Text(
                _videoUrlCtrl.text.split('/').last,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ),
          ],
        );
      case CarouselEffect.scrollSequence:
      case CarouselEffect.stopMotion:
        final folder = _folderOverrideCtrl.text.trim();
        // Modern stacked look for sequences
        return Center(
          child: SizedBox(
            width: 200,
            height: 120,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Bottom frame
                Positioned(
                  left: 20,
                  top: 10,
                  child: Transform.rotate(
                    angle: -0.1,
                    child: _buildSequenceFrame(folder, 3, 0.4),
                  ),
                ),
                // Middle frame
                Positioned(
                  left: 10,
                  top: 5,
                  child: Transform.rotate(
                    angle: 0.05,
                    child: _buildSequenceFrame(folder, 2, 0.7),
                  ),
                ),
                // Top frame
                Positioned(
                  left: 0,
                  top: 0,
                  child: _buildSequenceFrame(folder, 1, 1.0),
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildSequenceFrame(String folder, int offset, double opacity) {
    return Container(
      width: 140,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Opacity(
        opacity: opacity,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.layers, color: Colors.white54, size: 24),
              const SizedBox(height: 4),
              Text(
                'Frame #$offset',
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPreview(IconData icon) {
    return Center(
      child: Icon(icon, color: Colors.grey.withOpacity(0.3), size: 64),
    );
  }
}

class _EffectChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _EffectChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: FilterChip(
        label: Row(
          children: [
             Icon(icon, size: 16, color: selected ? Colors.black : Colors.grey),
             const SizedBox(width: 6),
             Text(label),
          ],
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: Colors.greenAccent,
        backgroundColor: Colors.grey.withValues(alpha: 0.1),
        labelStyle: TextStyle(
          color: selected ? Colors.black : Colors.grey,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
        checkmarkColor: Colors.black,
      ),
    );
  }
}
