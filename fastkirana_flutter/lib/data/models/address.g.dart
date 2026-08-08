// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'address.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Address _$AddressFromJson(Map<String, dynamic> json) => Address(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? '',
      label: json['label'] as String,
      houseNo: json['houseNo'] as String? ?? '',
      street: json['street'] as String? ?? '',
      area: json['area'] as String? ?? '',
      city: json['city'] as String? ?? '',
      pincode: json['pincode'] as String,
      phone: json['phone'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isDefault: json['isDefault'] as bool? ?? false,
    );

Map<String, dynamic> _$AddressToJson(Address instance) => <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'label': instance.label,
      'houseNo': instance.houseNo,
      'street': instance.street,
      'area': instance.area,
      'city': instance.city,
      'pincode': instance.pincode,
      'phone': instance.phone,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'isDefault': instance.isDefault,
    };
