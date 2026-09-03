import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  const User._();

  const factory User({
    required String id,
    String? name,
    required String email,
    String? phone,
    String? image,
    @Default('USER') String role,
    @Default(false) bool isBlocked,
    String? blockReason,
    String? assignedRestaurantId,
    DateTime? createdAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      image: json['image']?.toString(),
      role: json['role']?.toString() ?? 'USER',
      isBlocked: json['isBlocked'] == true,
      blockReason: json['blockReason']?.toString(),
      assignedRestaurantId: json['assignedRestaurantId']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'image': image,
        'role': role,
        'isBlocked': isBlocked,
        'blockReason': blockReason,
        'assignedRestaurantId': assignedRestaurantId,
        'createdAt': createdAt?.toIso8601String(),
      };

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