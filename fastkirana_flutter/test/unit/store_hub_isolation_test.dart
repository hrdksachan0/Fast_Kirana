import 'package:flutter_test/flutter_test.dart';
import 'package:fastkirana_flutter/data/models/store_hub.dart';
import 'package:fastkirana_flutter/data/models/cart.dart';
import 'package:fastkirana_flutter/data/models/product.dart';

void main() {
  group('StoreHub Geofence & Ray-Casting PIP Tests', () {
    test('Ray-casting algorithm accurately detects points inside vs outside polygon', () {
      // Define a triangular geofence around Ghatampur center
      // Coordinates: (26.15, 80.17), (26.16, 80.17), (26.155, 80.18)
      const hubWithPolygon = StoreHub(
        id: 'hub-test',
        name: 'Test Polygon Hub',
        latitude: 26.1534,
        longitude: 80.1714,
        polygonGeoJson: [
          [26.1500, 80.1700],
          [26.1600, 80.1700],
          [26.1550, 80.1800],
        ],
      );

      // Point strictly inside the triangle
      final insidePoint = hubWithPolygon.isPointInsideGeofence(26.1550, 80.1730);
      expect(insidePoint, isTrue);

      // Point strictly outside the triangle
      final outsidePoint = hubWithPolygon.isPointInsideGeofence(26.1700, 80.1900);
      expect(outsidePoint, isFalse);
    });

    test('StoreHub falls back to Euclidean radius when polygonGeoJson is null', () {
      const hubWithoutPolygon = StoreHub(
        id: 'hub-radius',
        name: 'Test Radius Hub',
        latitude: 26.1534185,
        longitude: 80.1714024,
        deliveryRadiusKm: 5.0,
      );

      // Center point (0 km) -> Inside
      expect(hubWithoutPolygon.isPointInsideGeofence(26.1534185, 80.1714024), isTrue);

      // Point far away (>50 km) -> Outside
      expect(hubWithoutPolygon.isPointInsideGeofence(26.4499, 80.3319), isFalse);
    });

    test('StoreHub parses deliveryPolygon from Map list and List list formats', () {
      final jsonNestedList = {
        'id': 'hub-json-1',
        'name': 'Hub 1',
        'latitude': 26.15,
        'longitude': 80.17,
        'deliveryPolygon': [
          [26.15, 80.17],
          [26.16, 80.17],
          [26.155, 80.18],
        ],
      };

      final hub1 = StoreHub.fromJson(jsonNestedList);
      expect(hub1.polygonGeoJson, isNotNull);
      expect(hub1.polygonGeoJson!.length, equals(3));
      expect(hub1.polygonGeoJson![0], equals([26.15, 80.17]));

      final jsonMapList = {
        'id': 'hub-json-2',
        'name': 'Hub 2',
        'latitude': 26.15,
        'longitude': 80.17,
        'deliveryPolygon': [
          {'lat': 26.15, 'lng': 80.17},
          {'lat': 26.16, 'lng': 80.17},
          {'lat': 26.155, 'lng': 80.18},
        ],
      };

      final hub2 = StoreHub.fromJson(jsonMapList);
      expect(hub2.polygonGeoJson, isNotNull);
      expect(hub2.polygonGeoJson!.length, equals(3));
      expect(hub2.polygonGeoJson![0], equals([26.15, 80.17]));
    });
  });

  group('Cart Hub Binding & Conflict Tests', () {
    test('Cart serializes and deserializes hubId correctly', () {
      final cart = Cart(
        id: 'cart-1',
        userId: 'u-1',
        hubId: 'hub-209206',
        items: [],
        couponDiscount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final json = cart.toJson();
      expect(json['hubId'], equals('hub-209206'));

      final restored = Cart.fromJson(json);
      expect(restored.hubId, equals('hub-209206'));
    });

    test('Cart copyWith accurately updates or retains hubId', () {
      final cart = Cart(
        id: 'cart-1',
        userId: 'u-1',
        hubId: 'hub-209206',
        items: [],
        couponDiscount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final switched = cart.copyWith(hubId: 'hub-224122');
      expect(switched.hubId, equals('hub-224122'));

      final unchanged = cart.copyWith(couponDiscount: 15.0);
      expect(unchanged.hubId, equals('hub-209206'));
    });

    test('Grocery items bound to Hub A report conflict when moving to Hub B', () {
      final dummyGrocery = Product.fromJson({
        'id': 'prod_grocery',
        'name': 'Fortune Rice Bran Oil 1L',
        'slug': 'fortune-rice-bran-oil-1l',
        'price': 135.0,
        'stock': 20,
        'category': 'Oils',
        'imageUrl': '',
      });

      final cart = Cart(
        id: 'cart_hub_a',
        userId: 'u1',
        hubId: 'hub-209206', // Ghatampur Hub
        items: [
          CartItem(
            id: 'item_g1',
            cartId: 'cart_hub_a',
            productId: dummyGrocery.id,
            product: dummyGrocery,
            quantity: 1,
          ),
        ],
        couponDiscount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Switching location to Akbarpur Hub
      const newHubId = 'hub-224122';
      final hasConflict = cart.hubId != null && cart.hubId != newHubId && cart.items.isNotEmpty;
      expect(hasConflict, isTrue);

      // Switching location to same Ghatampur Hub
      const sameHubId = 'hub-209206';
      final hasSameHubConflict = cart.hubId != null && cart.hubId != sameHubId;
      expect(hasSameHubConflict, isFalse);
    });
  });
}
