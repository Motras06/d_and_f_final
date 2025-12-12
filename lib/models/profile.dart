class Profile {
  final String id;          // uuid из auth.users
  final String mail;        // email пользователя
  final String? username;   // может быть null
  final String role;        // 'supplier', 'hall', 'storage', 'admin' и т.д.
  final DateTime createdAt;

  Profile({
    required this.id,
    required this.mail,
    this.username,
    required this.role,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      mail: json['mail'] as String,
      username: json['username'] as String?,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mail': mail,
      'username': username,
      'role': role,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Profile(id: $id, mail: $mail, username: $username, role: $role)';
  }
}