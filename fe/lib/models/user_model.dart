class UserModel {
  final int id;

  /// Optional and not unique — how to reach this researcher, not how to
  /// identify them. Nullable because most accounts will not have one.
  final String? phone;
  final String name;
  final String email;
  final String role; // 'admin' or 'user'
  final bool isActive;

  /// True while the account is still on the password an administrator issued.
  /// The app blocks the console behind a password change until it clears.
  final bool mustChangePassword;

  /// Path of the profile photo relative to the API root, e.g.
  /// `/users/3/avatar`. **Null means there is no photo**, which is what tells
  /// the UI to draw an initials frame rather than a broken image.
  final String? avatarPath;

  final DateTime? lastLoginAt;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    this.phone,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    this.mustChangePassword = false,
    this.avatarPath,
    this.lastLoginAt,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      phone: json['phone']?.toString(),
      name: json['name'],
      email: json['email'],
      role: json['role'],
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      mustChangePassword: json['must_change_password'] == true,
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
      'phone': phone,
      'name': name,
      'email': email,
      'role': role,
      'is_active': isActive,
      'must_change_password': mustChangePassword,
      'avatar_url': avatarPath,
      'last_login_at': lastLoginAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  bool get hasAvatar => avatarPath != null;

  /// Copy with a new photo path, so a fresh upload shows immediately without
  /// another round trip to `/user`.
  UserModel withAvatarPath(String? path) =>
      _copyWith(avatarPath: path, avatarPathGiven: true);

  /// Copy with the forced-change flag cleared, so the gate lets the console
  /// through the moment the new password is accepted.
  UserModel withPasswordChanged() => _copyWith(mustChangePassword: false);

  UserModel _copyWith({
    bool? mustChangePassword,
    String? avatarPath,
    bool avatarPathGiven = false,
  }) => UserModel(
    id: id,
    phone: phone,
    name: name,
    email: email,
    role: role,
    isActive: isActive,
    mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    avatarPath: avatarPathGiven ? avatarPath : this.avatarPath,
    lastLoginAt: lastLoginAt,
    createdAt: createdAt,
  );

  bool get isAdmin => role == 'admin';
  bool get isUser => role == 'user';
}
