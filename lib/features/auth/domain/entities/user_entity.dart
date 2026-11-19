class UserEntity {

  const UserEntity({
    required this.id,
    required this.email,
    required this.createdAt, this.name,
    this.phoneNumber,
    this.photoUrl,
    this.provider,
    this.lastLoginAt,
  });
  final String id;
  final String email;
  final String? name;
  final String? phoneNumber;
  final String? photoUrl;
  final String? provider;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
}
