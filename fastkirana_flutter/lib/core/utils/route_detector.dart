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

  static const RouteInfo all = RouteInfo(
    key: DeliveryRouteKey.all,
    label: 'All Roads',
    shortLabel: 'All Roads',
    emoji: '🛣️',
    primaryColor: Color(0xFF0F172A),
    backgroundColor: Color(0xFFF1F5F9),
    textColor: Color(0xFF0F172A),
    description: 'All 4 arterial roads and town center orders',
  );

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
      case DeliveryRouteKey.all:
        return all;
      case DeliveryRouteKey.hamirpur:
        return hamirpur;
      case DeliveryRouteKey.moosanagar:
        return moosanagar;
      case DeliveryRouteKey.kanpur:
        return kanpur;
      case DeliveryRouteKey.jahanabad:
        return jahanabad;
      case DeliveryRouteKey.townCenter:
        return townCenter;
    }
  }

  static const List<String> _hamirpurKeywords = [
    'hamirpur road', 'hamirpur rd', 'hamirpur', 'hamir pur', 'bus stand', 'bus adda',
    'mandi samiti', 'mandi', 'yamuna pul', 'yamuna bridge', 'yamuna',
    'bypass south', 'south bypass', 'by pass south', 'patel nagar', 'kushwaha nagar',
    'kushwaha', 'south', 'nh34 south', 'nh-34 south', 'saukhara', 'bairi'
  ];

  static const List<String> _moosanagarKeywords = [
    'moosanagar road', 'moosanagar rd', 'moosanagar', 'moosangar', 'musa nagar', 'musanagar',
    'mughal road', 'mughal rd', 'mughal', 'chc hospital', 'chc', 'samudayik', 'hospital',
    'degree college', 'college', 'block office', 'block', 'sarvoday nagar', 'sarvoday',
    'sarvodaya', 'west', 'bindki road', 'bindki rd', 'bindki', 'ansar market'
  ];

  static const List<String> _kanpurKeywords = [
    'kanpur road', 'kanpur rd', 'kanpur highway', 'railway station', 'railway', 'crossing',
    'railway crossing', 'fatak', 'railway fatak', 'station road', 'station rd', 'shahi gate',
    'subhash nagar', 'subhash', 'north', 'nh34 north', 'nh-34 north', 'kora jahanabad',
    'kora mode', 'kora mor'
  ];

  static const List<String> _jahanabadKeywords = [
    'jahanabad road', 'jahanabad rd', 'jahanabad', 'jahana bad', 'jahanabad tiraha', 'tiraha',
    'kotwali', 'thana road', 'thana rd', 'thana', 'police station', 'sabzi mandi',
    'purana bazar', 'purana bazaar', 'east', 'kasba'
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

    final List<String> addressTokens = [];
    String notes = '';
    double? lat;
    double? lng;

    void extractFromMap(Map addr) {
      for (final key in [
        'area',
        'street',
        'houseNo',
        'landmark',
        'label',
        'locality',
        'address',
        'formattedAddress',
        'addressLine1',
        'addressLine2',
        'city'
      ]) {
        final val = addr[key];
        if (val != null && val.toString().trim().isNotEmpty && val.toString() != 'null') {
          final str = val.toString().trim();
          // Filter out generic city name "kanpur nagar" so it doesn't trick keyword detector
          if (key == 'city' && (str.toLowerCase() == 'kanpur' || str.toLowerCase() == 'kanpur nagar')) {
            continue;
          }
          addressTokens.add(str);
        }
      }
      final rawLat = addr['lat'];
      final rawLng = addr['lng'];
      if (lat == null && rawLat != null) {
        lat = rawLat is num ? rawLat.toDouble() : double.tryParse(rawLat.toString());
      }
      if (lng == null && rawLng != null) {
        lng = rawLng is num ? rawLng.toDouble() : double.tryParse(rawLng.toString());
      }
    }

    if (order is Map) {
      final rawAddr = order['address'] ?? order['addresses'] ?? order['customerAddress'] ?? order['addressRaw'];
      if (rawAddr is Map) {
        extractFromMap(rawAddr);
      } else if (rawAddr is List && rawAddr.isNotEmpty) {
        for (final item in rawAddr) {
          if (item is Map) extractFromMap(item);
        }
      } else if (rawAddr is String) {
        addressTokens.add(rawAddr);
      }

      // Also check subOrders for companion addresses
      final subs = order['subOrders'];
      if (subs is List) {
        for (final s in subs) {
          if (s is Map) {
            final sAddr = s['address'] ?? s['addresses'] ?? s['customerAddress'];
            if (sAddr is Map) extractFromMap(sAddr);
            if (s['notes'] != null) addressTokens.add(s['notes'].toString());
          }
        }
      }

      notes = (order['notes'] ?? order['deliveryInstructions'] ?? '').toString();
      final oLat = order['deliveryLat'];
      final oLng = order['deliveryLng'];
      if (oLat != null) lat = oLat is num ? oLat.toDouble() : double.tryParse(oLat.toString());
      if (oLng != null) lng = oLng is num ? oLng.toDouble() : double.tryParse(oLng.toString());
    } else {
      try {
        final a = (order as dynamic).address;
        if (a != null) {
          if (a is Map) {
            extractFromMap(a);
          } else {
            try { if (a.formattedAddress != null) addressTokens.add(a.formattedAddress.toString()); } catch (_) {}
            try { if (a.area != null) addressTokens.add(a.area.toString()); } catch (_) {}
            try { if (a.street != null) addressTokens.add(a.street.toString()); } catch (_) {}
            try { if (a.label != null) addressTokens.add(a.label.toString()); } catch (_) {}
            try { if (a.landmark != null) addressTokens.add(a.landmark.toString()); } catch (_) {}
            try { if (a.lat != null) lat = (a.lat as num).toDouble(); } catch (_) {}
            try { if (a.lng != null) lng = (a.lng as num).toDouble(); } catch (_) {}
          }
        }
      } catch (_) {}

      try {
        final raw = (order as dynamic).addressRaw;
        if (raw is Map) extractFromMap(raw);
      } catch (_) {}

      try {
        final custAddr = (order as dynamic).customerAddress;
        if (custAddr != null) addressTokens.add(custAddr.toString());
      } catch (_) {}

      try {
        notes = ((order as dynamic).notes ?? '').toString();
        final oLat = (order as dynamic).deliveryLat;
        final oLng = (order as dynamic).deliveryLng;
        if (oLat != null) lat = oLat is num ? oLat.toDouble() : double.tryParse(oLat.toString());
        if (oLng != null) lng = oLng is num ? oLng.toDouble() : double.tryParse(oLng.toString());
      } catch (_) {}
    }

    final rawText = '${addressTokens.join(" ")} $notes'.toLowerCase();

    // 2. Keyword Matching across all 4 corridors
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

    // 3. Coordinate-based directional quadrant (Ghatampur Darkstore center: 26.155, 80.165)
    final safeLat = lat;
    final safeLng = lng;
    if (safeLat != null && safeLng != null && safeLat > 20 && safeLng > 70) {
      const centerLat = 26.155;
      const centerLng = 80.165;
      final dLat = safeLat - centerLat;
      final dLng = safeLng - centerLng;

      if (dLat.abs() > 0.004 || dLng.abs() > 0.004) {
        if (dLat < -0.004 && dLat.abs() >= dLng.abs()) return hamirpur; // South
        if (dLat > 0.004 && dLat.abs() >= dLng.abs()) return kanpur; // North
        if (dLng < -0.004 && dLng.abs() > dLat.abs()) return moosanagar; // West
        if (dLng > 0.004 && dLng.abs() > dLat.abs()) return jahanabad; // East
      }
    }

    return townCenter;
  }
}
