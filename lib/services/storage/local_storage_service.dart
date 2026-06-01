import 'package:hive/hive.dart';

class LocalStorageService {
  static const String _favoriteBoxName = 'favorite_movies';
  static const String _reviewDraftBoxName = 'review_drafts';
  static const String _movieSearchHistoryBoxName = 'movie_search_history';
  static const String _defaultFavoriteScope = 'guest';

  String _normalizeFavoriteScope(String? scopeKey) {
    final normalized = (scopeKey ?? '').trim();
    if (normalized.isEmpty) {
      return _defaultFavoriteScope;
    }
    return normalized;
  }

  String _favoriteStorageKey(String? scopeKey) {
    return 'movieIds:${_normalizeFavoriteScope(scopeKey)}';
  }

  Future<void> init() async {
    await _ensureBox(_favoriteBoxName);
    await _ensureBox(_reviewDraftBoxName);
    await _ensureBox(_movieSearchHistoryBoxName);
  }

  Future<void> cacheFavoriteMovieIds(
    List<String> movieIds, {
    String? scopeKey,
  }) async {
    final box = await _ensureBox(_favoriteBoxName);
    await box.put(_favoriteStorageKey(scopeKey), movieIds);
  }

  Future<List<String>> getFavoriteMovieIds({String? scopeKey}) async {
    final box = await _ensureBox(_favoriteBoxName);
    final storageKey = _favoriteStorageKey(scopeKey);
    final raw = box.get(storageKey, defaultValue: <String>[]);
    if (raw is List) {
      return raw.whereType<String>().toList();
    }

    // Backward compatibility: migrate old global key once.
    if (scopeKey != null && scopeKey.trim().isNotEmpty) {
      final legacyRaw = box.get('movieIds', defaultValue: <String>[]);
      if (legacyRaw is List) {
        final migrated = legacyRaw.whereType<String>().toList();
        await box.put(storageKey, migrated);
        return migrated;
      }
    }

    return const [];
  }

  Future<void> saveReviewDraft({
    required String key,
    required Map<String, dynamic> payload,
  }) async {
    final box = await _ensureBox(_reviewDraftBoxName);
    await box.put(key, payload);
  }

  Future<Map<String, dynamic>?> getReviewDraft(String key) async {
    final box = await _ensureBox(_reviewDraftBoxName);
    final raw = box.get(key);
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  Future<void> clearReviewDraft(String key) async {
    final box = await _ensureBox(_reviewDraftBoxName);
    await box.delete(key);
  }

  Future<int> getReviewDraftCount() async {
    final box = await _ensureBox(_reviewDraftBoxName);
    return box.length;
  }

  Future<List<Map<String, dynamic>>> getAllReviewDrafts() async {
    final box = await _ensureBox(_reviewDraftBoxName);
    final drafts = <Map<String, dynamic>>[];

    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! Map) {
        continue;
      }

      final normalized = raw.map((k, v) => MapEntry(k.toString(), v));
      drafts.add({'key': key.toString(), ...normalized});
    }

    drafts.sort((a, b) {
      final aDate = _parseDateTime(a['createdAt']);
      final bDate = _parseDateTime(b['createdAt']);
      if (aDate == null && bDate == null) {
        return 0;
      }
      if (aDate == null) {
        return 1;
      }
      if (bDate == null) {
        return -1;
      }
      return bDate.compareTo(aDate);
    });

    return drafts;
  }

  DateTime? _parseDateTime(dynamic raw) {
    if (raw is DateTime) {
      return raw;
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw.trim());
    }
    return null;
  }

  Future<void> cacheMovieSearchHistory(List<String> queries) async {
    final box = await _ensureBox(_movieSearchHistoryBoxName);
    await box.put('queries', queries);
  }

  Future<List<String>> getMovieSearchHistory() async {
    final box = await _ensureBox(_movieSearchHistoryBoxName);
    final raw = box.get('queries', defaultValue: <String>[]);
    if (raw is List) {
      return raw.whereType<String>().toList();
    }
    return const [];
  }

  Future<void> clearMovieSearchHistory() async {
    final box = await _ensureBox(_movieSearchHistoryBoxName);
    await box.delete('queries');
  }

  Future<Box<dynamic>> _ensureBox(String name) async {
    if (Hive.isBoxOpen(name)) {
      return Hive.box<dynamic>(name);
    }
    return Hive.openBox<dynamic>(name);
  }
}
