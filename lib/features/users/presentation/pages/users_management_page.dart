import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../bloc/users_bloc.dart';
import 'users_dashboard_page.dart';

/// صفحة إدارة المستخدمين الرئيسية مع Bloc Provider
class UsersManagementPage extends StatelessWidget {
  const UsersManagementPage({super.key});

  @override
  // ignore: cascade_invitations
  Widget build(BuildContext context) {
    // الحصول على بريد المستخدم الحالي
    final currentUser = FirebaseAuth.instance.currentUser;
    final rawEmail = currentUser?.email ?? '';

    // تطبيع البريد الإلكتروني لإزالة النقاط (Gmail تتجاهل النقاط)
    final emailService = EmailNormalizationService();
    final normalizedEmail = emailService.normalize(rawEmail);

    return BlocProvider<UsersBloc>.value(
      value: GetIt.instance<UsersBloc>(),
      child: UsersDashboardPage(organizationEmail: normalizedEmail),
    );
  }
}
