import 'dart:async';
import 'dart:io';

import 'package:ashur/core/widgets/loading_widget.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/assyrian_theme.dart';

/// ويدجت لمراقبة الاتصال بالخادم وعرض شاشة أنيقة عند فقدان الاتصال
class ConnectionMonitor extends StatefulWidget {
  const ConnectionMonitor({required this.child, super.key});

  final Widget child;

  @override
  State<ConnectionMonitor> createState() => _ConnectionMonitorState();
}

class _ConnectionMonitorState extends State<ConnectionMonitor> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _hasInternet = true;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkInitialConnection();
    _startMonitoring();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialConnection() async {
    final hasInternet = await _checkInternetAccess();
    if (mounted && !hasInternet) {
      setState(() {
        _hasInternet = false;
      });
    }
  }

  void _startMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      final result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;
      final hasBasicConnection = result != ConnectivityResult.none;

      if (!hasBasicConnection) {
        if (_hasInternet && mounted) {
          setState(() {
            _hasInternet = false;
          });
        }
      } else {
        final hasRealInternet = await _checkInternetAccess();
        if (mounted && hasRealInternet != _hasInternet) {
          setState(() {
            _hasInternet = hasRealInternet;
          });
        }
      }
    });
  }

  Future<bool> _checkInternetAccess() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;

      if (result == ConnectivityResult.none) {
        return false;
      }

      try {
        final result = await InternetAddress.lookup('google.com');
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } on Exception catch (_) {
        return false;
      }
    } on Exception catch (_) {
      return false;
    }
  }

  Future<void> _handleRetry() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
    });

    final hasInternet = await _checkInternetAccess();

    if (mounted) {
      setState(() {
        _hasInternet = hasInternet;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasInternet) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1B365D), Color(0xFF2C5F7C)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120.w,
                      height: 120.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AssyrianTheme.crimsonRed.withValues(alpha: 0.15),
                        border: Border.all(
                          color: AssyrianTheme.crimsonRed.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.wifi_off_rounded,
                        size: 56.sp,
                        color: AssyrianTheme.crimsonRed,
                      ),
                    ),
                    SizedBox(height: 32.h),
                    Text(
                      'انقطع الاتصال بالخادم',
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: AssyrianTheme.ivoryWhite,
                        fontFamily: 'Cairo',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'تعذر الوصول إلى الخادم',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AssyrianTheme.primaryGold.withValues(alpha: 0.9),
                        fontFamily: 'Cairo',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'يرجى التحقق من اتصالك بالإنترنت ثم إعادة المحاولة',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AssyrianTheme.ivoryWhite.withValues(alpha: 0.7),
                        fontFamily: 'Cairo',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 40.h),
                    Container(
                      width: double.infinity,
                      height: 52.h,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AssyrianTheme.primaryGold, AssyrianTheme.bronzeBrown],
                        ),
                        borderRadius: BorderRadius.circular(14.r),
                        boxShadow: [
                          BoxShadow(
                            color: AssyrianTheme.primaryGold.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isChecking ? null : _handleRetry,
                        icon: _isChecking
                            ? LoadingWidget(size: 20)
                            : Icon(Icons.refresh_rounded, color: AssyrianTheme.deepBlue),
                        label: Text(
                          _isChecking ? 'جارٍ التحقق...' : 'إعادة المحاولة',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: AssyrianTheme.deepBlue,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: AssyrianTheme.deepBlue,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    TextButton.icon(
                      onPressed: _isChecking ? null : _handleRetry,
                      icon: Icon(
                        Icons.history_rounded,
                        size: 18.sp,
                        color: AssyrianTheme.primaryGold.withValues(alpha: 0.8),
                      ),
                      label: Text(
                        'محاولة سريعة',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AssyrianTheme.primaryGold.withValues(alpha: 0.9),
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
