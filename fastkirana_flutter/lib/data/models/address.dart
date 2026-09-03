import 'package:freezed_annotation/freezed_annotation.dart';

part 'address.freezed.dart';

@freezed
class Address with _$Address {
  const Address._();

  const factory Address({
    required String id,
    @Default('') String userId,
    required String label,
    @Default('') String houseNo,
    @Default('') String street,
    @Default('') String area,
    @Default('') String city,
    required String pincode,
    @Default('') String phone,
    double? latitude,
    double? longitude,
    @Default(false) bool isDefault,
  }) = _Address;

  factory Address.fromJson(Map<String, dynamic> json) {
    final rawLat = json['latitude'] ?? json['lat'];
    final rawLng = json['longitude'] ?? json['lng'];

    return Address(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Home',
      houseNo: json['houseNo']?.toString() ?? '',
      street: json['street']?.toString() ?? '',
      area: json['area']?.toString() ?? '',
      city: json['city']?.toString() ?? 'Ghatampur',
      pincode: json['pincode']?.toString() ?? '209206',
      phone: json['phone']?.toString() ?? '',
      latitude: rawLat != null ? double.tryParse(rawLat.toString()) : null,
      longitude: rawLng != null ? double.tryParse(rawLng.toString()) : null,
      isDefault: json['isDefault'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'label': label,
        'houseNo': houseNo,
        'street': street,
        'area': area,
        'city': city,
        'pincode': pincode,
        'phone': phone,
        'latitude': latitude,
        'longitude': longitude,
        'lat': latitude,
        'lng': longitude,
        'isDefault': isDefault,
      };

  String get fullAddress {
    final parts = [houseNo, street, area, city]
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty && p != '.' && p.toLowerCase() != 'n/a')
        .toList();
    final main = parts.join(', ');
    final cleanPin = pincode.trim();
    if (cleanPin.isNotEmpty && cleanPin != '.') {
      return main.isNotEmpty ? '$main - $cleanPin' : cleanPin;
    }
    return main.isNotEmpty ? main : 'Ghatampur Zone';
  }

  String get displayArea {
    final a = area.trim();
    if (a.isNotEmpty && a != '.' && a.toLowerCase() != 'n/a') return a;
    final s = street.trim();
    if (s.isNotEmpty && s != '.' && s.toLowerCase() != 'n/a') return s;
    final c = city.trim();
    if (c.isNotEmpty && c != '.' && c.toLowerCase() != 'n/a') return c;
    return 'Ghatampur Zone';
  }

  String get displayLabel {
    final l = label.trim().replaceAll('📍', '').trim();
    if (l.isNotEmpty && l != '.' && l.toLowerCase() != 'n/a' && !l.toLowerCase().contains('current location')) {
      return l;
    }
    return 'Home';
  }

  String get shortAddress {
    final candidate = area.trim().isNotEmpty && area != '.' && area.toLowerCase() != 'n/a'
        ? area.trim()
        : (street.trim().isNotEmpty && street != '.' && street.toLowerCase() != 'n/a'
            ? street.trim()
            : (houseNo.trim().isNotEmpty && houseNo != '.' && houseNo.toLowerCase() != 'n/a'
                ? houseNo.trim()
                : city.trim()));
    if (candidate.isEmpty || candidate == '.' || candidate.toLowerCase() == 'n/a') {
      return 'Ghatampur';
    }
    final clean = candidate.replaceAll(RegExp(r'^[,\s.-]+|[,\s.-]+$'), '');
    final commaSplit = clean.split(',');
    if (commaSplit.isNotEmpty && commaSplit.first.trim().isNotEmpty) {
      final firstPart = commaSplit.first.trim();
      final words = firstPart.split(RegExp(r'\s+'));
      if (words.length > 2) {
        return '${words[0]} ${words[1]}';
      }
      return firstPart;
    }
    return clean;
  }
}