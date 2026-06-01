import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firebase/firebase_auth_service.dart';
import '../services/firebase/firebase_firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required FirebaseAuthService authService,
    required FirebaseFirestoreService firestoreService,
    required bool firebaseEnabled,
  }) : _authService = authService,
       _firestoreService = firestoreService,
       _firebaseEnabled = firebaseEnabled;

  final FirebaseAuthService _authService;
  final FirebaseFirestoreService _firestoreService;
  final bool _firebaseEnabled;

  User? _currentUser;
  bool _isLoading = false;
  String? _error;
  DateTime? _birthDate;
  String? _profileDisplayName;
  String? _profilePhotoUrl;

  bool get firebaseEnabled => _firebaseEnabled;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get error => _error;
  String? get uid => _currentUser?.uid;
  String get displayName {
    final profileName = _profileDisplayName?.trim() ?? '';
    if (profileName.isNotEmpty) {
      return profileName;
    }
    final authName = _currentUser?.displayName?.trim() ?? '';
    if (authName.isNotEmpty) {
      return authName;
    }
    return 'Guest';
  }

  String get email => _currentUser?.email ?? '';
  bool get isGoogleAccount {
    final user = _currentUser;
    if (user == null) {
      return false;
    }
    return user.providerData.any(
      (provider) => provider.providerId == 'google.com',
    );
  }

  String get photoUrl {
    final profilePhoto = _profilePhotoUrl?.trim() ?? '';
    if (profilePhoto.isNotEmpty) {
      return profilePhoto;
    }
    return _currentUser?.photoURL ?? '';
  }

  DateTime? get birthDate => _birthDate;
  bool get needsBirthDate => isAuthenticated && _birthDate == null;

  void clearError() {
    if (_error == null) {
      return;
    }
    _error = null;
    notifyListeners();
  }

  String _displayNameFromEmail(String email) {
    final localPart = email.split('@').first.trim();
    if (localPart.isEmpty) {
      return 'CineMemo User';
    }
    final normalized = localPart.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '');
    if (normalized.isEmpty) {
      return 'CineMemo User';
    }
    return normalized;
  }

  String _mapAuthError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Email khong hop le.';
        case 'user-disabled':
          return 'Tai khoan da bi vo hieu hoa.';
        case 'user-not-found':
          return 'Khong tim thay tai khoan voi email nay.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email hoac mat khau khong dung.';
        case 'email-already-in-use':
          return 'Email nay da duoc dang ky.';
        case 'weak-password':
          return 'Mat khau qua yeu. Vui long dung it nhat 6 ky tu.';
        case 'operation-not-allowed':
          return 'Dang nhap bang email/mat khau chua duoc bat tren Firebase.';
        case 'too-many-requests':
          return 'Ban thu qua nhieu lan. Vui long thu lai sau it phut.';
        case 'network-request-failed':
          return 'Khong the ket noi mang. Vui long kiem tra internet.';
      }

      if (error.message != null && error.message!.trim().isNotEmpty) {
        return error.message!.trim();
      }
    }
    return error.toString();
  }

  int? get age {
    final value = _birthDate;
    if (value == null) {
      return null;
    }
    final now = DateTime.now();
    var years = now.year - value.year;
    final hadBirthday =
        now.month > value.month ||
        (now.month == value.month && now.day >= value.day);
    if (!hadBirthday) {
      years -= 1;
    }
    return years;
  }

  bool canWatchAgeLabel(String ageLabel) {
    final minimumAge =
        int.tryParse(ageLabel.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (minimumAge == 0) {
      return true;
    }
    final currentAge = age;
    return currentAge != null && currentAge >= minimumAge;
  }

  Future<void> initialize() async {
    _currentUser = _authService.currentUser;
    if (_currentUser != null) {
      await _loadProfile();
    }

    _authService.authStateChanges().listen((user) async {
      _currentUser = user;
      _error = null;
      if (user == null) {
        _birthDate = null;
        _profileDisplayName = null;
        _profilePhotoUrl = null;
      } else {
        await _loadProfile();
      }
      notifyListeners();
    });

    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    if (!_firebaseEnabled) {
      _error = 'Firebase is not configured. Run FlutterFire setup first.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final credential = await _authService.signInWithGoogle();
      final user = credential?.user;
      if (user == null) {
        _error = 'Google sign-in was cancelled.';
        return false;
      }

      _currentUser = user;
      await _firestoreService.upsertUserProfile(
        uid: user.uid,
        profile: {
          'email': user.email,
          'displayName': user.displayName,
          'photoUrl': user.photoURL,
          'lastLoginAt': FieldValue.serverTimestamp(),
        },
      );
      await _loadProfile();
      return true;
    } catch (error) {
      _error = error.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (!_firebaseEnabled) {
      _error = 'Firebase is not configured. Run FlutterFire setup first.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final credential = await _authService.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        _error = 'Khong the dang nhap bang email/mat khau.';
        return false;
      }

      _currentUser = user;
      await _firestoreService.upsertUserProfile(
        uid: user.uid,
        profile: {
          'email': user.email ?? email.trim(),
          'displayName': user.displayName ?? _displayNameFromEmail(email),
          'lastLoginAt': FieldValue.serverTimestamp(),
        },
      );
      await _loadProfile();
      return true;
    } catch (error) {
      _error = _mapAuthError(error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (!_firebaseEnabled) {
      _error = 'Firebase is not configured. Run FlutterFire setup first.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final normalizedEmail = email.trim();
      final credential = await _authService.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        _error = 'Khong the tao tai khoan moi.';
        return false;
      }

      final displayName = _displayNameFromEmail(normalizedEmail);
      try {
        await _authService.updateDisplayName(displayName);
      } catch (_) {
        // Display name sync is optional. Do not fail registration for this.
      }

      await _firestoreService.upsertUserProfile(
        uid: user.uid,
        profile: {
          'email': normalizedEmail,
          'displayName': displayName,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        },
      );

      // Keep registration and login as two separate steps.
      try {
        await _authService.signOut();
      } catch (_) {
        // Ignore sign-out errors here; login screen still asks user to sign in.
      }
      _currentUser = null;
      _birthDate = null;
      _profileDisplayName = null;
      _profilePhotoUrl = null;
      return true;
    } catch (error) {
      _error = _mapAuthError(error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveBirthDate(DateTime date) async {
    final userId = uid;
    if (userId == null) {
      return;
    }

    await _firestoreService.upsertUserProfile(
      uid: userId,
      profile: {'birthDate': Timestamp.fromDate(date)},
    );
    _birthDate = date;
    notifyListeners();
  }

  Future<bool> updateDisplayName(String newDisplayName) async {
    final userId = uid;
    if (userId == null) {
      _error = 'Vui lòng đăng nhập để cập nhật tên.';
      notifyListeners();
      return false;
    }

    final normalized = newDisplayName.trim();
    if (normalized.isEmpty) {
      _error = 'Tên hiển thị không được để trống.';
      notifyListeners();
      return false;
    }

    if (normalized == displayName) {
      return true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.updateDisplayName(normalized);
      await _firestoreService.upsertUserProfile(
        uid: userId,
        profile: {'displayName': normalized},
      );

      _currentUser = _authService.currentUser ?? _currentUser;
      _profileDisplayName = normalized;
      return true;
    } catch (error) {
      _error = _mapAuthError(error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updatePhotoUrl(String newPhotoUrl) async {
    final userId = uid;
    if (userId == null) {
      _error = 'Vui lòng đăng nhập để cập nhật ảnh đại diện.';
      notifyListeners();
      return false;
    }

    final normalized = newPhotoUrl.trim();
    if (normalized.isEmpty) {
      _error = 'Ảnh đại diện không hợp lệ.';
      notifyListeners();
      return false;
    }

    if (normalized == photoUrl) {
      return true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.updatePhotoUrl(normalized);
      await _firestoreService.upsertUserProfile(
        uid: userId,
        profile: {'photoUrl': normalized},
      );

      _currentUser = _authService.currentUser ?? _currentUser;
      _profilePhotoUrl = normalized;
      return true;
    } catch (error) {
      _error = _mapAuthError(error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    _birthDate = null;
    _profileDisplayName = null;
    _profilePhotoUrl = null;
    notifyListeners();
  }

  Future<void> _loadProfile() async {
    final userId = uid;
    if (userId == null) {
      return;
    }

    final profile = await _firestoreService.getUserProfile(userId);
    final rawDisplayName = profile?['displayName'];
    if (rawDisplayName is String && rawDisplayName.trim().isNotEmpty) {
      _profileDisplayName = rawDisplayName.trim();
    } else {
      _profileDisplayName = _currentUser?.displayName;
    }

    final rawPhotoUrl = profile?['photoUrl'];
    if (rawPhotoUrl is String && rawPhotoUrl.trim().isNotEmpty) {
      _profilePhotoUrl = rawPhotoUrl.trim();
    } else {
      _profilePhotoUrl = _currentUser?.photoURL;
    }

    final rawBirthDate = profile?['birthDate'];
    if (rawBirthDate is Timestamp) {
      _birthDate = rawBirthDate.toDate();
    } else if (rawBirthDate is String) {
      _birthDate = DateTime.tryParse(rawBirthDate);
    } else {
      _birthDate = null;
    }
  }
}
