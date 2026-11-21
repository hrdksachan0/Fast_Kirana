// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FastMinute Unified Order Event Model (Flutter)
// Standard Immutable Event Envelope received via Supabase Realtime or FCM Push
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class AlertConfig {
  final String urgency; // CRITICAL, HIGH, NORMAL, LOW, SILENT
  final String? sound;  // 'order_chime', 'kitchen_order_bell', 'order_placed_celebrate', null
  final String title;
  final String body;

  const AlertConfig({
    required this.urgency,
    this.sound,
    required this.title,
    required this.body,
  });

  factory AlertConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const AlertConfig(urgency: 'NORMAL', title: '', body: '');
    }
    return AlertConfig(
      urgency: (map['urgency'] ?? 'NORMAL').toString().toUpperCase(),
      sound: map['sound']?.toString(),
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
    );
  }
}

class OrderEvent {
  final String tag;
  final String orderId;
  final String readableId;
  final String displayId;
  final String? combinedId;
  final String? storeId;
  final String? restaurantId;
  final String orderType;

  final String status;
  final String previousStatus;
  final String? paymentStatus;
  final String? paymentMethod;

  final String? actorId;
  final String? actorRole;

  final List<String> targets;
  final AlertConfig alert;
  final Map<String, dynamic> payload;

  final int version;
  final int timestamp;

  const OrderEvent({
    required this.tag,
    required this.orderId,
    required this.readableId,
    required this.displayId,
    this.combinedId,
    this.storeId,
    this.restaurantId,
    this.orderType = 'GROCERY',
    required this.status,
    this.previousStatus = '',
    this.paymentStatus,
    this.paymentMethod,
    this.actorId,
    this.actorRole,
    this.targets = const [],
    required this.alert,
    this.payload = const {},
    required this.version,
    required this.timestamp,
  });

  factory OrderEvent.fromMap(Map<String, dynamic> map) {
    final alertMap = map['alert'] is Map<String, dynamic> ? map['alert'] as Map<String, dynamic> : null;
    final targetsList = map['targets'] is List ? (map['targets'] as List).map((e) => e.toString()).toList() : <String>[];

    final rawOrderId = (map['orderId'] ?? map['id'] ?? '').toString();
    final rawReadable = (map['readableId'] ?? rawOrderId).toString();
    final rawDisplay = (map['displayId'] ?? rawReadable).toString().replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '');

    return OrderEvent(
      tag: (map['tag'] ?? 'ORDER_STATUS_CHANGED').toString(),
      orderId: rawOrderId,
      readableId: rawReadable,
      displayId: rawDisplay.isNotEmpty ? rawDisplay : rawReadable,
      combinedId: map['combinedId']?.toString(),
      storeId: map['storeId']?.toString(),
      restaurantId: map['restaurantId']?.toString(),
      orderType: (map['orderType'] ?? 'GROCERY').toString().toUpperCase(),
      status: (map['status'] ?? '').toString().toUpperCase(),
      previousStatus: (map['previousStatus'] ?? '').toString().toUpperCase(),
      paymentStatus: map['paymentStatus']?.toString(),
      paymentMethod: map['paymentMethod']?.toString(),
      actorId: map['actorId']?.toString(),
      actorRole: map['actorRole']?.toString(),
      targets: targetsList,
      alert: AlertConfig.fromMap(alertMap),
      payload: map['payload'] is Map<String, dynamic> ? map['payload'] as Map<String, dynamic> : {},
      version: (map['version'] is num) ? (map['version'] as num).toInt() : DateTime.now().millisecondsSinceEpoch,
      timestamp: (map['timestamp'] is num) ? (map['timestamp'] as num).toInt() : DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Construct from standard FCM notification data payload
  factory OrderEvent.fromFCMData(Map<String, dynamic> data) {
    final rawOrderId = (data['orderId'] ?? data['id'] ?? '').toString();
    final rawReadable = (data['readableId'] ?? rawOrderId).toString();
    final rawDisplay = (data['displayId'] ?? rawReadable).toString().replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '');
    final status = (data['status'] ?? data['orderStatus'] ?? '').toString().toUpperCase();

    final urgency = (data['urgency'] ?? (data['type'] == 'NEW_ORDER' ? 'CRITICAL' : 'NORMAL')).toString().toUpperCase();
    final title = (data['title'] ?? '').toString();
    final body = (data['body'] ?? data['message'] ?? '').toString();

    final role = (data['role'] ?? '').toString().toUpperCase();
    final targets = <String>[];
    if (role.isNotEmpty) targets.add(role);
    if (data['screen'] == 'admin-orders') targets.add('ADMIN');
    if (data['screen'] == 'order-tracking') targets.add('CUSTOMER');
    if (data['screen'] == 'delivery' || data['screen'] == 'delivery-dashboard') targets.add('RIDER');
    if (data['screen'] == 'restaurant-console') targets.add('KITCHEN');
    if (data['screen'] == 'picker') targets.add('PICKER');

    final rawVersion = int.tryParse(data['version']?.toString() ?? '') ?? DateTime.now().millisecondsSinceEpoch;
    final rawTimestamp = int.tryParse(data['timestamp']?.toString() ?? '') ?? DateTime.now().millisecondsSinceEpoch;

    return OrderEvent(
      tag: (data['type'] ?? 'ORDER_STATUS_CHANGED').toString(),
      orderId: rawOrderId,
      readableId: rawReadable,
      displayId: rawDisplay.isNotEmpty ? rawDisplay : rawReadable,
      combinedId: data['combinedId']?.toString(),
      storeId: data['storeId']?.toString(),
      restaurantId: data['restaurantId']?.toString(),
      orderType: (data['orderType'] ?? 'GROCERY').toString().toUpperCase(),
      status: status,
      previousStatus: (data['previousStatus'] ?? '').toString().toUpperCase(),
      paymentStatus: data['paymentStatus']?.toString(),
      paymentMethod: data['paymentMethod']?.toString(),
      actorId: data['actorId']?.toString(),
      actorRole: data['actorRole']?.toString(),
      targets: targets,
      alert: AlertConfig(
        urgency: urgency,
        sound: data['sound']?.toString(),
        title: title,
        body: body,
      ),
      payload: data,
      version: rawVersion,
      timestamp: rawTimestamp,
    );
  }
}
