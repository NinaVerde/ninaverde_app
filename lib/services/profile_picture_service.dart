import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;

class ProfilePictureService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Upload profile picture to Firebase Storage
  /// Returns download URL
  Future<String> uploadProfilePicture(File imageFile) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path.extension(imageFile.path);
    final filename = '$timestamp$extension';
    final ref = _storage.ref('angelina_profile_pics/${user.uid}/$filename');

    final uploadTask = ref.putFile(imageFile);
    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    return downloadUrl;
  }

  /// Delete profile picture from Firebase Storage
  Future<void> deleteProfilePicture(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting profile picture: $e');
      // Continue even if delete fails (might already be deleted)
    }
  }

  /// Fetch all profile pictures for current user
  Future<List<String>> fetchUserProfilePictures() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final ref = _storage.ref('angelina_profile_pics/${user.uid}');
      final result = await ref.listAll();
      
      final urls = <String>[];
      for (final item in result.items) {
        final url = await item.getDownloadURL();
        urls.add(url);
      }
      
      return urls;
    } catch (e) {
      debugPrint('Error fetching profile pictures: $e');
      return [];
    }
  }

  /// Validate image file meets requirements
  static String? validateImage(File imageFile) {
    // Check file size (max 5MB)
    final sizeInBytes = imageFile.lengthSync();
    final sizeInMb = sizeInBytes / (1024 * 1024);
    if (sizeInMb > 5) {
      return 'Image too large. Maximum size is 5MB.';
    }

    // Check extension
    final ext = path.extension(imageFile.path).toLowerCase();
    if (!['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) {
      return 'Invalid file format. Use JPG, PNG, or WebP.';
    }

    return null; // Valid
  }
}
