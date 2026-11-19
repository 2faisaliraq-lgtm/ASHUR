import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Shared date parsing utility to eliminate duplication across models
class DateParser {
  /// Parse a dynamic value into a DateTime
  /// Returns [DateTime.now()] with a warning if the value is null or invalid
  static DateTime parse(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }

    if (value is DateTime) return value;

    if (value is Timestamp) return value.toDate();

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return DateTime.now();
      }

      try {
        return DateTime.parse(trimmed);
      } on FormatException catch (_) {
        return DateTime.now();
      }
    }

    if (value is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } on Exception catch (_) {
        return DateTime.now();
      }
    }

    return DateTime.now();
  }

  /// Convert DateTime to Firestore Timestamp
  static dynamic toTimestamp(DateTime? dateTime) {
    if (dateTime == null) return null;
    return Timestamp.fromDate(dateTime);
  }
}
