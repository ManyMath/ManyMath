import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:manyui/manyui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'papers.dart';

@immutable
class ManyMathDocument {
  const ManyMathDocument({
    required this.id,
    required this.name,
    required this.source,
    required this.updatedAt,
    this.seedKey,
    this.seedSource,
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
    final rawSeedSource = value['seedSource'];
    return ManyMathDocument(
      id: id,
      name: name,
      source: source,
      updatedAt: updatedAt,
      seedKey: rawSeedKey is String && rawSeedKey.isNotEmpty ? rawSeedKey : null,
      seedSource: rawSeedSource is String ? rawSeedSource : null,
    );
  }

  final String id;
  final String name;
  final String source;
  final DateTime updatedAt;
  // Stable key linking this document to its originating paper; null for
  // user-created documents. Never changes, even if the user renames the doc.
  final String? seedKey;
  // The paper source as it was when this document was seeded. If source ==
  // seedSource the user has not made edits, so the doc can be refreshed safely.
  final String? seedSource;

  ManyMathDocument copyWith({
    String? name,
    String? source,
    DateTime? updatedAt,
    String? seedKey,
    String? seedSource,
  }) {
    return ManyMathDocument(
      id: id,
      name: name ?? this.name,
      source: source ?? this.source,
      updatedAt: updatedAt ?? this.updatedAt,
      seedKey: seedKey ?? this.seedKey,
      seedSource: seedSource ?? this.seedSource,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'source': source,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    if (seedKey != null) 'seedKey': seedKey,
    if (seedSource != null) 'seedSource': seedSource,
  };
}

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
  /// iterable deliberately starts with no documents.
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

    if (raw == null || (needsRepair && documents.isEmpty)) {
      documents.addAll(_seedDocuments((now ?? DateTime.now)()));
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
    final removedSeeds = _decodeRemovedSeeds(storage.getString(removedSeedsStorageKey));
    final seedsChanged = _reconcileSeeds(documents, now ?? DateTime.now, removedSeeds);

    final store = DocumentStore._(storage, documents, now ?? DateTime.now);
    if (raw == null || needsRepair || seedsChanged) {
      await store._persistImmediately();
    }
    return store;
  }

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
          seedSource: papers[index].source,
        ),
    ];
  }

  // Mutates [documents] in place. Returns true if any change was made so the
  // caller knows to persist the updated list.
  //
  // Three passes:
  //   1. Migration: assign seedKey/seedSource to pre-existing seed docs that
  //      pre-date this field by matching their source against current papers.
  //   2. Refresh: if a seed doc's source still equals its seedSource (user
  //      hasn't edited it) but the paper has since been updated, replace it.
  //   3. Injection: add any papers not yet represented in the store, skipping
  //      papers the user has explicitly removed (tracked in [removedSeeds]).
  static bool _reconcileSeeds(
    List<ManyMathDocument> documents,
    DateTime Function() now,
    Set<String> removedSeeds,
  ) {
    var changed = false;

    // Pass 1: migrate docs without a seedKey by matching source content.
    for (var i = 0; i < documents.length; i++) {
      if (documents[i].seedKey != null) continue;
      for (final paper in papers) {
        if (documents[i].source == paper.source) {
          documents[i] = documents[i].copyWith(
            seedKey: paper.name,
            seedSource: paper.source,
          );
          changed = true;
          break;
        }
      }
    }

    // Pass 2: refresh unmodified seed docs whose paper source has changed.
    for (var i = 0; i < documents.length; i++) {
      final doc = documents[i];
      if (doc.seedKey == null || doc.seedSource == null) continue;
      if (doc.source != doc.seedSource) continue; // user has edits -- skip
      for (final paper in papers) {
        if (paper.name != doc.seedKey) continue;
        if (paper.source == doc.source) break; // already current
        documents[i] = doc.copyWith(
          source: paper.source,
          seedSource: paper.source,
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
      if (seededKeys.contains(paper.name) || removedSeeds.contains(paper.name)) continue;
      documents.add(
        ManyMathDocument(
          id:
              '${timestamp.microsecondsSinceEpoch.toRadixString(36)}'
              '-seed-$seedIndex',
          name: paper.name,
          source: paper.source,
          updatedAt: timestamp,
          seedKey: paper.name,
          seedSource: paper.source,
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
      final current = _decodeRemovedSeeds(_preferences.getString(removedSeedsStorageKey));
      current.add(key);
      return _preferences.setString(removedSeedsStorageKey, jsonEncode(current.toList()));
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
