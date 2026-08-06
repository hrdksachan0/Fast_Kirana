import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  final String id;
  final String? name;
  final String email;
  final String? phone;
  final String? image;
  final String role;
  final bool isBlocked;
  final String? blockReason;
  final DateTime? createdAt;

  User({
    required this.id,
    this.name,
    required this.email,
    this.phone,
    this.image,
    required this.role,
    required this.isBlocked,
    this.blockReason,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  bool get isWorker => role != 'USER';
  bool get isAdmin => role == 'ADMIN';
}

@JsonSerializable()
class AuthResponse {
  final bool success;
  final User? user;
  final String? token;

  AuthResponse({required this.success, this.user, this.token});

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
}