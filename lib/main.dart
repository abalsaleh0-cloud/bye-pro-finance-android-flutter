import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:expense_app/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterCryptography.enable();
  runApp(const ProviderScope(child: MyApp()));
}
