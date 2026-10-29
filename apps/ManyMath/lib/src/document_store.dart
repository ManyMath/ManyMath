import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:manyui/manyui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'papers.dart';
import 'theme.dart';

@immutable
class ManyMathDocument {
  const ManyMathDocument({
    required this.id,
    required this.name,
    required this.source,
    required this.updatedAt,
    this.seedKey,
    this.seedDigest,
  });

  factory ManyMathDocument.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Document entry must be an object.');
    }
    final id = value['id'];
    final source = value['source'];
    final timestamp = value['updatedAt'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Document id must be a non-empty string.');
    }
    if (source is! String) {
      throw const FormatException('Document source must be a string.');
    }
    if (timestamp is! int) {
      throw const FormatException('Document timestamp must be an integer.');
    }
    final rawName = value['name'];
    final name = rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim()
        : 'Untitled';
    DateTime updatedAt;
    try {
      updatedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } on RangeError {
      throw const FormatException('Document timestamp is out of range.');
    }
    final rawSeedKey = value['seedKey'];
    final rawSeedDigest = value['seedDigest'];
    // Stores before seedDigest kept the whole seed text instead.
    final rawSeedSource = value['seedSource'];
    return ManyMathDocument(
      id: id,
      name: name,
      source: source,
      updatedAt: updatedAt,
      seedKey: rawSeedKey is String && rawSeedKey.isNotEmpty
          ? rawSeedKey
          : null,
      seedDigest: rawSeedDigest is String
          ? rawSeedDigest
          : rawSeedSource is String
          ? seedSourceDigest(rawSeedSource)
          : null,
    );
  }

  final String id;
  final String name;
  final String source;
  final DateTime updatedAt;
  // Stable key linking this document to its originating paper; null for
  // user-created documents. Never changes, even if the user renames the doc.
  final String? seedKey;
  // A digest of the paper source as it was when this document was seeded.
  // While the source still has this digest the user has not edited it, so
  // the doc can be refreshed safely. A digest rather than the text itself
  // keeps every bundled paper from being stored twice.
  final String? seedDigest;

  /// Whether the document still holds the paper text it was seeded with.
  bool get isUneditedSeed =>
      seedDigest != null && seedSourceDigest(source) == seedDigest;

  ManyMathDocument copyWith({
    String? name,
    String? source,
    DateTime? updatedAt,
    String? seedKey,
    String? seedDigest,
  }) {
    return ManyMathDocument(
      id: id,
      name: name ?? this.name,
      source: source ?? this.source,
      updatedAt: updatedAt ?? this.updatedAt,
      seedKey: seedKey ?? this.seedKey,
      seedDigest: seedDigest ?? this.seedDigest,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'source': source,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    if (seedKey != null) 'seedKey': seedKey,
    if (seedDigest != null) 'seedDigest': seedDigest,
  };
}

/// The SHA-256 of [source]'s UTF-8 bytes, as lowercase hex.
String seedSourceDigest(String source) =>
    sha256.convert(utf8.encode(source)).toString();

class DocumentPersistenceException implements Exception {
  const DocumentPersistenceException(this.operation, [this.cause]);

  final String operation;
  final Object? cause;

  @override
  String toString() {
    final detail = cause == null ? '' : ': $cause';
    return 'DocumentPersistenceException($operation)$detail';
  }
}

/// Local-first document persistence backed by the platform preferences store.
///
/// Writes are serialized, so an older platform write cannot land after a
/// newer one. Call [flush] after a save boundary and [close] before an orderly
/// shutdown to surface platform failures instead of displaying a false saved
/// state.
class DocumentStore extends ChangeNotifier {
  DocumentStore._(this._preferences, this._documents, this._now);

  /// Creates a synchronous, plugin-free store for widget tests and previews.
  /// Passing null [documents] seeds the bundled papers; passing an empty
  /// iterable starts with no documents.
  factory DocumentStore.inMemory({
    Iterable<ManyMathDocument>? documents,
    DateTime Function()? now,
  }) {
    final clock = now ?? DateTime.now;
    return DocumentStore._(
      _MemoryDocumentPreferences(),
      documents?.toList() ?? _seedDocuments(clock()),
      clock,
    );
  }

  static const documentsStorageKey = 'manymath.documents.v1';
  static const recoveryStorageKey = 'manymath.documents.recovery.v1';
  static const removedSeedsStorageKey = 'manymath.settings.removedSeeds';
  static const _lastOpenKey = 'manymath.settings.lastOpen';
  static const _splitKey = 'manymath.settings.split';
  static const _themeModeKey = 'manymath.settings.themeMode';
  static const _appThemeKey = 'manymath.settings.appTheme';

  final _DocumentPreferences _preferences;
  final List<ManyMathDocument> _documents;
  final DateTime Function() _now;
  Future<void> _writeTail = Future<void>.value();
  final List<DocumentPersistenceException> _unreportedErrors =
      <DocumentPersistenceException>[];
  String? _pendingDocumentsPayload;
  var _documentsWriteScheduled = false;
  var _idCounter = 0;
  var _disposed = false;

  void Function(DocumentPersistenceException error, StackTrace stackTrace)?
  onPersistError;

  static Future<DocumentStore> load({
    SharedPreferences? preferences,
    DateTime Function()? now,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final storage = _SharedDocumentPreferences(prefs);
    final raw = storage.getString(documentsStorageKey);
    final documents = <ManyMathDocument>[];
    var needsRepair = false;

    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List<Object?>) {
          throw const FormatException('Document store must be a list.');
        }
        final ids = <String>{};
        for (final entry in decoded) {
          try {
            final document = ManyMathDocument.fromJson(entry);
            if (!ids.add(document.id)) {
              throw const FormatException('Duplicate document id.');
            }
            documents.add(document);
          } on FormatException {
            needsRepair = true;
          }
        }
      } on FormatException {
        needsRepair = true;
      }
    }

    if (needsRepair && raw != null) {
      await _requireWrite(
        'back up corrupt document data',
        storage.setString(recoveryStorageKey, raw),
      );
    }

    // Reconcile the stored document list against the current bundled papers.
    // This runs on every load so that papers added or updated in a new build
    // are reflected for returning users without clearing their data.
    final removedSeeds = _decodeRemovedSeeds(
      storage.getString(removedSeedsStorageKey),
    );
    final seedsChanged = _reconcileSeeds(
      documents,
      now ?? DateTime.now,
      removedSeeds,
    );

    // Stores written before seedDigest hold a full copy of every seed's text;
    // saving once drops it.
    final legacySeedCopies = raw != null && raw.contains('"seedSource"');

    final store = DocumentStore._(storage, documents, now ?? DateTime.now);
    if (raw == null || needsRepair || seedsChanged || legacySeedCopies) {
      // The documents read above are intact (and any damaged original is
      // backed up), so a failed save here, such as a full browser storage
      // quota, must not cost the reader their library: keep the store and
      // let the editor report the failure like any other save.
      try {
        await store._persistImmediately();
      } on DocumentPersistenceException catch (error) {
        store._loadError = error;
      }
    }
    return store;
  }

  DocumentPersistenceException? _loadError;

  /// A save that failed while loading, for the editor to report once.
  DocumentPersistenceException? takeLoadError() {
    final error = _loadError;
    _loadError = null;
    return error;
  }

  /// The bundled papers as fresh documents, for an in-memory session.
  static List<ManyMathDocument> _seedDocuments(DateTime timestamp) {
    return <ManyMathDocument>[
      for (var index = 0; index < papers.length; index++)
        ManyMathDocument(
          id:
              '${timestamp.microsecondsSinceEpoch.toRadixString(36)}'
              '-seed-$index',
          name: papers[index].name,
          source: papers[index].source,
          updatedAt: timestamp,
          seedKey: papers[index].name,
          seedDigest: seedSourceDigest(papers[index].source),
        ),
    ];
  }

  // Mutates [documents] in place. Returns true if any change was made so the
  // caller knows to persist the updated list.
  //
  // Three passes:
  //   1. Migration: assign seedKey/seedDigest to pre-existing seed docs that
  //      pre-date this field. Each paper claims at most one document, and a
  //      paper already represented claims none, so a user's "Copy of" a
  //      paper never becomes the seed itself.
  //   2. Refresh: if a seed doc's source still has its seedDigest (user
  //      hasn't edited it) but the paper has since been updated, replace it.
  //   3. Injection: add any papers not yet represented in the store, skipping
  //      papers the user has explicitly removed (tracked in [removedSeeds]).
  //      A fresh or fully unreadable store is seeded here too.
  static bool _reconcileSeeds(
    List<ManyMathDocument> documents,
    DateTime Function() now,
    Set<String> removedSeeds,
  ) {
    var changed = false;

    // Pass 1: migrate docs without a seedKey. The pre-seedKey schema named
    // every seed after its paper, so a name match identifies an edited seed;
    // a source match catches a renamed, unedited one.
    final keyed = <String>{
      for (final doc in documents)
        if (doc.seedKey != null) doc.seedKey!,
    };
    for (final paper in papers) {
      if (keyed.contains(paper.name)) continue;
      var index = documents.indexWhere(
        (doc) => doc.seedKey == null && doc.name == paper.name,
      );
      if (index < 0) {
        index = documents.indexWhere(
          (doc) => doc.seedKey == null && doc.source == paper.source,
        );
      }
      if (index < 0) continue;
      documents[index] = documents[index].copyWith(
        seedKey: paper.name,
        seedDigest: seedSourceDigest(paper.source),
      );
      keyed.add(paper.name);
      changed = true;
    }

    // Pass 2: refresh unmodified seed docs whose paper source has changed.
    for (var i = 0; i < documents.length; i++) {
      final doc = documents[i];
      if (doc.seedKey == null || !doc.isUneditedSeed) continue;
      for (final paper in papers) {
        if (paper.name != doc.seedKey) continue;
        if (paper.source == doc.source) break; // already current
        documents[i] = doc.copyWith(
          source: paper.source,
          seedDigest: seedSourceDigest(paper.source),
        );
        changed = true;
        break;
      }
    }

    // Pass 3: inject papers missing from the store entirely, unless the user
    // already removed them (tracked in removedSeeds).
    final seededKeys = <String>{
      for (final doc in documents)
        if (doc.seedKey != null) doc.seedKey!,
    };
    final timestamp = now();
    var seedIndex = documents.length;
    for (final paper in papers) {
      if (seededKeys.contains(paper.name) ||
          removedSeeds.contains(paper.name)) {
        continue;
      }
      documents.add(
        ManyMathDocument(
          id:
              '${timestamp.microsecondsSinceEpoch.toRadixString(36)}'
              '-seed-$seedIndex',
          name: paper.name,
          source: paper.source,
          updatedAt: timestamp,
          seedKey: paper.name,
          seedDigest: seedSourceDigest(paper.source),
        ),
      );
      seedIndex++;
      changed = true;
    }

    return changed;
  }

  List<ManyMathDocument> get documents =>
      List<ManyMathDocument>.unmodifiable(_documents);

  String? get recoveryPayload => _preferences.getString(recoveryStorageKey);

  ManyMathDocument? byId(String id) {
    for (final document in _documents) {
      if (document.id == id) return document;
    }
    return null;
  }

  String? get lastOpenedId => _preferences.getString(_lastOpenKey);

  set lastOpenedId(String? id) {
    if (id == null) {
      _enqueue(
        'clear last opened document',
        () => _preferences.remove(_lastOpenKey),
      );
    } else {
      _enqueue(
        'save last opened document',
        () => _preferences.setString(_lastOpenKey, id),
      );
    }
  }

  double get splitRatio {
    final value = _preferences.getDouble(_splitKey);
    if (value == null || !value.isFinite || value < 0.15 || value > 0.85) {
      return 0.5;
    }
    return value;
  }

  set splitRatio(double value) {
    final normalized = value.isFinite ? value.clamp(0.15, 0.85) : 0.5;
    _enqueue(
      'save editor split',
      () => _preferences.setDouble(_splitKey, normalized),
    );
  }

  MThemeMode get themeMode {
    final saved = _preferences.getString(_themeModeKey);
    return MThemeMode.values.asNameMap()[saved] ?? MThemeMode.system;
  }

  set themeMode(MThemeMode mode) {
    _enqueue(
      'save theme mode',
      () => _preferences.setString(_themeModeKey, mode.name),
    );
  }

  /// The app-wide scheme the header toggle scrolls through. Falls back to
  /// the legacy [themeMode] key for stores saved before night mode existed.
  AppThemeMode get appThemeMode {
    final saved = _preferences.getString(_appThemeKey);
    return AppThemeMode.values.asNameMap()[saved] ??
        switch (themeMode) {
          MThemeMode.light => AppThemeMode.light,
          MThemeMode.dark => AppThemeMode.dark,
          MThemeMode.system => AppThemeMode.system,
        };
  }

  set appThemeMode(AppThemeMode mode) {
    _enqueue(
      'save app theme mode',
      () => _preferences.setString(_appThemeKey, mode.name),
    );
  }

  ManyMathDocument create({required String name, required String source}) {
    _checkOpen();
    final timestamp = _now();
    final normalizedName = name.trim().isEmpty ? 'Untitled' : name.trim();
    final document = ManyMathDocument(
      id: '${timestamp.microsecondsSinceEpoch.toRadixString(36)}-${_idCounter++}',
      name: normalizedName,
      source: source,
      updatedAt: timestamp,
    );
    _documents.insert(0, document);
    _persist();
    notifyListeners();
    return document;
  }

  bool rename(String id, String name) {
    _checkOpen();
    final normalizedName = name.trim();
    final index = _indexOf(id);
    if (index < 0 || normalizedName.isEmpty) return false;
    _documents[index] = _documents[index].copyWith(
      name: normalizedName,
      updatedAt: _now(),
    );
    _persist();
    notifyListeners();
    return true;
  }

  ManyMathDocument? duplicate(String id) {
    final document = byId(id);
    if (document == null) return null;
    return create(name: 'Copy of ${document.name}', source: document.source);
  }

  bool remove(String id) {
    _checkOpen();
    final index = _indexOf(id);
    if (index < 0) return false;
    final doc = _documents[index];
    _documents.removeAt(index);
    if (lastOpenedId == id) lastOpenedId = null;
    if (doc.seedKey != null) _persistRemovedSeed(doc.seedKey!);
    _persist();
    notifyListeners();
    return true;
  }

  void _persistRemovedSeed(String key) {
    _enqueue('record removed seed', () async {
      final current = _decodeRemovedSeeds(
        _preferences.getString(removedSeedsStorageKey),
      );
      current.add(key);
      return _preferences.setString(
        removedSeedsStorageKey,
        jsonEncode(current.toList()),
      );
    });
  }

  static Set<String> _decodeRemovedSeeds(String? raw) {
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<String>().toSet();
    } catch (_) {}
    return {};
  }

  bool updateSource(String id, String source) {
    _checkOpen();
    final index = _indexOf(id);
    if (index < 0 || _documents[index].source == source) return false;
    _documents[index] = _documents[index].copyWith(
      source: source,
      updatedAt: _now(),
    );
    _persist();
    return true;
  }

  /// Re-schedules the current snapshot, including after a failed write.
  void save() {
    _checkOpen();
    _persist();
  }

  Future<void> clearRecoveryPayload() async {
    _enqueue(
      'clear recovered document data',
      () => _preferences.remove(recoveryStorageKey),
    );
    await flush();
    if (!_disposed) notifyListeners();
  }

  int _indexOf(String id) =>
      _documents.indexWhere((document) => document.id == id);

  void _persist() {
    _pendingDocumentsPayload = _encodedDocuments();
    _scheduleDocumentsWrite();
  }

  void _scheduleDocumentsWrite() {
    if (_documentsWriteScheduled || _pendingDocumentsPayload == null) return;
    _documentsWriteScheduled = true;
    _enqueue('save documents', _writePendingDocuments);
  }

  Future<bool> _writePendingDocuments() async {
    try {
      while (_pendingDocumentsPayload != null) {
        final payload = _pendingDocumentsPayload!;
        _pendingDocumentsPayload = null;
        if (!await _preferences.setString(documentsStorageKey, payload)) {
          return false;
        }
      }
      return true;
    } finally {
      _documentsWriteScheduled = false;
      _scheduleDocumentsWrite();
    }
  }

  Future<void> _persistImmediately() {
    return _requireWrite(
      'save documents',
      _preferences.setString(documentsStorageKey, _encodedDocuments()),
    );
  }

  String _encodedDocuments() => jsonEncode(<Object?>[
    for (final document in _documents) document.toJson(),
  ]);

  void _enqueue(String operation, Future<bool> Function() write) {
    _checkOpen();
    _writeTail = _writeTail.then((_) async {
      try {
        await _requireWrite(operation, write());
      } on DocumentPersistenceException catch (error, stackTrace) {
        _unreportedErrors.add(error);
        onPersistError?.call(error, stackTrace);
      }
    });
  }

  static Future<void> _requireWrite(
    String operation,
    Future<bool> result,
  ) async {
    try {
      if (!await result) {
        throw DocumentPersistenceException(operation);
      }
    } on DocumentPersistenceException {
      rethrow;
    } on Object catch (error) {
      throw DocumentPersistenceException(operation, error);
    }
  }

  /// Waits for every queued write and reports the first failure since the
  /// preceding call. Later queued writes still run when an earlier one fails.
  Future<void> flush() async {
    while (true) {
      final tail = _writeTail;
      await tail;
      if (identical(tail, _writeTail) &&
          !_documentsWriteScheduled &&
          _pendingDocumentsPayload == null) {
        break;
      }
    }
    if (_unreportedErrors.isNotEmpty) {
      throw _unreportedErrors.removeAt(0);
    }
  }

  /// Flushes outstanding saves before disposing this notifier.
  Future<void> close() async {
    if (_disposed) return;
    await flush();
    dispose();
  }

  void _checkOpen() {
    if (_disposed) {
      throw StateError('DocumentStore is closed.');
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}

abstract interface class _DocumentPreferences {
  String? getString(String key);
  double? getDouble(String key);
  Future<bool> setString(String key, String value);
  Future<bool> setDouble(String key, double value);
  Future<bool> remove(String key);
}

class _SharedDocumentPreferences implements _DocumentPreferences {
  const _SharedDocumentPreferences(this._preferences);

  final SharedPreferences _preferences;

  @override
  String? getString(String key) => _preferences.getString(key);

  @override
  double? getDouble(String key) => _preferences.getDouble(key);

  @override
  Future<bool> setString(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<bool> setDouble(String key, double value) =>
      _preferences.setDouble(key, value);

  @override
  Future<bool> remove(String key) => _preferences.remove(key);
}

class _MemoryDocumentPreferences implements _DocumentPreferences {
  final Map<String, Object> _values = <String, Object>{};

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  double? getDouble(String key) => _values[key] as double?;

  @override
  Future<bool> setString(String key, String value) {
    _values[key] = value;
    return Future<bool>.value(true);
  }

  @override
  Future<bool> setDouble(String key, double value) {
    _values[key] = value;
    return Future<bool>.value(true);
  }

  @override
  Future<bool> remove(String key) {
    _values.remove(key);
    return Future<bool>.value(true);
  }
}
