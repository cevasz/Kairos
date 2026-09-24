import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Toda la app formatea fechas en español de Colombia.
  await initializeDateFormatting('es_CO');
  runApp(const ProviderScope(child: KairosApp()));
}
