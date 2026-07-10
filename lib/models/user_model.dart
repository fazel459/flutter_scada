import 'enums.dart';

class User {
  final String id;
  final String username;
  final String email;
  final UserRole role;
  final String? displayName;
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.displayName,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'role': role.name,
        'displayName': displayName,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        username: json['username'],
        email: json['email'],
        role: UserRole.values.firstWhere(
          (e) => e.name == json['role'],
          orElse: () => UserRole.viewer,
        ),
        displayName: json['displayName'],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : null,
      );
}

class AuthResponse {
  final String token;
  final User user;

  const AuthResponse({required this.token, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        token: json['token'],
        user: User.fromJson(json['user']),
      );
}
