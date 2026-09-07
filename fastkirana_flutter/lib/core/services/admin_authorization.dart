import 'package:dio/dio.dart';
import '../network/api_client.dart';
import '../services/secure_storage_service.dart';

/// Centralized admin/role authorization helper.
///
/// IMPORTANT: All admin or staff actions must be authenticated through
/// the API using the user's actual JWT token. Do NOT hardcode admin
/// credentials in client code. This helper exposes the headers that
/// should be sent on role-gated requests, derived from the logged-in
/// user (no hardcoded phone numbers or roles).
///
/// If the current user lacks the required role, the action must NOT
/// be attempted — the server will reject it anyway, and the client
/// must never impersonate admins via header forgery.
class AdminAuthorization {
  AdminAuthorization._();

  /// Valid roles for staff dashboards.
  static const Set<String> staffRoles = {
    'ADMIN',
    'RIDER',
    'DELIVERY',
    'DELIVERY_PARTNER',
    'PICKER',
    'CHEF',
    'RESTAURANT_OWNER',
    'RESTAURANT',
  };

  /// Returns true if the current user holds a staff/admin role.
  static bool isStaff({
    required String? userRole,
    required String? userId,
  }) {
    if (userId == null || userId.isEmpty) return false;
    final role = (userRole ?? '').toUpperCase();
    return staffRoles.contains(role);
  }

  /// Returns true if the current user is an admin.
  static bool isAdmin({required String? userRole, required String? userId}) {
    if (userId == null || userId.isEmpty) return false;
    return (userRole ?? '').toUpperCase() == 'ADMIN';
  }

  /// Builds role-headers for a staff action based on the currently
  /// authenticated user. These headers identify the user making the
  /// request — they do NOT grant admin privileges.
  ///
  /// Returns null if there is no authenticated user, signalling that
  /// the caller should NOT proceed with the staff-only operation.
  static Map<String, String>? buildStaffHeaders({
    required String? userRole,
    required String? userId,
    String? userPhone,
    String? userEmail,
    String? userName,
  }) {
    if (userId == null || userId.isEmpty) return null;

    final headers = <String, String>{
      'x-user-id': userId,
      if (userRole != null && userRole.isNotEmpty) 'x-user-role': userRole,
      if (userPhone != null && userPhone.isNotEmpty)
        'x-user-phone': userPhone,
      if (userEmail != null && userEmail.isNotEmpty)
        'x-user-email': userEmail,
      if (userName != null && userName.isNotEmpty)
        'x-user-name': userName,
    };
    return headers;
  }

  /// Reads the currently authenticated user's identity from the
  /// in-memory cache and returns headers suitable for a staff action.
  ///
  /// Returns null when no user is logged in.
  static Map<String, String>? currentStaffHeaders() {
    final userId = SecureStorage.cachedUserId;
    if (userId == null || userId.isEmpty) return null;

    return buildStaffHeaders(
      userId: userId,
      userRole: SecureStorage.cachedUserRole,
      userPhone: SecureStorage.cachedUserPhone,
      userEmail: SecureStorage.cachedUserEmail,
      userName: SecureStorage.cachedUserName,
    );
  }

  /// Wraps a Dio request options with staff headers from the current
  /// session. If no user is logged in, returns the options unchanged
  /// (the server will reject the request).
  static Options withStaffAuth(Options? base) {
    final headers = currentStaffHeaders();
    if (headers == null) return base ?? Options();
    final merged = Map<String, String>.from(base?.headers ?? {});
    headers.forEach((k, v) => merged.putIfAbsent(k, () => v));
    return Options(
      headers: merged,
      method: base?.method,
      contentType: base?.contentType,
      responseType: base?.responseType,
      followRedirects: base?.followRedirects,
      receiveDataWhenStatusError: base?.receiveDataWhenStatusError,
    );
  }

  /// Convenience: get an authenticated Dio with staff headers.
  static Options options({Map<String, dynamic>? extra}) {
    final headers = currentStaffHeaders() ?? const <String, String>{};
    return Options(headers: headers, extra: extra);
  }
}
