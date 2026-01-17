import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../state/app_state.dart';
import '../services/profile_picture_service.dart';
import '../theme/brand_colors.dart';

class AngelinaProfileSettingsScreen extends StatefulWidget {
  const AngelinaProfileSettingsScreen({super.key});

  @override
  State<AngelinaProfileSettingsScreen> createState() => _AngelinaProfileSettingsScreenState();
}

class _AngelinaProfileSettingsScreenState extends State<AngelinaProfileSettingsScreen> {
  final ProfilePictureService _service = ProfilePictureService();
  final ImagePicker _picker = ImagePicker();
  bool _uploading = false;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    _loadProfilePictures();
  }

  Future<void> _loadProfilePictures() async {
    final urls = await _service.fetchUserProfilePictures();
    if (mounted) {
      AppState.of(context).angelinaProfilePics.value = urls;
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );

      if (image == null) return;

      final file = File(image.path);
      
      // Validate
      final error = ProfilePictureService.validateImage(file);
      if (error != null) {
        setState(() => _uploadError = error);
        return;
      }

      // Check limit (20 pictures max)
      final app = AppState.of(context);
      if (app.angelinaProfilePics.value.length >= 20) {
        setState(() => _uploadError = 'Maximum 20 pictures allowed');
        return;
      }

      setState(() {
        _uploading = true;
        _uploadError = null;
      });

      // Upload
      final url = await _service.uploadProfilePicture(file);
      
      // Add to list
      final updated = List<String>.from(app.angelinaProfilePics.value)..add(url);
      app.angelinaProfilePics.value = updated;

      // If it's the first picture, auto-select it
      if (updated.length == 1) {
        app.selectedProfilePic.value = url;
      }

      setState(() => _uploading = false);
    } catch (e) {
      setState(() {
        _uploading = false;
        _uploadError = 'Upload failed: $e';
      });
    }
  }

  Future<void> _deleteImage(String url) async {
    final app = AppState.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Picture?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Delete from storage
    await _service.deleteProfilePicture(url);

    // Remove from list
    final updated = List<String>.from(app.angelinaProfilePics.value)..remove(url);
    app.angelinaProfilePics.value = updated;

    // If deleted was selected, pick new selection
    if (app.selectedProfilePic.value == url) {
      app.selectedProfilePic.value = updated.isNotEmpty ? updated.first : null;
    }
  }

  String _formatInterval(int seconds) {
    if (seconds < 60) return '$seconds seconds';
    if (seconds < 3600) return '${(seconds / 60).round()} minutes';
    return '${(seconds / 3600).round()} hours';
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Angelina Profile Pictures'),
        backgroundColor: nvGreenDark,
      ),
      body: ValueListenableBuilder<List<String>>(
        valueListenable: app.angelinaProfilePics,
        builder: (context, pics, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Picture Preview
                _buildCurrentPictureSection(app, scheme),
                const SizedBox(height: 24),

                // Upload Button
                _buildUploadSection(pics, theme),
                const SizedBox(height: 24),

                // Gallery Grid
                if (pics.isNotEmpty) ...[
                  _buildGallerySection(app, pics, scheme),
                  const SizedBox(height: 24),
                ],

                // Randomization Controls
                _buildRandomizationSection(app, pics, theme),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentPictureSection(AppState app, ColorScheme scheme) {
    return ValueListenableBuilder<String?>(
      valueListenable: app.selectedProfilePic,
      builder: (context, selected, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Profile Picture',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: nvAccentOrange, width: 3),
                    ),
                    child: ClipOval(
                      child: selected != null
                          ? CachedNetworkImage(
                              imageUrl: selected,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (_, __, ___) => const Icon(Icons.error),
                            )
                          : Image.asset(
                              'assets/images/angelina/angelina_bubble_avatar.jpg',
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    selected != null ? 'Custom Picture' : 'Default Avatar',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUploadSection(List<String> pics, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upload New Picture',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '${pics.length}/20',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_uploadError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _uploadError!,
                  style: TextStyle(color: Colors.red[700]),
                ),
              ),
            ElevatedButton.icon(
              onPressed: _uploading || pics.length >= 20 ? null : _pickAndUploadImage,
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_a_photo),
              label: Text(_uploading ? 'Uploading...' : 'Select from Gallery'),
              style: ElevatedButton.styleFrom(
                backgroundColor: nvGreenDark,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Max 5MB • JPG, PNG, or WebP • 200x200 to 2000x2000 px',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGallerySection(AppState app, List<String> pics, ColorScheme scheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Pictures (${pics.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: pics.length,
              itemBuilder: (context, index) {
                final url = pics[index];
                return ValueListenableBuilder<String?>(
                  valueListenable: app.selectedProfilePic,
                  builder: (context, selected, _) {
                    final isSelected = selected == url;
                    return GestureDetector(
                      onTap: () => app.selectedProfilePic.value = url,
                      onLongPress: () => _deleteImage(url),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? nvAccentOrange : Colors.grey[300]!,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            children: [
                              CachedNetworkImage(
                                imageUrl: url,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                placeholder: (_, __) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (_, __, ___) => const Icon(Icons.error),
                              ),
                              if (isSelected)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: nvAccentOrange,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to select • Long-press to delete',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRandomizationSection(AppState app, List<String> pics, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Randomization',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<bool>(
              valueListenable: app.profilePicRandomize,
              builder: (context, randomize, _) {
                return SwitchListTile(
                  title: const Text('Randomize Profile Picture'),
                  subtitle: pics.length < 2
                      ? const Text('Upload at least 2 pictures to enable')
                      : Text(randomize ? 'Pictures will cycle automatically' : 'Show selected picture only'),
                  value: randomize,
                  onChanged: pics.length < 2
                      ? null
                      : (value) => app.profilePicRandomize.value = value,
                  activeColor: nvGreenDark,
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: app.profilePicRandomize,
              builder: (context, randomize, _) {
                if (!randomize) return const SizedBox.shrink();
                
                return ValueListenableBuilder<int>(
                  valueListenable: app.profilePicInterval,
                  builder: (context, interval, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'Change Interval: ${_formatInterval(interval)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Slider(
                          value: interval.toDouble(),
                          min: 30, // 30 seconds
                          max: 86400, // 24 hours
                          divisions: 20,
                          label: _formatInterval(interval),
                          onChanged: (value) {
                            app.profilePicInterval.value = value.round();
                          },
                          activeColor: nvGreenDark,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
