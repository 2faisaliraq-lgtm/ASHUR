import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../email/email_normalization_service.dart';
import '../services/section_notification_service.dart';
import '../services/subscription_notification_service.dart';
import '../../features/customers/domain/repositories/customer_repository.dart';
import '../../features/customers/injection_container.dart' as customers;
import '../../features/inventory/domain/entities/product_entity.dart';
import '../../features/inventory/domain/repositories/product_repository.dart';
import '../../features/inventory/injection_container.dart' as inventory;
import '../../features/maintenance/domain/repositories/maintenance_repository.dart';
import '../../features/maintenance/injection_container.dart' as maintenance;
import '../../features/rentals/domain/repositories/rental_repository.dart';
import '../../features/rentals/injection_container.dart' as rentals;
import '../../features/expenses/domain/repositories/expense_repository.dart';
import '../../features/expenses/injection_container.dart' as expenses;
import '../../features/subscriptions/domain/repositories/subscription_repository.dart';

class NotificationForegroundService with WidgetsBindingObserver {
  static final EmailNormalizationService _emailService =
      EmailNormalizationService();
  static DateTime? _lastCheck;
  static Future<void>? _inFlightCheck;
  static final NotificationForegroundService _observer =
      NotificationForegroundService();
  static const _checkCooldown = Duration(minutes: 15);
  static const _notificationCallablesUnavailableMessage =
      'OneSignal sending function is unavailable; deploy Firebase Functions before scheduling pushes.';

  static Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(_observer);
    await _runChecks();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future(() => _runChecks());
    }
  }

  static Future<void> _runChecks({bool force = false}) async {
    final inFlight = _inFlightCheck;
    if (inFlight != null) return inFlight;
    if (!force &&
        _lastCheck != null &&
        DateTime.now().difference(_lastCheck!) < _checkCooldown) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;

    final future = _performChecks(user!.email!);
    _inFlightCheck = future;
    try {
      await future;
    } finally {
      _inFlightCheck = null;
    }
  }

  static Future<void> _performChecks(String userEmail) async {
    final orgEmail = _emailService.normalize(userEmail);
    final results = await Future.wait([
      _checkSection(orgEmail, _checkCustomers),
      _checkSection(orgEmail, _checkInventory),
      _checkSection(orgEmail, _checkMaintenance),
      _checkSection(orgEmail, _checkRentals),
      _checkSection(orgEmail, _checkExpenses),
      _checkSection(orgEmail, _checkSubscriptions),
    ]);
    if (results.every((success) => success)) {
      _lastCheck = DateTime.now();
    }
  }

  static Future<bool> _checkSection(
    String orgEmail,
    Future<void> Function(String) check,
  ) async {
    try {
      await check(orgEmail);
      return true;
    } on Object catch (error, stackTrace) {
      final errorText = error.toString();
      if (errorText.contains(_notificationCallablesUnavailableMessage) ||
          errorText.contains('firebase_functions/not-found') ||
          errorText.contains('firebase_functions/unimplemented')) {
        // Missing push callables are a deployment issue, not a failed local
        // notification scan. Cool down to avoid repeating the same scan/logs.
        _lastCheck = DateTime.now();
        debugPrint(
          'Skipping notification checks because required Firebase Functions are unavailable.',
        );
        return true;
      }
      debugPrint('Notification check failed for $orgEmail: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  static Future<void> _ensureCustomersInjected() async {
    if (!GetIt.instance.isRegistered<CustomerRepository>()) {
      await customers.initCustomers();
    }
  }

  static Future<void> _ensureInventoryInjected() async {
    if (!GetIt.instance.isRegistered<ProductRepository>()) {
      await inventory.initInventoryDependencies();
    }
  }

  static Future<void> _ensureMaintenanceInjected() async {
    if (!GetIt.instance.isRegistered<MaintenanceRepository>()) {
      await maintenance.initMaintenanceDependencies();
    }
  }

  static Future<void> _ensureRentalsInjected() async {
    if (!GetIt.instance.isRegistered<RentalRepository>()) {
      await rentals.initRentalDependencies();
    }
  }

  static Future<void> _ensureExpensesInjected() async {
    if (!GetIt.instance.isRegistered<ExpenseRepository>()) {
      await expenses.initExpenses();
    }
  }

  static Future<void> _checkCustomers(String orgEmail) async {
    await _ensureCustomersInjected();
    final repo = GetIt.instance<CustomerRepository>();
    final result = await repo.getCustomers(orgEmail);
    await result.fold(
      (failure) async => throw StateError(failure.message),
      (customers) =>
          SectionNotificationService.checkAndNotifyCustomers(customers),
    );
  }

  static Future<void> _checkInventory(String orgEmail) async {
    await _ensureInventoryInjected();
    final repo = GetIt.instance<ProductRepository>();
    final result = await repo.getProducts(organizationEmail: orgEmail);
    await result.fold(
      (failure) async => throw StateError(failure.message),
      (products) => SectionNotificationService.checkAndNotifyInventory(
        products.cast<ProductEntity>(),
      ),
    );
  }

  static Future<void> _checkMaintenance(String orgEmail) async {
    await _ensureMaintenanceInjected();
    final repo = GetIt.instance<MaintenanceRepository>();
    final result = await repo.getMaintenanceRequests(orgEmail);
    await result.fold(
      (failure) async => throw StateError(failure.message),
      (requests) =>
          SectionNotificationService.checkAndNotifyMaintenance(requests),
    );
  }

  static Future<void> _checkRentals(String orgEmail) async {
    await _ensureRentalsInjected();
    final repo = GetIt.instance<RentalRepository>();
    final result = await repo.getRentals(orgEmail);
    await result.fold(
      (failure) async => throw StateError(failure.message),
      (rentals) => SectionNotificationService.checkAndNotifyRentals(rentals),
    );
  }

  static Future<void> _checkExpenses(String orgEmail) async {
    await _ensureExpensesInjected();
    final repo = GetIt.instance<ExpenseRepository>();
    final result = await repo.getExpenses(orgEmail);
    await result.fold(
      (failure) async => throw StateError(failure.message),
      (expenses) => SectionNotificationService.checkAndNotifyExpenses(expenses),
    );
  }

  static Future<void> _checkSubscriptions(String orgEmail) async {
    // ✅ تم إزالة استدعاء resetSessionCheck() لأن قفل الجلسة أُزل من
    // SubscriptionNotificationService — الإشعارات تُفحص الآن في كل مرة دون قفل.
    final repo = GetIt.instance<SubscriptionRepository>();
    final result = await repo.getSubscriptions(orgEmail);
    await result.fold(
      (failure) async => throw StateError(failure.message),
      (subscriptions) =>
          SectionNotificationService.checkAndNotifySubscriptions(subscriptions),
    );
  }
}
