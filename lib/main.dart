import 'package:expense_app/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await FlutterEdgeAi.initialize(
      inferenceEngines: const [LiteRtLmEngine()],
    );
  } catch (_) {
    // The app and its experimental assistant remain available if native AI
    // initialization is unavailable on this device.
  }
  runApp(const ProviderScope(child: MyApp()));
}
