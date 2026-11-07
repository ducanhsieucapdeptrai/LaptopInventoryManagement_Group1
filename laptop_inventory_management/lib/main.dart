import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/database/database_helper.dart';
import 'core/theme/app_theme.dart';
import 'features/administration/screens/sign_in_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop FFI database initialization for local testing
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Pre-initialize local SQLite database with seeds
  try {
    await DatabaseHelper.instance.database;
  } catch (e) {
    debugPrint('Database initialization notice: $e');
  }

  runApp(const ProviderScope(child: LaptopInventoryApp()));
}

class LaptopInventoryApp extends StatelessWidget {
  const LaptopInventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LPSM — Laptop & PC Shop Management',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SignInScreen(),
    );
  }
}
