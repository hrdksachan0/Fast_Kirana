import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/address.dart';
import '../../core/network/api_client.dart';

class AddressRepository {
  final Dio dio;
  static const String _cacheKey = 'user_saved_addresses_cache';

  AddressRepository(this.dio);

  static Address get defaultGhatampurAddress => Address(
    id: 'addr_default_ghatampur',
    userId: 'default_user',
    label: 'Home',
    houseNo: 'Main Market',
    street: 'Station Road',
    area: 'Ghatampur Express Zone',
    city: 'Ghatampur, Kanpur Nagar',
    pincode: '209206',
    phone: '7054470303',
    latitude: 26.1534185,
    longitude: 80.1714024,
    isDefault: true,
  );

  Future<List<Address>> getAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    List<Address> localAddresses = [];

    final rawJson = prefs.getString(_cacheKey);
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
        localAddresses = decoded.map((j) => Address.fromJson(j as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    try {
      final response = await dio.get('/api/addresses');
      if (response.data is List) {
        final List<dynamic> data = response.data as List<dynamic>;
        final apiAddresses = data.map((json) => Address.fromJson(json as Map<String, dynamic>)).toList();
        if (apiAddresses.isNotEmpty) {
          await _saveToCache(apiAddresses);
          return apiAddresses;
        }
      }
    } catch (_) {}

    return localAddresses;
  }

  Future<Address> createAddress(Map<String, dynamic> data) async {
    final newId = 'addr_${DateTime.now().millisecondsSinceEpoch}';
    final newAddress = Address(
      id: data['id']?.toString() ?? newId,
      userId: data['userId']?.toString() ?? '',
      label: data['label']?.toString() ?? 'Home',
      houseNo: data['houseNo']?.toString() ?? '',
      street: data['street']?.toString() ?? '',
      area: data['area']?.toString() ?? '',
      city: data['city']?.toString() ?? 'Ghatampur',
      pincode: data['pincode']?.toString() ?? '209206',
      phone: data['phone']?.toString() ?? '',
      latitude: data['lat'] != null ? double.tryParse(data['lat'].toString()) : 26.1534,
      longitude: data['lng'] != null ? double.tryParse(data['lng'].toString()) : 80.1714,
      isDefault: data['isDefault'] == true,
    );

    final current = await getAddresses();
    final updated = [
      if (newAddress.isDefault)
        ...current.map((a) => Address(
              id: a.id,
              userId: a.userId,
              label: a.label,
              houseNo: a.houseNo,
              street: a.street,
              area: a.area,
              city: a.city,
              pincode: a.pincode,
              phone: a.phone,
              latitude: a.latitude,
              longitude: a.longitude,
              isDefault: false,
            ))
      else
        ...current,
      newAddress,
    ];
    await _saveToCache(updated);

    try {
      final response = await dio.post('/api/addresses', data: data);
      if (response.data is Map<String, dynamic>) {
        return Address.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}

    return newAddress;
  }

  Future<Address> updateAddress(Map<String, dynamic> data) async {
    final id = data['id']?.toString() ?? '';
    final current = await getAddresses();
    final updated = current.map((a) {
      if (a.id == id) {
        return Address(
          id: a.id,
          userId: a.userId,
          label: data['label']?.toString() ?? a.label,
          houseNo: data['houseNo']?.toString() ?? a.houseNo,
          street: data['street']?.toString() ?? a.street,
          area: data['area']?.toString() ?? a.area,
          city: data['city']?.toString() ?? a.city,
          pincode: data['pincode']?.toString() ?? a.pincode,
          phone: data['phone']?.toString() ?? a.phone,
          latitude: data['lat'] != null ? double.tryParse(data['lat'].toString()) : a.latitude,
          longitude: data['lng'] != null ? double.tryParse(data['lng'].toString()) : a.longitude,
          isDefault: data['isDefault'] == true,
        );
      }
      return a;
    }).toList();
    await _saveToCache(updated);

    try {
      final response = await dio.put('/api/addresses', data: data);
      if (response.data is Map<String, dynamic>) {
        return Address.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}

    return updated.firstWhere((a) => a.id == id, orElse: () => defaultGhatampurAddress);
  }

  Future<void> deleteAddress(String id) async {
    final current = await getAddresses();
    final updated = current.where((a) => a.id != id).toList();
    if (updated.isEmpty) {
      updated.add(defaultGhatampurAddress);
    }
    await _saveToCache(updated);

    try {
      await dio.delete('/api/addresses', data: {'id': id});
    } catch (_) {}
  }

  Future<void> updateCoordinates(String id, double lat, double lng) async {
    final current = await getAddresses();
    final updated = current.map((a) {
      if (a.id == id) {
        return Address(
          id: a.id,
          userId: a.userId,
          label: a.label,
          houseNo: a.houseNo,
          street: a.street,
          area: a.area,
          city: a.city,
          pincode: a.pincode,
          phone: a.phone,
          latitude: lat,
          longitude: lng,
          isDefault: a.isDefault,
        );
      }
      return a;
    }).toList();
    await _saveToCache(updated);

    try {
      await dio.patch('/api/addresses', data: {
        'id': id,
        'lat': lat,
        'lng': lng,
      });
    } catch (_) {}
  }

  Future<void> _saveToCache(List<Address> addresses) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = addresses.map((a) => a.toJson()).toList();
    await prefs.setString(_cacheKey, jsonEncode(jsonList));
  }
}