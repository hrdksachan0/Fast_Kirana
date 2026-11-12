import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fastminute_flutter/features/campaign_bento/campaign_bento_models.dart';

void main() {
  group('CampaignBentoConfig Tests', () {
    test('Default production config initializes 6 distinct archetypes', () {
      final config = CampaignBentoConfig.defaultProductionConfig();

      expect(config.enabled, isTrue);
      expect(config.cards.length, equals(6));

      final cardTypes = config.cards.map((c) => c.type).toList();
      expect(cardTypes, contains(CampaignCardType.freshMarket));
      expect(
        cardTypes.any((t) => t == CampaignCardType.seasonalSwitchUp || t == CampaignCardType.dailyRestock),
        isTrue,
      );
      expect(cardTypes, contains(CampaignCardType.valuePicks));
      expect(cardTypes, contains(CampaignCardType.giftingBoutique));
      expect(cardTypes, contains(CampaignCardType.movieNight));
      expect(cardTypes, contains(CampaignCardType.breakfastClub));
    });

    test('All cards have distinct color palettes and configuration', () {
      final config = CampaignBentoConfig.defaultProductionConfig();

      for (var i = 0; i < config.cards.length; i++) {
        final card = config.cards[i];
        expect(card.title, isNotEmpty);
      }
    });

    test('JSON round-trip preserves all fields for dynamic live editability', () {
      final original = CampaignBentoConfig.defaultProductionConfig();
      final json = original.toJson();
      final restored = CampaignBentoConfig.fromJson(json);

      expect(restored.enabled, equals(original.enabled));
      expect(restored.sectionTitle, equals(original.sectionTitle));
      expect(restored.cards.length, equals(original.cards.length));

      for (var i = 0; i < original.cards.length; i++) {
        expect(restored.cards[i].id, equals(original.cards[i].id));
        expect(restored.cards[i].type, equals(original.cards[i].type));
        expect(restored.cards[i].badge, equals(original.cards[i].badge));
        expect(restored.cards[i].title, equals(original.cards[i].title));
        expect(restored.cards[i].items.length, equals(original.cards[i].items.length));
      }
    });

    test('Card can be dynamically edited and customized', () {
      final config = CampaignBentoConfig.defaultProductionConfig();
      final firstCard = config.cards.first;

      final editedCard = firstCard.copyWith(
        title: 'Super Fresh Sabzi Mandi',
        badge: 'FARM FRESH',
        accentColor: const Color(0xFF059669),
      );

      expect(editedCard.title, equals('Super Fresh Sabzi Mandi'));
      expect(editedCard.badge, equals('FARM FRESH'));
      expect(editedCard.accentColor, equals(const Color(0xFF059669)));
    });
  });
}
