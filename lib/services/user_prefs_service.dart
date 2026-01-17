import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../providers/cart_provider.dart';
import '../models/product_model.dart';
import 'analytics_service.dart';

class UserPrefsSettings {
  final ThemeMode themeMode;
  final String languageCode;
  final String currencyCode;
  final String lastCategory;
  final List<String> favorites;
  // Profile picture settings
  final List<String> angelinaProfilePics;
  final String? selectedProfilePic;
  final bool profilePicRandomize;
  final int profilePicInterval;

  UserPrefsSettings({
    required this.themeMode,
    required this.languageCode,
    required this.currencyCode,
    required this.lastCategory,
    required this.favorites,
    this.angelinaProfilePics = const [],
    this.selectedProfilePic,
    this.profilePicRandomize = false,
    this.profilePicInterval = 300,
  });
}

class UserPrefsService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static late SharedPreferences _prefs;

  static const String _kTheme = 'theme_mode';
  static const String _kLang = 'lang_code';
  static const String _kCurr = 'curr_code';
  static const String _kCat = 'last_cat';
  static const String _kFavs = 'favorites';
  static const String _kCart = 'cart_items';
  static const String _kIntro = 'intro_seen';
  static const String _kCarouselConfig = 'carousel_config';
  
  // Session-only flag for Guests/Anonymous users
  static bool _sessionIntroSeen = false;

  /// Call this in main() before runApp
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- Hybrid Getters ---

  static bool get introSeen {
    // 1. Session check (for current run, especially guests)
    if (_sessionIntroSeen) return true;
    
    // 2. Persistent check (for registered users)
    // IMPORTANT: If user is Guest, we ignore persistent storage to force re-onboarding on fresh launch
    // (User requirement: "if I reenter as a guest again I should be onboarded again")
    final user = _auth.currentUser;
    if (user != null && user.isAnonymous) {
      return false; 
    }

    return _prefs.getBool(_kIntro) ?? false;
  }

  static Future<void> setIntroSeen() async {
    // A. Always set session flag for immediate navigation within this run
    _sessionIntroSeen = true;

    // B. Only persist if NOT Guest
    final user = _auth.currentUser;
    if (user != null && !user.isAnonymous) {
      await _prefs.setBool(_kIntro, true);
    }
  }

  static UserPrefsSettings loadLocalPrefs() {
    // Theme
    final tStr = _prefs.getString(_kTheme);
    final theme = tStr == 'light'
        ? ThemeMode.light
        : (tStr == 'dark' ? ThemeMode.dark : ThemeMode.system);

    // Lang
    final lang = _prefs.getString(_kLang) ?? 'es'; // Default to Spanish per guidelines? Or device?
    // User requested "start with her explaining... language currency etc" so we might default to device or ES.
    
    // Currency
    final curr = _prefs.getString(_kCurr) ?? 'USD';

    // Category
    final cat = _prefs.getString(_kCat) ?? '__all__';

    // Favorites
    final favs = _prefs.getStringList(_kFavs) ?? [];

    // Profile Pictures
    final profilePics = _prefs.getStringList('angelina_profile_pics') ?? [];
    final selectedPic = _prefs.getString('selected_profile_pic');
    final randomize = _prefs.getBool('profile_pic_randomize') ?? false;
    final interval = _prefs.getInt('profile_pic_interval') ?? 300;

    return UserPrefsSettings(
      themeMode: theme,
      languageCode: lang,
      currencyCode: curr,
      lastCategory: cat,
      favorites: favs,
      angelinaProfilePics: profilePics,
      selectedProfilePic: selectedPic,
      profilePicRandomize: randomize,
      profilePicInterval: interval,
    );
  }

  static Map<String, dynamic> loadCarouselConfig() {
    final str = _prefs.getString(_kCarouselConfig);
    if (str == null) return {};
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static List<CartItem> loadCart(List<Product> allProducts) {
    final jsonStr = _prefs.getString(_kCart);
    if (jsonStr == null) return [];
    
    // Simple CSV parser for "id:qty,id:qty"
    // Ideally use JSON, but CSV is fast for simple strings.
    final items = <CartItem>[];
    final parts = jsonStr.split(',');
    final productMap = {for (var p in allProducts) p.id: p};

    for (final part in parts) {
      final pair = part.split(':');
      if (pair.length == 2) {
        final id = pair[0];
        final qty = int.tryParse(pair[1]) ?? 1;
        final product = productMap[id];
        if (product != null) {
          items.add(CartItem(product: product, quantity: qty));
        }
      }
    }
    return items;
  }

  // --- Hybrid Setters ---

  static Future<void> saveTheme(ThemeMode mode) async {
    final str = mode == ThemeMode.light ? 'light' : (mode == ThemeMode.dark ? 'dark' : 'system');
    await _prefs.setString(_kTheme, str);
    _syncToFirestore({'themeMode': str});
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    await saveTheme(mode);
  }

  static Future<void> saveLanguage(String code) async {
    await _prefs.setString(_kLang, code);
    _syncToFirestore({'languageCode': code});
  }

  static Future<void> saveCurrency(String code) async {
    await _prefs.setString(_kCurr, code);
    _syncToFirestore({'currencyCode': code});
  }

  static Future<void> saveCategory(String category) async {
    await _prefs.setString(_kCat, category);
     // Category state is usually transient, but we can sync it if "history" is desired.
     _syncToFirestore({'lastCategory': category});
  }

  static Future<void> saveCarouselConfig(Map<String, dynamic> config) async {
    final str = jsonEncode(config);
    await _prefs.setString(_kCarouselConfig, str);
    _syncToFirestore({'carouselConfig': config});
  }

  // Profile Picture Persistence
  static Future<void> saveProfilePictures(List<String> urls) async {
    await _prefs.setStringList('angelina_profile_pics', urls);
    _syncToFirestore({'angelinaProfilePics': urls});
  }

  static Future<void> saveSelectedProfilePic(String? url) async {
    if (url != null) {
      await _prefs.setString('selected_profile_pic', url);
    } else {
      await _prefs.remove('selected_profile_pic');
    }
    _syncToFirestore({'selectedProfilePic': url});
  }

  static Future<void> saveProfilePicRandomize(bool enabled) async {
    await _prefs.setBool('profile_pic_randomize', enabled);
    _syncToFirestore({'profilePicRandomize': enabled});
  }

  static Future<void> saveProfilePicInterval(int seconds) async {
    await _prefs.setInt('profile_pic_interval', seconds);
    _syncToFirestore({'profilePicInterval': seconds});
  }

  // --- Favorites Logic (Original + Local) ---

  DocumentReference<Map<String, dynamic>>? _prefsRef() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('prefs').doc('home');
  }

  Stream<Map<String, dynamic>> prefsStream() {
    // Keeping this for the stream-based Home Screen widgets if needed,
    // but ideally we move to AppState source of truth.
    final ref = _prefsRef();
    if (ref == null) return const Stream.empty();
    return ref.snapshots().map((snap) => snap.data() ?? {});
  }

  Future<void> saveCategoryOrder(List<String> order) async {
    // This was specific to HomeScreen ordering, keep sending to Firestore
     final ref = _prefsRef();
    if (ref == null) return;
    await ref.set({
      'categoryOrder': order,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> toggleFavorite({
    required String productId,
    required bool isFavorite,
  }) async {
    // 1. Local Update
    final current = _prefs.getStringList(_kFavs) ?? [];
    if (isFavorite) {
      if (!current.contains(productId)) current.add(productId);
    } else {
      current.remove(productId);
    }
    await _prefs.setStringList(_kFavs, current);

    // 2. Server Update (Auth only)
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final ref = _prefsRef();
    if (ref != null) {
        await ref.set({
        'favorites': current,
        'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    }

    final productRef = _db.collection('products').doc(productId);
    final summaryRef = _db.collection('crm_favorites').doc(productId);
    final eventRef = _db.collection('crm_favorites_events').doc();

    final delta = isFavorite ? 1 : -1;

    await _db.runTransaction((txn) async {
      txn.set(productRef, {
        'favoritesCount': FieldValue.increment(delta),
        'favoritesUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      txn.set(summaryRef, {
        'productId': productId,
        'count': FieldValue.increment(delta),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      txn.set(eventRef, {
        'productId': productId,
        'userId': uid,
        'isFavorite': isFavorite,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    
    if (isFavorite) {
      AnalyticsService.logEvent('add_favorite', {
        'content_type': 'product',
        'item_id': productId,
      });
    }
  }

  // --- Cart Sync ---
  
  static Future<void> saveCart(Map<String, CartItem> items) async {
    // Save as "id:qty,id:qty"
    final str = items.entries.map((e) => '${e.key}:${e.value.quantity}').join(',');
    await _prefs.setString(_kCart, str);
    
    // We don't necessarily sync Cart to Firestore instantly on every tap for performance,
    // but we can. Users requested "if he has things in the cart they should still be there".
    // Firestore sync is robust.
    _syncToFirestore({'cart': items.entries.map((e) => {'id': e.key, 'qty': e.value.quantity}).toList()});
  }

  // --- Internal Sync Helper ---

  static Future<void> _syncToFirestore(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      await _db.collection('users').doc(user.uid).collection('prefs').doc('global').set(
        data..addAll({'updatedAt': FieldValue.serverTimestamp()}),
        SetOptions(merge: true),
      );
    } catch (_) {
      // Ignore offline sync errors
    }
  }
  
  /// Call this after login to merge cloud prefs down to device
  static Future<void> syncFromCloud() async {
     final user = _auth.currentUser;
    if (user == null) return;

    try {
        final doc = await _db.collection('users').doc(user.uid).collection('prefs').doc('global').get();
        if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            // Merge cloud to local
            if (data.containsKey('themeMode')) await _prefs.setString(_kTheme, data['themeMode']);
            if (data.containsKey('languageCode')) await _prefs.setString(_kLang, data['languageCode']);
            if (data.containsKey('currencyCode')) await _prefs.setString(_kCurr, data['currencyCode']);
            if (data.containsKey('lastCategory')) await _prefs.setString(_kCat, data['lastCategory']);
            if (data.containsKey('favorites')) {
                 final favs = (data['favorites'] as List).cast<String>();
                 await _prefs.setStringList(_kFavs, favs);
            }
             // Cart merge is complex (cloud vs local), for now, we assume local wins if active, else cloud.
             // Or we just overwrite local with cloud if local is empty.
        }
    } catch (_) {}
  }
}
