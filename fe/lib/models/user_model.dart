class UserModel {
  final int id;
  final String username;
  final String name;
  final String email;
  final String role; // 'admin' or 'user'
  final bool isActive;

  /// Path of the profile photo relative to the API root, e.g.
  /// `/users/3/avatar`. **Null means there is no photo**, which is what tells
  /// the UI to draw an initials frame rather than a broken image.
  final String? avatarPath;

  final DateTime? lastLoginAt;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    this.avatarPath,
    this.lastLoginAt,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      name: json['name'],
      email: json['email'],
      role: json['role'],
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      avatarPath: json['avatar_url']?.toString(),
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'email': email,
      'role': role,
      'is_active': isActive,
      'avatar_url': avatarPath,
      'last_login_at': lastLoginAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  bool get hasAvatar => avatarPath != null;

  /// Copy with a new photo path, so a fresh upload shows immediately without
  /// another round trip to `/user`.
  UserModel withAvatarPath(String? path) => UserModel(
    id: id,
    username: username,
    name: name,
    email: email,
    role: role,
    isActive: isActive,
    avatarPath: path,
    lastLoginAt: lastLoginAt,
    createdAt: createdAt,
  );

  bool get isAdmin => role == 'admin';
  bool get isUser => role == 'user';
}
