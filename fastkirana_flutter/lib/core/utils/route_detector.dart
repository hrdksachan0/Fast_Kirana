import 'package:flutter/material.dart';

enum DeliveryRouteKey {
  all,
  hamirpur,
  moosanagar,
  kanpur,
  jahanabad,
  townCenter,
}

class RouteInfo {
  final DeliveryRouteKey key;
  final String label;
  final String shortLabel;
  final String emoji;
  final Color primaryColor;
  final Color backgroundColor;
  final Color textColor;
  final String description;

  const RouteInfo({
    required this.key,
    required this.label,
    required this.shortLabel,
    required this.emoji,
    required this.primaryColor,
    required this.backgroundColor,
    required this.textColor,
    required this.description,
  });
}

class DeliveryRoutes {
  DeliveryRoutes._();

  static const RouteInfo hamirpur = RouteInfo(
    key: DeliveryRouteKey.hamirpur,
    label: 'Hamirpur Road',
    shortLabel: 'Hamirpur Rd',
    emoji: '🔴',
    primaryColor: Color(0xFFF43F5E),
    backgroundColor: Color(0xFFFFF1F2),
    textColor: Color(0xFFBE123C),
    description: 'Hamirpur Chauraha, Bus Stand, Mandi Samiti, Yamuna Pul, Patel Nagar',
  );

  static const RouteInfo moosanagar = RouteInfo(
    key: DeliveryRouteKey.moosanagar,
    label: 'Moosanagar Road',
    shortLabel: 'Moosanagar Rd',
    emoji: '🟣',
    primaryColor: Color(0xFF9333EA),
    backgroundColor: Color(0xFFFAF5FF),
    textColor: Color(0xFF6B21A8),
    description: 'Moosanagar Road, Mughal Road, CHC Hospital, Degree College, Block Office',
  );

  static const RouteInfo kanpur = RouteInfo(
    key: DeliveryRouteKey.kanpur,
    label: 'Kanpur Road',
    shortLabel: 'Kanpur Rd',
    emoji: '🔵',
    primaryColor: Color(0xFF2563EB),
    backgroundColor: Color(0xFFEFF6FF),
    textColor: Color(0xFF1D4ED8),
    description: 'Kanpur Road, Railway Station, Crossing, Shahi Gate, Subhash Nagar, NH-34',
  );

  static const RouteInfo jahanabad = RouteInfo(
    key: DeliveryRouteKey.jahanabad,
    label: 'Jahanabad Road',
    shortLabel: 'Jahanabad Rd',
    emoji: '🟢',
    primaryColor: Color(0xFF059669),
    backgroundColor: Color(0xFFECFDF5),
    textColor: Color(0xFF047857),
    description: 'Jahanabad Tiraha, Kotwali, Thana Road, Sabzi Mandi, Purana Bazar',
  );

  static const RouteInfo townCenter = RouteInfo(
    key: DeliveryRouteKey.townCenter,
    label: 'Town Center',
    shortLabel: 'Town Center',
    emoji: '🟡',
    primaryColor: Color(0xFFD97706),
    backgroundColor: Color(0xFFFFFBEB),
    textColor: Color(0xFFB45309),
    description: 'Chauraha Chowk, Sadar Bazar, Main Town, Central Hub',
  );

  static RouteInfo getByKey(DeliveryRouteKey key) {
    switch (key) {
      case DeliveryRouteKey.hamirpur:
        return hamirpur;
      case DeliveryRouteKey.moosanagar:
        return moosanagar;
      case DeliveryRouteKey.kanpur:
        return kanpur;
      case DeliveryRouteKey.jahanabad:
        return jahanabad;
      case DeliveryRouteKey.townCenter:
      case DeliveryRouteKey.all:
        return townCenter;
    }
  }

  static const List<String> _hamirpurKeywords = [
    'hamirpur', 'hamir pur', 'bus stand', 'mandi', 'mandi samiti', 'yamuna', 'pul',
    'bypass', 'by pass', 'patel nagar', 'kushwaha', 'south', 'nh34 south', 'nh-34 south',
    'saukhara', 'bairi'
  ];

  static const List<String> _moosanagarKeywords = [
    'moosanagar', 'moosangar', 'musa nagar', 'musanagar', 'mughal', 'mughal road', 'chc', 'hospital',
    'degree college', 'college', 'block', 'sarvoday', 'sarvodaya', 'west', 'bindki road', 'ansar market'
  ];

  static const List<String> _kanpurKeywords = [
    'kanpur', 'kanpur road', 'railway', 'station', 'crossing', 'fatak', 'shahi gate',
    'subhash nagar', 'subhash', 'north', 'nh34 north', 'nh-34 north', 'kora jahanabad'
  ];

  static const List<String> _jahanabadKeywords = [
    'jahanabad', 'jahana bad', 'tiraha', 'kotwali', 'thana', 'police station', 'sabzi mandi',
    'purana bazar', 'east', 'jahanabad road'
  ];

  /// Helper to format or append a manual Route Override marker into the order's notes
  static String setRouteInNotes(String? existingNotes, DeliveryRouteKey key) {
    final cleaned = (existingNotes ?? '')
        .replaceAll(RegExp(r'\s*\|\s*ROUTE:[A-Z_]+(?=\s*\||$)', caseSensitive: false), '')
        .replaceAll(RegExp(r'ROUTE:[A-Z_]+', caseSensitive: false), '')
        .trim();
    if (key == DeliveryRouteKey.all) return cleaned;
    String routeName = 'HAMIRPUR';
    switch (key) {
      case DeliveryRouteKey.hamirpur:
        routeName = 'HAMIRPUR';
        break;
      case DeliveryRouteKey.moosanagar:
        routeName = 'MOOSANAGAR';
        break;
      case DeliveryRouteKey.kanpur:
        routeName = 'KANPUR';
        break;
      case DeliveryRouteKey.jahanabad:
        routeName = 'JAHANABAD';
        break;
      case DeliveryRouteKey.townCenter:
      case DeliveryRouteKey.all:
        routeName = 'TOWN_CENTER';
        break;
    }
    final marker = 'ROUTE:$routeName';
    return cleaned.isNotEmpty ? '$cleaned | $marker' : marker;
  }

  static RouteInfo detect(dynamic order) {
    if (order == null) return townCenter;

    // 1. Explicit Admin manual override in notes or deliveryRoute property
    String notesUpper = '';
    if (order is Map) {
      notesUpper = '${order['notes'] ?? ''} ${order['deliveryRoute'] ?? ''}'.toUpperCase();
      final subs = order['subOrders'];
      if (subs is List) {
        for (final s in subs) {
          if (s is Map) {
            notesUpper = '$notesUpper ${s['notes'] ?? ''} ${s['deliveryRoute'] ?? ''}'.toUpperCase();
          }
        }
      }
    } else {
      try {
        notesUpper = '${(order as dynamic).notes ?? ''} ${(order as dynamic).deliveryRoute ?? ''}'.toUpperCase();
        final subs = (order as dynamic).subOrders;
        if (subs is List) {
          for (final s in subs) {
            notesUpper = '$notesUpper ${(s as dynamic).notes ?? ''} ${(s as dynamic).deliveryRoute ?? ''}'.toUpperCase();
          }
        }
      } catch (_) {}
    }

    if (notesUpper.contains('ROUTE:HAMIRPUR')) return hamirpur;
    if (notesUpper.contains('ROUTE:MOOSANAGAR')) return moosanagar;
    if (notesUpper.contains('ROUTE:KANPUR')) return kanpur;
    if (notesUpper.contains('ROUTE:JAHANABAD')) return jahanabad;
    if (notesUpper.contains('ROUTE:TOWN_CENTER')) return townCenter;

    try {
      final rProp = (order is Map ? order['deliveryRoute'] : (order as dynamic).deliveryRoute)?.toString().toUpperCase().trim();
      if (rProp == 'HAMIRPUR') return hamirpur;
      if (rProp == 'MOOSANAGAR') return moosanagar;
      if (rProp == 'KANPUR') return kanpur;
      if (rProp == 'JAHANABAD') return jahanabad;
      if (rProp == 'TOWN_CENTER') return townCenter;
    } catch (_) {}

    String addressText = '';
    String notes = '';
    num? lat;
    num? lng;

    if (order is Map) {
      final rawAddr = order['address'] ?? order['addresses'] ?? order['customerAddress'];
      if (rawAddr is Map) {
        addressText = [
          rawAddr['addressLine1'],
          rawAddr['addressLine2'],
          rawAddr['street'],
          rawAddr['address'],
          rawAddr['formattedAddress'],
          rawAddr['landmark'],
          rawAddr['city'],
          rawAddr['locality'],
        ].where((s) => s != null && s.toString().trim().isNotEmpty).join(' ');
        lat = rawAddr['lat'] is num ? rawAddr['lat'] : null;
        lng = rawAddr['lng'] is num ? rawAddr['lng'] : null;
      } else if (rawAddr is String) {
        addressText = rawAddr;
      }
      notes = (order['notes'] ?? order['deliveryInstructions'] ?? '').toString();
      lat = order['deliveryLat'] ?? lat;
      lng = order['deliveryLng'] ?? lng;
    } else {
      // Order model from fastkirana_flutter
      try {
        final a = (order as dynamic).address;
        if (a != null) {
          final fmt = a.formattedAddress;
          final lbl = a.label;
          addressText = '${fmt ?? ''} ${lbl ?? ''}';
          lat = a.lat;
          lng = a.lng;
        }
      } catch (_) {}

      try {
        final custAddr = (order as dynamic).customerAddress;
        if (custAddr != null && custAddr.toString().isNotEmpty) {
          addressText = '$addressText $custAddr';
        }
      } catch (_) {}

      try {
        final rawAddr = (order as dynamic).addressRaw;
        if (rawAddr is Map) {
          final extra = [
            rawAddr['addressLine1'],
            rawAddr['addressLine2'],
            rawAddr['street'],
            rawAddr['address'],
            rawAddr['formattedAddress'],
            rawAddr['landmark'],
            rawAddr['city'],
          ].where((s) => s != null && s.toString().trim().isNotEmpty).join(' ');
          addressText = '$addressText $extra';
          lat ??= rawAddr['lat'] is num ? rawAddr['lat'] : null;
          lng ??= rawAddr['lng'] is num ? rawAddr['lng'] : null;
        }
      } catch (_) {}

      try {
        notes = ((order as dynamic).notes ?? '').toString();
        lat ??= (order as dynamic).deliveryLat;
        lng ??= (order as dynamic).deliveryLng;
      } catch (_) {}
    }

    final rawText = '$addressText $notes'.toLowerCase();

    for (final kw in _hamirpurKeywords) {
      if (rawText.contains(kw)) return hamirpur;
    }

    for (final kw in _moosanagarKeywords) {
      if (rawText.contains(kw)) return moosanagar;
    }

    for (final kw in _kanpurKeywords) {
      if (rawText.contains(kw)) return kanpur;
    }

    for (final kw in _jahanabadKeywords) {
      if (rawText.contains(kw)) return jahanabad;
    }

    // Coordinate-based approximate direction if available (Ghatampur center is approx lat: 26.155, lng: 80.165)
    if (lat != null && lng != null) {
      const centerLat = 26.155;
      const centerLng = 80.165;
      final dLat = lat.toDouble() - centerLat;
      final dLng = lng.toDouble() - centerLng;

      if (dLat.abs() > 0.005 || dLng.abs() > 0.005) {
        if (dLat < -0.005) return hamirpur; // South
        if (dLat > 0.005 && dLng.abs() < 0.01) return kanpur; // North
        if (dLng < -0.005) return moosanagar; // West
        if (dLng > 0.005) return jahanabad; // East
      }
    }

    return townCenter;
  }
}
