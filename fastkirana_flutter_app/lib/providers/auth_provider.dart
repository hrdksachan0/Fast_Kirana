import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? image;
  final String role;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.image,
    this.role = 'USER',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      image: json['image'],
      role: json['role'] ?? 'USER',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'image': image,
    'role': role,
  };

  bool get isAdmin => role == 'ADMIN';
  bool get isDelivery => role == 'DELIVERY';
  bool get isPicker => role == 'PICKER';
  bool get isChef => role == 'CHEF';
  bool get isRestaurantOwner => role == 'RESTAURANT_OWNER';
}

class AuthProvider with ChangeNotifier {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthProvider() {
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final userJson = prefs.getString(_userKey);
      if (token != null && userJson != null) {
        _token = token;
        _user = User.fromJson(Map.from(jsonMapFromString(userJson)));
      }
      notifyListeners();
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Call your auth API endpoint
      // For now, this is a placeholder
      await Future.delayed(const Duration(seconds: 1));
      _error = 'API endpoint needed';
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _user = null;
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    notifyListeners();
  }

  Future<void> updateUser(User user) async {
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, user.toJson().toString());
    notifyListeners();
  }
}

Map<String, dynamic> jsonMapFromString(String str) {
  // Simple parser for stored user data
  final result = <String, dynamic>{};
  final content = str.replaceAll('{', '').replaceAll('}', '').split(', ');
  for (final entry in content) {
    final parts = entry.split(': ');
    if (parts.length == 2) {
      final key = parts[0].replaceAll("'", "");
      var value = parts[1].replaceAll("'", "");
      result[key] = value;
    }
  }
  return result;
}
