import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/loading_widget.dart';

/// Mixin لإدارة عمليات الحفظ بشكل موحد
mixin SaveOperationMixin<T extends StatefulWidget> on State<T> {
  bool _isSaving = false;
  bool _hasInternet = true;
  int _saveOperationId = 0; // رقم تسلسلي لمنع الحفظ المتكرر

  /// التحقق من حالة الحفظ
  bool get isSaving => _isSaving;

  /// التحقق من حالة الاتصال
  bool get hasInternet => _hasInternet;

  /// تنفيذ عملية الحفظ مع إدارة الحالة والتحميل
  Future<void> performSaveOperation({
    required Future<bool> Function() saveFunction,
    required String successMessage,
    required String loadingMessage,
    VoidCallback? onSuccess,
    Function(String)? onError,
    bool navigateBackOnSuccess = true,
  }) async {
    // منع التنفيذ المتعدد
    if (_isSaving) {
      return;
    }

    // زيادة رقم العملية للتحقق من التعددية
    final operationId = ++_saveOperationId;

    setState(() {
      _isSaving = true;
    });

    try {
      // التحقق من أن هذه هي العملية الأحدث قبل التنفيذ
      if (operationId != _saveOperationId) {
        return;
      }

      // تنفيذ عملية الحفظ
      final success = await saveFunction();

      // التحقق مرة أخرى من أن هذه هي العملية الأحدث
      if (operationId != _saveOperationId) {
        return;
      }

      if (success) {
        // عرض رسالة النجاح
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
          if (onSuccess != null) {
            onSuccess();
          }
          if (navigateBackOnSuccess && mounted) {
            Navigator.of(context).pop(true);
          }
        }
      } else {
        // عرض رسالة خطأ عامة
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'حدث خطأ أثناء الحفظ، يرجى المحاولة مرة أخرى',
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
        if (onError != null) {
          onError('حدث خطأ أثناء الحفظ');
        }
      }
    } on Exception catch (_) {
      // عرض رسالة الخطأ
      final errorMessage = 'حدث خطأ: يرجى المحاولة مرة أخرى';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }

      if (onError != null) {
        onError(errorMessage);
      }
    } finally {
      // تحديث الحالة فقط إذا كانت هذه هي العملية الأحدث
      if (operationId == _saveOperationId && mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// التحقق من الاتصال بالإنترنت
  Future<bool> _checkInternetConnection() async {
    try {
      // التحقق من الاتصال الأساسي
      final results = await Connectivity().checkConnectivity();
      final result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;

      // إذا لم يكن هناك اتصال أساسي، نرجع false مباشرة
      if (result == ConnectivityResult.none) {
        return false;
      }

      // محاولة بسيطة للاتصال بخادم موثوق
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

  /// بدء مراقبة الاتصال بالإنترنت بشكل مستمر
  void startInternetMonitoring() {
    Connectivity().onConnectivityChanged.listen((results) {
      final result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;
      final hasInternet = result != ConnectivityResult.none;

      if (!_hasInternet && hasInternet && mounted) {
        // إذا عاد الاتصال بعد فقدانه، نعرض رسالة
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم استعادة الاتصال بالإنترنت'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      _hasInternet = hasInternet;
    });
  }

  /// تنفيذ عملية الحفظ مع BLoC
  Future<void> performBlocSaveOperation({
    required VoidCallback triggerSave,
    required String successMessage,
    required String loadingMessage,
    VoidCallback? onSuccess,
    Function(String)? onError,
    bool navigateBackOnSuccess = true,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // التحقق من الاتصال بالإنترنت
    final isConnected = await _checkInternetConnection();
    if (!isConnected) {
      // عرض رسالة عدم الاتصال
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لا يوجد اتصال بالإنترنت. يرجى التحقق من الاتصال والمحاولة مرة أخرى.',
            ),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // الاتصال متوفر، تنفيذ العملية مباشرة
    await _executeSaveOperation(
      triggerSave,
      successMessage,
      loadingMessage,
      onSuccess,
      onError,
      navigateBackOnSuccess,
      timeout,
    );
  }

  /// تنفيذ عملية الحفظ فعليًا
  Future<void> _executeSaveOperation(
    VoidCallback triggerSave,
    String successMessage,
    String loadingMessage,
    VoidCallback? onSuccess,
    Function(String)? onError,
    bool navigateBackOnSuccess,
    Duration timeout,
  ) async {
    // منع التنفيذ المتعدد
    if (_isSaving) {
      return;
    }

    // زيادة رقم العملية للتحقق من التعددية
    final operationId = ++_saveOperationId;

    if (mounted) {
      setState(() {
        _isSaving = true;
      });
    }

    // عرض نافذة التحميل (غير قابلة للإغلاق)
    if (mounted) {
      LoadingWidget.showLoadingDialog(
        context,
        message: loadingMessage,
        subtitle: 'الرجاء الانتظار ولا تغلق هذه النافذة...',
        icon: Icons.save,
      );
    }

    try {
      // التحقق من أن هذه هي العملية الأحدث قبل التنفيذ
      if (operationId != _saveOperationId) {
        if (mounted) {
          try {
            Navigator.of(context).pop();
          } on Exception catch (_) {}
        }
        return;
      }

      // تنفيذ عملية الحفظ
      triggerSave();

      // نحن نعتمد على BlocListener في الصفحة لاستقبال الحالة
      // نستخدم Timer لإغلاق نافذة التحميل إذا لم يتم استقبال الحالة في غضون الوقت المحدد
      Timer(timeout, () {
        // نستخدم SchedulerBinding لضمان استخدام BuildContext بشكل آمن
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // التحقق من أن هذه هي العملية الأحدث
          if (operationId != _saveOperationId) {
            return;
          }

          if (mounted && isSaving) {
            // إغلاق نافذة التحميل
            try {
              Navigator.of(context).pop();
            } on Exception catch (_) {
              // في حالة عدم وجود نافذة للإغلاق
            }

            // إذا كانت العملية لا تزال جارية بعد انتهاء الوقت، نعرض رسالة خطأ
            if (mounted) {
              setState(() {
                _isSaving = false;
              });
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'انتهى وقت الانتظار، يرجى التحقق من الاتصال بالإنترنت',
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
            if (onError != null) {
              onError('انتهى وقت الانتظار، يرجى التحقق من الاتصال بالإنترنت');
            }
          }
        });
      });
    } on Exception catch (_) {
      // التحقق من أن هذه هي العملية الأحدث
      if (operationId != _saveOperationId) {
        return;
      }

      // إغلاق نافذة التحميل
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } on Exception catch (_) {
          // في حالة عدم وجود نافذة للإغلاق
        }
      }

      // عرض رسالة الخطأ
      final errorMessage = 'حدث خطأ: يرجى المحاولة مرة أخرى';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      if (onError != null) {
        onError(errorMessage);
      }
    }
  }

  /// إنهاء عملية الحفظ بنجاح (للاستخدام في BLoC listener)
  void completeSaveOperation({
    required String successMessage,
    VoidCallback? onSuccess,
    bool navigateBackOnSuccess = false,
  }) {
    if (!mounted) {
      return;
    }

    // إغلاق نافذة التحميل أولاً
    try {
      Navigator.of(context).pop();
    } on Exception catch (_) {
      // في حالة عدم وجود نافذة للإغلاق
    }

    // عرض رسالة النجاح
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(successMessage),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    // تحديث حالة الحفظ قبل أي تنقل كي لا يحدث setState بعد التخلص من الصفحة.
    setState(() {
      _isSaving = false;
    });

    if (onSuccess != null) {
      onSuccess();
    } else if (navigateBackOnSuccess && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  /// إنهاء عملية الحفظ بخطأ (للاستخدام في BLoC listener)
  void failSaveOperation({
    required String errorMessage,
    Function(String)? onError,
  }) {
    if (!mounted) return;

    // إغلاق نافذة التحميل أولاً
    try {
      Navigator.of(context).pop();
    } on Exception catch (_) {
      // في حالة عدم وجود نافذة للإغلاق
    }

    // عرض رسالة الخطأ
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    if (onError != null) {
      onError(errorMessage);
    }

    setState(() {
      _isSaving = false;
    });
  }
}
