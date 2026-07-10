import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:manymath/src/document_store.dart';
import 'package:manymath/src/papers.dart';
import 'package:manyui/manyui.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    expect(store.documents.map((document) => document.id), <String>['valid']);
    expect(store.recoveryPayload, raw);

    final normalized =
        jsonDecode(
              (await SharedPreferences.getInstance()).getString(
                DocumentStore.documentsStorageKey,
              )!,
            )
            as List<Object?>;
    expect(normalized, hasLength(1));
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

    expect(store.documents.map((document) => document.id), <String>['valid']);
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
    'valid empty store stays empty instead of being silently reseeded',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        DocumentStore.documentsStorageKey: '[]',
      });
      final store = await DocumentStore.load();
      expect(store.documents, isEmpty);
    },
  );

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
}
