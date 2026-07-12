import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/document_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final store = await DocumentStore.load();
    runApp(ManyMathApp(store: store));
  } on Object catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'ManyMath bootstrap',
        context: ErrorDescription('while loading local documents'),
      ),
    );
    runApp(
      ManyMathApp(store: DocumentStore.inMemory(), persistentStorage: false),
    );
  }
}
