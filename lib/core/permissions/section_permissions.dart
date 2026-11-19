import '../../features/users/domain/entities/permission_entity.dart';

/// واجهة أساسية لتعريف صلاحيات كل قسم
abstract class SectionPermissions {
  /// اسم القسم
  String get sectionName;

  /// اسم القسم بالعربية
  String get sectionDisplayName;

  /// أيقونة القسم
  String get sectionIcon;

  /// قائمة صلاحيات القسم
  List<PermissionEntity> getPermissions();
}
