// lib/services/auth_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'user_service.dart';

/// Centralized service for all authentication flows.
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static const MethodChannel _facebookChannel = MethodChannel('native_facebook_auth');

  static const String _googleServerClientId =
      '615971922286-875kbmm3rkhkr1lp75ctql5qadjlqo84.apps.googleusercontent.com';

  /// --- Email / Password ---
  static Future<UserCredential> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await UserService.upsertCurrentUser();
    return cred;
  }

  static Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// --- Google ---
  static Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final cred = await _auth.signInWithPopup(GoogleAuthProvider());
      await UserService.upsertCurrentUser();
      return cred;
    }

    final AuthCredential? googleCred = await _getGoogleCredential();
    if (googleCred == null) throw Exception('Google sign-in aborted');

    final cred = await _auth.signInWithCredential(googleCred);
    await UserService.upsertCurrentUser();
    return cred;
  }

  static Future<AuthCredential?> _getGoogleCredential() async {
    await _googleSignIn.initialize(serverClientId: _googleServerClientId);
    final account = await _googleSignIn.authenticate();
    final auth = account.authentication;
    if (auth.idToken == null) return null;
    return GoogleAuthProvider.credential(idToken: auth.idToken);
  }

  /// --- Facebook ---
  static Future<UserCredential> signInWithFacebook() async {
    if (kIsWeb) {
      final cred = await _auth.signInWithPopup(FacebookAuthProvider());
      await UserService.upsertCurrentUser();
      return cred;
    }

    final token = await _facebookChannel.invokeMethod<String>('logIn');
    if (token == null || token.isEmpty) throw Exception('Facebook sign-in aborted');

    final fbCred = FacebookAuthProvider.credential(token);
    final cred = await _auth.signInWithCredential(fbCred);
    await UserService.upsertCurrentUser();
    return cred;
  }

  /// --- Apple ---
  static Future<UserCredential> signInWithApple() async {
    // 1. Web: Popup
    if (kIsWeb) {
      final cred = await _auth.signInWithPopup(OAuthProvider('apple.com'));
      await UserService.upsertCurrentUser();
      return cred;
    }

    // 2. Android: Generic OAuthProvider (Firebase handles the flow via browser/tab)
    // NOTE: This requires "Sign in with Apple" enabled in Firebase with Service ID + Private Key
    if (defaultTargetPlatform == TargetPlatform.android) {
      final provider = OAuthProvider('apple.com');
      provider
        ..addScope('email')
        ..addScope('name');
      
      final cred = await _auth.signInWithProvider(provider);
      await UserService.upsertCurrentUser();
      return cred;
    }

    // 3. iOS/macOS: Native Sign In with Apple (SHA-256 nonce flow)
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    try {
      final appleIdCred = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final appleCred = OAuthProvider('apple.com').credential(
        idToken: appleIdCred.identityToken,
        rawNonce: rawNonce,
      );

      final cred = await _auth.signInWithCredential(appleCred);
      await UserService.upsertCurrentUser();
      return cred;
    } catch (e) {
      if (e is SignInWithAppleAuthorizationException && 
          e.code == AuthorizationErrorCode.canceled) {
        throw Exception('Apple sign-in canceled');
      }
      rethrow;
    }
  }

  /// --- Microsoft ---
  static Future<UserCredential> signInWithMicrosoft() async {
    final provider = OAuthProvider('microsoft.com');
    // provider.setCustomParameters({'prompt': 'login'}); // Reverted to allow biometric auto-login
    provider
      ..addScope('openid')
      ..addScope('profile')
      ..addScope('email');

    if (kIsWeb) {
      final cred = await _auth.signInWithPopup(provider);
      await UserService.upsertCurrentUser();
      return cred;
    }

    // For Android/iOS, generic provider flow is cleanest if secrets are in Firebase
    final cred = await _auth.signInWithProvider(provider);
    await UserService.upsertCurrentUser();
    return cred;
  }

  /// --- Guest ---
  static Future<UserCredential> signInAnonymously() async {
    final cred = await _auth.signInAnonymously();
    await UserService.upsertCurrentUser();
    return cred;
  }

  /// --- Sign Out ---
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// --- Helpers ---
  static String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final rand = Random.secure();
    return List.generate(length, (_) => charset[rand.nextInt(charset.length)]).join();
  }

  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
