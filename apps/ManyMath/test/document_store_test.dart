import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:manymath/src/document_store.dart';
import 'package:manymath/src/papers.dart';
import 'package:manymath/src/theme.dart';
import 'package:manyui/manyui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quota_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('in-memory store is synchronous to construct and plugin-free', () async {
    final store = DocumentStore.inMemory(now: () => DateTime.utc(2026));
    final document = store.documents.first;
    expect(store.updateSource(document.id, 'local edit'), isTrue);
    await store.flush();
    expect(store.byId(document.id)?.source, 'local edit');
  });

  test(
    'a failed save while loading keeps the library and reports it',
    () async {
      final stored = jsonEncode(<Object?>[
        <String, Object?>{
          'id': 'mine',
          'name': 'My notes',
          'source': 'kept',
          'updatedAt': 1234,
        },
      ]);
      final preferences = QuotaPreferences(<String, Object>{
        DocumentStore.documentsStorageKey: stored,
      });

      // Injecting the bundled papers needs a save, which the quota refuses.
      final store = await DocumentStore.load(preferences: preferences);
      expect(store.byId('mine')?.source, 'kept');
      expect(store.documents, hasLength(1 + papers.length));
      expect(store.takeLoadError(), isA<DocumentPersistenceException>());
      expect(store.takeLoadError(), isNull, reason: 'reported once');
      expect(preferences.values[DocumentStore.documentsStorageKey], stored);
    },
  );

  test('a fresh store creates and durably saves the bundled papers', () async {
    final store = await DocumentStore.load(now: () => DateTime.utc(2026));
    expect(store.documents, hasLength(papers.length));
    expect(
      store.documents.map((document) => document.name),
      papers.map((paper) => paper.name),
    );

    final reloaded = await DocumentStore.load();
    expect(
      reloaded.documents.map((document) => document.source),
      store.documents.map((document) => document.source),
    );
  });

  test('rapid source saves are ordered and the last edit wins', () async {
    var tick = 0;
    final store = await DocumentStore.load(
      now: () => DateTime.utc(2026, 1, 1, 0, 0, tick++),
    );
    final document = store.create(name: 'Notes', source: 'initial');
    for (var index = 0; index < 25; index++) {
      store.updateSource(document.id, 'edit $index');
    }
    await store.flush();

    final reloaded = await DocumentStore.load();
    expect(reloaded.byId(document.id)?.source, 'edit 24');
  });

  test('one corrupt entry does not discard valid documents', () async {
    final valid = <String, Object?>{
      'id': 'valid',
      'name': 'Recovered',
      'source': r'\[x^2\]',
      'updatedAt': 1234,
    };
    final raw = jsonEncode(<Object?>[
      valid,
      <String, Object?>{'id': 42},
    ]);
    SharedPreferences.setMockInitialValues(<String, Object>{
      DocumentStore.documentsStorageKey: raw,
    });

    final store = await DocumentStore.load();
    // The valid doc is preserved first; bundled papers are injected after it
    // because no tombstones exist to suppress them.
    expect(store.documents.first.id, 'valid');
    expect(store.documents.length, 1 + papers.length);
    expect(store.recoveryPayload, raw);

    final normalized =
        jsonDecode(
              (await SharedPreferences.getInstance()).getString(
                DocumentStore.documentsStorageKey,
              )!,
            )
            as List<Object?>;
    expect(normalized, hasLength(1 + papers.length));
  });

  test('an out-of-range timestamp is isolated as one corrupt entry', () async {
    final valid = <String, Object?>{
      'id': 'valid',
      'name': 'Recovered',
      'source': 'kept',
      'updatedAt': 1234,
    };
    final raw = jsonEncode(<Object?>[
      valid,
      <String, Object?>{
        'id': 'bad-date',
        'source': 'discarded',
        'updatedAt': 9223372036854775807,
      },
    ]);
    SharedPreferences.setMockInitialValues(<String, Object>{
      DocumentStore.documentsStorageKey: raw,
    });

    final store = await DocumentStore.load();

    // The valid doc is preserved; bundled papers are also injected because no
    // tombstones exist to suppress them.
    expect(store.documents.first.id, 'valid');
    expect(store.documents.length, 1 + papers.length);
    expect(store.recoveryPayload, raw);
  });

  test(
    'unreadable data is backed up before the bundled papers are saved',
    () async {
      const raw = 'not json at all {';
      SharedPreferences.setMockInitialValues(<String, Object>{
        DocumentStore.documentsStorageKey: raw,
      });

      final store = await DocumentStore.load();
      expect(store.documents, hasLength(papers.length));
      expect(store.recoveryPayload, raw);
      await store.clearRecoveryPayload();
      expect(store.recoveryPayload, isNull);
    },
  );

  test(
    'empty store with no tombstones is backfilled with bundled papers',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        DocumentStore.documentsStorageKey: '[]',
      });
      final store = await DocumentStore.load();
      // No tombstones -> all bundled papers are injected so the library isn't
      // silently empty. Explicit removals are tracked separately and respected.
      expect(store.documents, hasLength(papers.length));
    },
  );

  test('duplicating a bundled paper does not make the copy its seed', () async {
    final store = await DocumentStore.load(now: () => DateTime.utc(2026));
    final paper = store.documents.first;
    final copy = store.duplicate(paper.id)!;
    await store.close();

    final reloaded = await DocumentStore.load();
    expect(reloaded.byId(copy.id)?.seedKey, isNull);
    expect(reloaded.byId(paper.id)?.seedKey, papers.first.name);
    expect(reloaded.remove(copy.id), isTrue);
    await reloaded.close();

    // Removing the copy did not tombstone the paper: it is still present and
    // only its own removal keeps it out.
    final afterCopy = await DocumentStore.load();
    expect(afterCopy.byId(paper.id), isNotNull);
    expect(afterCopy.remove(paper.id), isTrue);
    await afterCopy.close();
    final afterPaper = await DocumentStore.load();
    expect(
      afterPaper.documents.map((document) => document.seedKey),
      isNot(contains(papers.first.name)),
    );
  });

  test('a pre-seedKey edited paper is keyed by name, not duplicated', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      DocumentStore.documentsStorageKey: jsonEncode(<Object?>[
        <String, Object?>{
          'id': 'legacy',
          'name': papers.first.name,
          'source': '${papers.first.source}\n% local edit',
          'updatedAt': 1234,
        },
      ]),
    });

    final store = await DocumentStore.load();
    final migrated = store.byId('legacy')!;
    expect(migrated.seedKey, papers.first.name);
    expect(migrated.seedDigest, seedSourceDigest(papers.first.source));
    expect(migrated.isUneditedSeed, isFalse);
    expect(migrated.source, endsWith('% local edit'));
    expect(store.documents, hasLength(papers.length));
  });

  test('a fully unreadable store respects removed seeds', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      DocumentStore.documentsStorageKey: jsonEncode(<Object?>[
        <String, Object?>{'id': 42},
      ]),
      DocumentStore.removedSeedsStorageKey: jsonEncode(<String>[
        papers.first.name,
      ]),
    });

    final store = await DocumentStore.load();
    expect(store.documents, hasLength(papers.length - 1));
    expect(
      store.documents.map((document) => document.seedKey),
      isNot(contains(papers.first.name)),
    );
  });

  test('seed documents store a digest instead of a second copy', () async {
    final store = await DocumentStore.load(now: () => DateTime.utc(2026));
    await store.close();
    final raw = (await SharedPreferences.getInstance()).getString(
      DocumentStore.documentsStorageKey,
    )!;
    expect(raw, isNot(contains('"seedSource"')));
    final sources = papers.fold<int>(0, (sum, p) => sum + p.source.length);
    expect(raw.length, lessThan(sources * 1.5));
  });

  test('a stored seed copy becomes a digest and still detects edits', () async {
    final edited = '${papers.first.source}\n% mine';
    SharedPreferences.setMockInitialValues(<String, Object>{
      DocumentStore.documentsStorageKey: jsonEncode(<Object?>[
        <String, Object?>{
          'id': 'unedited',
          'name': papers.first.name,
          'source': 'an older printing',
          'updatedAt': 1234,
          'seedKey': papers.first.name,
          'seedSource': 'an older printing',
        },
        <String, Object?>{
          'id': 'edited',
          'name': papers.last.name,
          'source': edited,
          'updatedAt': 1234,
          'seedKey': papers.last.name,
          'seedSource': 'an older printing of the last paper',
        },
      ]),
    });

    final store = await DocumentStore.load();
    // The unedited seed follows the bundled paper; the edited one is kept.
    expect(store.byId('unedited')?.source, papers.first.source);
    expect(store.byId('edited')?.source, edited);
    await store.close();
    final raw = (await SharedPreferences.getInstance()).getString(
      DocumentStore.documentsStorageKey,
    )!;
    expect(raw, isNot(contains('"seedSource"')));
    expect(raw, contains(seedSourceDigest(papers.first.source)));
  });

  test('explicitly removed seed docs are not reinjected on reload', () async {
    final store = await DocumentStore.load(now: () => DateTime.utc(2026));
    for (final doc in store.documents.toList()) {
      store.remove(doc.id);
    }
    await store.close();

    final reloaded = await DocumentStore.load();
    expect(reloaded.documents, isEmpty);
  });

  test('document operations and settings round-trip', () async {
    var tick = 0;
    final store = await DocumentStore.load(
      now: () => DateTime.utc(2026, 1, 1, 0, 0, tick++),
    );
    final seedIds = store.documents.map((document) => document.id).toList();
    final original = store.create(name: '  A  ', source: 'source');
    expect(original.name, 'A');
    expect(store.rename(original.id, '  B  '), isTrue);
    final copy = store.duplicate(original.id)!;
    expect(copy.name, 'Copy of B');
    expect(store.remove(original.id), isTrue);
    for (final id in seedIds) {
      expect(store.remove(id), isTrue);
    }

    store.splitRatio = 0.99;
    store.themeMode = MThemeMode.dark;
    store.lastOpenedId = copy.id;
    await store.close();

    final reloaded = await DocumentStore.load();
    expect(reloaded.documents.map((document) => document.name), <String>[
      'Copy of B',
    ]);
    expect(reloaded.splitRatio, 0.85);
    expect(reloaded.themeMode, MThemeMode.dark);
    expect(reloaded.lastOpenedId, copy.id);
  });

  test('app theme mode persists and falls back to the legacy key', () async {
    final store = await DocumentStore.load();
    expect(store.appThemeMode, AppThemeMode.system);

    store.themeMode = MThemeMode.dark;
    await store.flush();
    expect(store.appThemeMode, AppThemeMode.dark);

    store.appThemeMode = AppThemeMode.night;
    await store.close();

    final reloaded = await DocumentStore.load();
    expect(reloaded.appThemeMode, AppThemeMode.night);
  });
}
