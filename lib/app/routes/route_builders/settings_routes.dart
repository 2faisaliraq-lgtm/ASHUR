import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/widgets/loading_widget.dart';
import 'package:material_ui/material_ui.dart';

import '../../../features/settings/presentation/pages/formatting_settings_page.dart';
import '../../../features/settings/presentation/pages/notification_settings_page.dart';
import '../../../features/settings/presentation/pages/pdf_settings_page.dart';
import '../../../features/settings/presentation/pages/settings_page.dart';
import '../../../features/settings/setting_feature.dart';
import '../route_paths.dart';

/// مسارات الإعدادات
Map<String, WidgetBuilder> get settingsRoutes => {
  RoutePaths.settings: (context) {
    final user = FirebaseAuth.instance.currentUser;
    return FutureBuilder<Widget>(
      future: SettingFeature.createDashboard(user?.email ?? ''),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return LoadingWidget(message: 'جاري التحميل...');
        }
        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }
        return snapshot.data ??
            const Center(child: Text('جاري تحميل الإعدادات...'));
      },
    );
  },
  RoutePaths.settingsList: (context) {
    final user = FirebaseAuth.instance.currentUser;
    return FutureBuilder<Widget>(
      future: SettingFeature.createDashboard(user?.email ?? ''),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return LoadingWidget(message: 'جاري التحميل...');
        }
        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }
        return snapshot.data ??
            const Center(child: Text('جاري تحميل الإعدادات...'));
      },
    );
  },
  RoutePaths.systemSettings: (context) => const SettingsPage(),
  RoutePaths.formattingSettings: (context) => const FormattingSettingsPage(),
  RoutePaths.notificationSettings: (context) =>
      const NotificationSettingsPage(),
  RoutePaths.pdfSettings: (context) => const PdfSettingsPage(),
};



