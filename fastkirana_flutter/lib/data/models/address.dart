import 'package:json_annotation/json_annotation.dart';

part 'address.g.dart';

@JsonSerializable()
class Address {
  final String id;
  final String userId;
  final String label;
  final String houseNo;
  final String street;
  final String area;
  final String city;
  final String pincode;
  final String phone;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  Address({
    required this.id,
    this.userId = '',
    required this.label,
    this.houseNo = '',
    this.street = '',
    this.area = '',
    this.city = '',
    required this.pincode,
    this.phone = '',
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  factory Address.fromJson(Map<String, dynamic> json) =>
      _$AddressFromJson(json);
  Map<String, dynamic> toJson() => _$AddressToJson(this);

  String get fullAddress =>
      '$houseNo, $street, $area, $city - $pincode';
}