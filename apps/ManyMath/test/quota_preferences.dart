import 'package:manymath/src/document_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferences whose document list cannot be written, like a browser
/// storage quota that the stored library already nearly fills.
class QuotaPreferences implements SharedPreferences {
  QuotaPreferences(this.values);

  final Map<String, Object> values;

  @override
  String? getString(String key) => values[key] as String?;

  @override
  double? getDouble(String key) => values[key] as double?;

  @override
  Future<bool> setString(String key, String value) async {
    if (key == DocumentStore.documentsStorageKey) return false;
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async => values.remove(key) != null;

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
