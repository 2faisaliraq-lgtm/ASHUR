import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'app/config/app_initializer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await AppInitializer.initialize();
  AppInitializer.resetNotificationChecks();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const AshurApp());

  await AppInitializer.initializeBackground();
}
