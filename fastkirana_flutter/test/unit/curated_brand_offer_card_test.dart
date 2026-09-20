import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fastkirana_flutter/widgets/curated_brand_offer_card.dart';
import 'package:fastkirana_flutter/widgets/card_media_widget.dart';
import 'package:fastkirana_flutter/data/models/brand_offer_card_data.dart';
import 'package:fastkirana_flutter/providers/banner_provider.dart';
import 'package:fastkirana_flutter/widgets/dynamic_hero_banner_carousel.dart';

void main() {
  testWidgets('CategoryOfferCard renders hero variant (Food / Grocery Spotlight)', (WidgetTester tester) async {
    const data = CategoryCardData(
      id: 'food-hero-1',
      cardType: 'hero',
      eyebrowTag: '🔥 CHEF SPECIAL DROP',
      title: 'DOUBLE CHEESE BURGER',
      subtitle: 'Crispy Patty • Melted Cheddar',
      categoryName: 'A.S. RESTAURANT',
      outletName: 'GHATAMPUR',
      ctaText: 'ORDER BURGERS',
      disclaimerText: '*Hot delivery in 15 mins',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryOfferCard.fromData(data),
        ),
      ),
    );

    expect(find.text('🔥 CHEF SPECIAL DROP'), findsOneWidget);
    expect(find.text('DOUBLE CHEESE BURGER'), findsOneWidget);
    expect(find.text('A.S. RESTAURANT'), findsOneWidget);
    expect(find.text('ORDER BURGERS'), findsOneWidget);
  });

  testWidgets('CategoryOfferCard renders bento_grid variant (2x2 Tiles & Custom CTA)', (WidgetTester tester) async {
    const data = CategoryCardData(
      id: 'bento-1',
      cardType: 'bento_grid',
      eyebrowTag: '🍽️ MOST ORDERED',
      title: 'BEST FOOD SPOTS',
      subtitle: 'Pizzas, Burgers & Shakes',
      ctaText: 'EXPLORE ALL',
      ctaBgColorHex: '#EA580C',
      ctaTextColorHex: '#FFFFFF',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryOfferCard.fromData(data),
        ),
      ),
    );

    expect(find.text('🍽️ MOST ORDERED'), findsOneWidget);
    expect(find.text('BEST FOOD SPOTS'), findsOneWidget);
    expect(find.text('Pizzas, Burgers & Shakes'), findsOneWidget);
    expect(find.text('EXPLORE ALL'), findsOneWidget);
  });

  testWidgets('CategoryOfferCard renders editorial variant (Royal Feast / Offer Pill)', (WidgetTester tester) async {
    const data = CategoryCardData(
      id: 'editorial-1',
      cardType: 'editorial',
      eyebrowTag: '✨ ROYAL FEAST',
      title: 'MIN. 50% OFF',
      subtitle: 'Shahi Paneer & Dal Makhani Combos',
      categoryName: 'WEDSON RESTAURANT',
      cashbackTitle: 'EXTRA ₹100 CASHBACK',
      cashbackSubtitle: 'Use code WEDSON100',
      disclaimerText: '*T&C apply',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryOfferCard.fromData(data),
        ),
      ),
    );

    expect(find.text('✨ ROYAL FEAST'), findsOneWidget);
    expect(find.text('MIN. 50% OFF'), findsOneWidget);
    expect(find.text('WEDSON RESTAURANT'), findsOneWidget);
    expect(find.text('EXTRA ₹100 CASHBACK'), findsOneWidget);
    expect(find.text('Use code WEDSON100'), findsOneWidget);
    expect(find.text('*T&C apply'), findsOneWidget);
  });

  testWidgets('CategoryOffersCarousel renders category multi-cards side-by-side', (WidgetTester tester) async {
    const multiCards = [
      CategoryCardData(
        id: 'c1',
        cardType: 'hero',
        eyebrowTag: '🔥 FRESH DROP',
        title: 'Crispy Burger',
        subtitle: 'Snacks',
      ),
      CategoryCardData(
        id: 'c2',
        cardType: 'bento_grid',
        title: 'Household Staples',
        subtitle: 'Pantry essentials',
        ctaText: 'SHOP NOW',
      ),
      CategoryCardData(
        id: 'c3',
        cardType: 'editorial',
        eyebrowTag: '✨ ROYAL TASTE',
        title: 'Min. 50% off',
        subtitle: 'Royal thalis',
        categoryName: 'WEDSON',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryOffersCarousel(
            sectionTitle: 'Top Category Offers',
            items: multiCards,
          ),
        ),
      ),
    );

    expect(find.text('Top Category Offers'), findsOneWidget);
    expect(find.text('Crispy Burger'), findsOneWidget);
    expect(find.text('Household Staples'), findsOneWidget);
    expect(find.text('Min. 50% off'), findsOneWidget);
  });

  testWidgets('DynamicHeroBannerCarousel renders dynamic category cards seamlessly', (WidgetTester tester) async {
    const mockCards = [
      CategoryCardData(
        id: 'food-hero',
        cardType: 'hero',
        eyebrowTag: '🔥 CHEF SPECIAL',
        title: 'Double Cheese Burger',
        subtitle: 'Hot & crispy',
        categoryName: 'A.S. RESTAURANT',
        outletName: 'GHATAMPUR',
        ctaUrl: '/restaurant/as-restaurant',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryOfferCardsProvider('food').overrideWith((ref) => Future.value(mockCards)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: DynamicHeroBannerCarousel(type: 'food'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Double Cheese Burger'), findsOneWidget);
    expect(find.text('A.S. RESTAURANT'), findsOneWidget);
  });

  testWidgets('CategoryOfferCard accepts videoUrl and renders CardMediaWidget', (WidgetTester tester) async {
    const data = CategoryCardData(
      id: 'video-card-1',
      cardType: 'hero',
      title: 'SIZZLING PIZZA',
      subtitle: 'Wood fired pizza',
      imageUrl: 'https://images.unsplash.com/photo-pizza.jpg',
      videoUrl: 'https://example.com/pizza-motion.mp4',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryOfferCard.fromData(data),
        ),
      ),
    );

    expect(find.text('SIZZLING PIZZA'), findsOneWidget);
    expect(find.byType(CardMediaWidget), findsOneWidget);
  });
}
