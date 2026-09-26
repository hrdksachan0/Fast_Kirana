/// Strongly typed user session data used for fast in-memory authorization headers
/// and cross-layer user identity propagation.
class UserSession {
  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final String role;

  const UserSession({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.role = 'USER',
  });

  bool get isValid => id.isNotEmpty;
  bool get isWorker => role != 'USER';
  bool get isAdmin => role == 'ADMIN';

  /// Generates the standard FastKirana x-user headers map
  Map<String, String> toHeaderMap() {
    final headers = <String, String>{};
    if (id.isNotEmpty) headers['x-user-id'] = id;
    if (phone != null && phone!.isNotEmpty) headers['x-user-phone'] = phone!;
    if (email != null && email!.isNotEmpty) headers['x-user-email'] = email!;
    if (name != null && name!.isNotEmpty) headers['x-user-name'] = name!;
    if (role.isNotEmpty) headers['x-user-role'] = role;
    return headers;
  }

  factory UserSession.fromMap(Map<String, dynamic> map) {
    return UserSession(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString(),
      email: map['email']?.toString(),
      phone: map['phone']?.toString(),
      role: map['role']?.toString() ?? 'USER',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'role': role,
  };
}
