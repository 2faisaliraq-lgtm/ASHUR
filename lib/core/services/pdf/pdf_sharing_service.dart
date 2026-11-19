import 'dart:io';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// خدمة مشاركة وطباعة ملفات PDF
class PdfSharingService {
  /// مشاركة ملف PDF عبر التطبيقات المتاحة
  Future<void> sharePdf({
    required File pdfFile,
    String? subject,
    String? message,
  }) async {
    try {
      final xFile = XFile(pdfFile.path);
      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          subject: subject ?? 'فاتورة',
          text: message,
        ),
      );
    } on Exception {
      rethrow;
    }
  }

  /// طباعة ملف PDF (مشاركة مع خيار الطباعة)
  Future<void> printPdf({
    required File pdfFile,
    String? subject,
  }) async {
    try {
      final xFile = XFile(pdfFile.path);
      await SharePlus.instance.share(
        ShareParams(files: [xFile], subject: subject ?? 'طباعة'),
      );
    } on Exception {
      rethrow;
    }
  }

  /// نسخ ملف PDF إلى موقع آخر
  Future<File> copyPdf({
    required File sourceFile,
    required String destinationPath,
  }) async {
    try {
      final destinationFile = await sourceFile.copy(destinationPath);
      return destinationFile;
    } on Exception {
      rethrow;
    }
  }

  /// حذف ملف PDF
  Future<void> deletePdf({required File pdfFile}) async {
    try {
      await pdfFile.delete();
    } on Exception {
      rethrow;
    }
  }

  /// الحصول على حجم الملف بوحدة مناسبة
  String getFileSize(File pdfFile) {
    try {
      final bytes = pdfFile.lengthSync();
      if (bytes < 1024) {
        return '$bytes بايت';
      } else if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(2)} كيلوبايت';
      } else {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} ميجابايت';
      }
    } on Exception {
      return 'غير معروف';
    }
  }
}
