import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthService {
  static const String calendarEventsScope =
      'https://www.googleapis.com/auth/calendar.events';

  FirebaseAuthService({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
    : _firebaseAuth = firebaseAuth,
      _googleSignIn =
          googleSignIn ??
          GoogleSignIn(
            clientId:
                '150666245622-j28ii7s3kt9j8if3smu9b5ioaqdaq4be.apps.googleusercontent.com',
            scopes: const <String>['email', calendarEventsScope],
          );

  FirebaseAuth? _firebaseAuth;
  final GoogleSignIn? _googleSignIn;

  FirebaseAuth? get _auth {
    final current = _firebaseAuth;
    if (current != null) {
      return current;
    }
    if (Firebase.apps.isEmpty) {
      return null;
    }
    _firebaseAuth = FirebaseAuth.instance;
    return _firebaseAuth;
  }

  Stream<User?> authStateChanges() {
    final auth = _auth;
    if (auth == null) {
      return const Stream<User?>.empty();
    }
    return auth.authStateChanges();
  }

  User? get currentUser => _auth?.currentUser;

  bool get isGoogleUserSignedIn {
    final user = currentUser;
    if (user == null) {
      return false;
    }
    return user.providerData.any(
      (provider) => provider.providerId == 'google.com',
    );
  }

  bool get isInitialized => Firebase.apps.isNotEmpty;

  Future<UserCredential?> signInWithGoogle() async {
    if (!isInitialized) {
      throw StateError('Firebase is not initialized.');
    }

    final auth = _auth;
    if (auth == null) {
      throw StateError('FirebaseAuth is unavailable.');
    }

    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      provider.addScope('email');
      provider.addScope(calendarEventsScope);
      return auth.signInWithPopup(provider);
    }

    final googleSignIn = _googleSignIn;
    if (googleSignIn == null) {
      throw StateError('GoogleSignIn is unavailable on this platform.');
    }

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      return null;
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return auth.signInWithCredential(credential);
  }

  Future<String?> getGoogleAccessToken({
    List<String> requiredScopes = const <String>[calendarEventsScope],
  }) async {
    final googleSignIn = _googleSignIn;
    if (googleSignIn == null) {
      return null;
    }

    GoogleSignInAccount? account = googleSignIn.currentUser;
    account ??= await googleSignIn.signInSilently();
    if (account == null) {
      return null;
    }

    if (requiredScopes.isNotEmpty) {
      final granted = await googleSignIn.requestScopes(requiredScopes);
      if (!granted) {
        return null;
      }
    }

    final googleAuth = await account.authentication;
    return googleAuth.accessToken;
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (!isInitialized) {
      throw StateError('Firebase is not initialized.');
    }

    final auth = _auth;
    if (auth == null) {
      throw StateError('FirebaseAuth is unavailable.');
    }

    return auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (!isInitialized) {
      throw StateError('Firebase is not initialized.');
    }

    final auth = _auth;
    if (auth == null) {
      throw StateError('FirebaseAuth is unavailable.');
    }

    return auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> updateDisplayName(String displayName) async {
    final auth = _auth;
    final user = auth?.currentUser;
    if (user == null) {
      return;
    }
    await user.updateDisplayName(displayName);
    await user.reload();
  }

  Future<void> updatePhotoUrl(String photoUrl) async {
    final auth = _auth;
    final user = auth?.currentUser;
    if (user == null) {
      return;
    }
    await user.updatePhotoURL(photoUrl);
    await user.reload();
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn?.signOut();
    }
    await _auth?.signOut();
  }
}
