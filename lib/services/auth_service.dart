// lib/services/auth_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool get supportsGoogleSignIn =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  bool get supportsAppleSignIn =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  Future<void> initializeGoogleSignIn() => supportsGoogleSignIn
      ? _googleSignIn.initialize()
      : Future<void>.value();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ---------- Email/Password -------------
  Future<UserCredential> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user?.updateDisplayName(displayName);
    await _saveUserProfile(cred.user!, displayName: displayName);
    return cred;
  }

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // ---------- Google ----------
  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final userCred = await _auth.signInWithPopup(GoogleAuthProvider());
      await _saveUserProfile(
        userCred.user!,
        displayName: userCred.user!.displayName,
      );
      return userCred;
    }
    if (!supportsGoogleSignIn) {
      throw UnsupportedError('Google Sign-In is not available on this device.');
    }

    final googleUser = await _googleSignIn.authenticate(
      scopeHint: const ['email', 'profile'],
    );

    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(credential);
    await _saveUserProfile(
      userCred.user!,
      displayName: userCred.user!.displayName,
    );
    return userCred;
  }

  // ---------- Apple ----------
  Future<UserCredential> signInWithApple() async {
    if (kIsWeb) {
      final userCred = await _auth.signInWithPopup(OAuthProvider('apple.com'));
      await _saveUserProfile(
        userCred.user!,
        displayName: userCred.user!.displayName,
      );
      return userCred;
    }
    if (!supportsAppleSignIn) {
      throw UnsupportedError('Apple Sign-In is not available on this device.');
    }

    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final oauthCredential = OAuthProvider(
      "apple.com",
    ).credential(idToken: appleCredential.identityToken, rawNonce: rawNonce);

    final userCred = await _auth.signInWithCredential(oauthCredential);

    final name = appleCredential.givenName != null
        ? '${appleCredential.givenName} ${appleCredential.familyName ?? ""}'
              .trim()
        : userCred.user!.displayName;

    if (name != null && name.isNotEmpty) {
      await userCred.user?.updateDisplayName(name);
    }
    await _saveUserProfile(userCred.user!, displayName: name);
    return userCred;
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  // ---------- Profile (Firestore) ----------
  Future<void> _saveUserProfile(User user, {String? displayName}) async {
    await _createUserProfile(user, displayName: displayName);
  }

  Future<void> _createUserProfile(User user, {String? displayName}) async {
    final ref = _db.collection('users').doc(user.uid);
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      await ref.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': displayName ?? 'Music Fan',
        'photoUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // The Google SDK is not active for every session or platform.
    }
    await _auth.signOut();
  }
}
