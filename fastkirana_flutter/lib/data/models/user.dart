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
  final String? assignedRestaurantId;
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
    this.assignedRestaurantId,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    try {
      return _$UserFromJson(json);
    } catch (_) {
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
  }
  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? image,
    String? role,
    bool? isBlocked,
    String? blockReason,
    String? assignedRestaurantId,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      image: image ?? this.image,
      role: role ?? this.role,
      isBlocked: isBlocked ?? this.isBlocked,
      blockReason: blockReason ?? this.blockReason,
      assignedRestaurantId: assignedRestaurantId ?? this.assignedRestaurantId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

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