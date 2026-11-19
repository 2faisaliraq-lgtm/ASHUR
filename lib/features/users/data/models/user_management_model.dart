import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/role_entity.dart';
import '../../domain/entities/user_management_entity.dart';
import 'role_model.dart';

/// نموذج إدارة المستخدم - يحول البيانات من وإلى Firestore
class UserManagementModel extends UserManagementEntity {
  const UserManagementModel({
    required super.id,
    required super.createdAt,
    super.email, // إزالة required
    super.name,
    super.phoneNumber,
    super.photoUrl,
    super.department,
    super.jobTitle,
    super.roles,
    super.roleIds, // إضافة معرفات الأدوار
    super.roleCode, // رمز الوصول للدور
    super.customPermissions, // الصلاحيات المخصصة
    super.isActive,
    super.isEmailVerified,
    super.notificationEnabled,
    super.updatedAt,
    super.lastLoginAt,
    super.createdBy,
    super.updatedBy,
  });

  /// إنشاء نموذج من كيان
  factory UserManagementModel.fromEntity(UserManagementEntity entity) {
    return UserManagementModel(
      id: entity.id,
      email: entity.email,
      name: entity.name,
      phoneNumber: entity.phoneNumber,
      photoUrl: entity.photoUrl,
      department: entity.department,
      jobTitle: entity.jobTitle,
      roles: entity.roles,
      roleIds: entity.roleIds, // إضافة معرفات الأدوار
      roleCode: entity.roleCode, // رمز الوصول للدور
      customPermissions: entity.customPermissions, // الصلاحيات المخصصة
      isActive: entity.isActive,
      isEmailVerified: entity.isEmailVerified,
      notificationEnabled: entity.notificationEnabled,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      lastLoginAt: entity.lastLoginAt,
      createdBy: entity.createdBy,
      updatedBy: entity.updatedBy,
    );
  }

  /// إنشاء نموذج من JSON
  factory UserManagementModel.fromJson(Map<String, dynamic> json) {
    final roleIds = List<String>.from(json['roleIds'] ?? []);
    // دعم الاسم القديم additionalPermissions للتوافق مع البيانات القديمة
    final customPermissions = List<String>.from(
      json['customPermissions'] ?? json['additionalPermissions'] ?? [],
    );

    return UserManagementModel(
      id: json['id'] as String,
      email: json['email'] as String?, // يمكن أن يكون null
      name: json['name'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      photoUrl: json['photoUrl'] as String?,
      department: json['department'] as String?,
      jobTitle: json['jobTitle'] as String?,
      roles:
          (json['roles'] as List<dynamic>?)
              ?.map(
                (roleData) =>
                    RoleModel.fromJson(roleData as Map<String, dynamic>),
              )
              .cast<RoleEntity>()
              .toList() ??
          [],
      roleIds: roleIds, // إضافة معرفات الأدوار
      roleCode:
          json['accessCode'] as String? ??
          json['roleCode'] as String?, // قراءة رمز الوصول (مع دعم الاسم القديم)
      customPermissions: customPermissions, // الصلاحيات المخصصة
      isActive: json['isActive'] as bool? ?? true,
      isEmailVerified: json['isEmailVerified'] as bool? ?? false,
      notificationEnabled: json['notificationEnabled'] as bool? ?? true,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] is Timestamp
                ? (json['updatedAt'] as Timestamp).toDate()
                : DateTime.parse(json['updatedAt'] as String))
          : null,
      lastLoginAt: json['lastLoginAt'] != null
          ? (json['lastLoginAt'] is Timestamp
                ? (json['lastLoginAt'] as Timestamp).toDate()
                : DateTime.parse(json['lastLoginAt'] as String))
          : null,
      createdBy: json['createdBy'] as String?,
      updatedBy: json['updatedBy'] as String?,
    );
  }

  /// إنشاء نموذج من Firestore DocumentSnapshot
  factory UserManagementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data();
    if (data == null) throw Exception('المستند فارغ');
    return UserManagementModel.fromJson({'id': doc.id, ...data as Map<String, dynamic>});
  }

  /// تحويل النموذج إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'department': department,
      'jobTitle': jobTitle,
      'roles': roles.map((role) => (role as RoleModel).toJson()).toList(),
      'roleIds': roleIds, // استخدام roleIds الفعلي بدلاً من استخراجه من roles
      'accessCode': roleCode, // رمز الوصول للدور
      'customPermissions': customPermissions, // الصلاحيات المخصصة
      'isActive': isActive,
      'isEmailVerified': isEmailVerified,
      'notificationEnabled': notificationEnabled,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'lastLoginAt': lastLoginAt != null
          ? Timestamp.fromDate(lastLoginAt!)
          : null,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };
  }

  /// إنشاء نسخة محدثة من النموذج
  @override
  UserManagementModel copyWith({
    String? id,
    String? email,
    String? name,
    String? phoneNumber,
    String? photoUrl,
    String? department,
    String? jobTitle,
    List<RoleEntity>? roles,
    List<String>? roleIds,
    String? roleCode,
    List<String>? customPermissions,
    bool? isActive,
    bool? isEmailVerified,
    bool? notificationEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return UserManagementModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      department: department ?? this.department,
      jobTitle: jobTitle ?? this.jobTitle,
      roles: roles ?? this.roles,
      roleIds: roleIds ?? this.roleIds,
      roleCode: roleCode ?? this.roleCode,
      customPermissions: customPermissions ?? this.customPermissions,
      isActive: isActive ?? this.isActive,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  /// تحويل النموذج إلى كيان
  UserManagementEntity toEntity() {
    return UserManagementEntity(
      id: id,
      email: email,
      name: name,
      phoneNumber: phoneNumber,
      photoUrl: photoUrl,
      department: department,
      jobTitle: jobTitle,
      roles: roles,
      roleIds: roleIds, // إضافة معرفات الأدوار
      roleCode: roleCode, // رمز الوصول للدور
      customPermissions: customPermissions, // الصلاحيات المخصصة
      isActive: isActive,
      isEmailVerified: isEmailVerified,
      notificationEnabled: notificationEnabled,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastLoginAt: lastLoginAt,
      createdBy: createdBy,
      updatedBy: updatedBy,
    );
  }
}
