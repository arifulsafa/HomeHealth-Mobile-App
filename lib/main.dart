import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'config/app_config.dart';
import 'services/app_service_initializer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize app configuration
  await AppConfig.initialize();

  // Initialize app services (upload queue, file retention, etc.)
  await AppServiceInitializer.initialize();

  runApp(
    const ProviderScope(
      child: HealthDocApp(),
    ),
  );
}
