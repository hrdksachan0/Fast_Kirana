import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/category.dart';
import '../../providers/product_provider.dart';
import '../../features/categories/category_products_screen.dart';
import '../routes/page_transitions.dart';
import '../widgets/contextual_brand_transition_screen.dart';

/// Intelligent helper to manage Blinkit-style contextual category interstitial transitions
class CategoryTransitionHelper {
  CategoryTransitionHelper._();

  /// Resolves the visual context theme based on category slug and name
  static TransitionContextType resolveContext(Category category) {
    final slug = category.slug.toLowerCase().trim();
    final name = category.name.toLowerCase().trim();

    // 1. Beauty & Personal Care (Blinkit 1:1 Blush + Brush)
    if (slug.contains('beauty') ||
        slug.contains('makeup') ||
        slug.contains('cosmetic') ||
        slug.contains('skincare') ||
        slug.contains('haircare') ||
        slug.contains('personal-care') ||
        slug.contains('grooming') ||
        name.contains('beauty') ||
        name.contains('makeup') ||
        name.contains('personal care') ||
        name.contains('cosmetic') ||
        name.contains('skincare') ||
        name.contains('haircare')) {
      return TransitionContextType.beauty;
    }

    // 2. Pharmacy, Medicine & Health Wellness
    if (slug.contains('pharmacy') ||
        slug.contains('medicine') ||
        slug.contains('health') ||
        slug.contains('wellness') ||
        slug.contains('pharma') ||
        name.contains('pharmacy') ||
        name.contains('medicine') ||
        name.contains('wellness') ||
        name.contains('health')) {
      return TransitionContextType.pharmacy;
    }

    // 3. Electronics, Gadgets & Tech
    if (slug.contains('electronic') ||
        slug.contains('gadget') ||
        slug.contains('tech') ||
        slug.contains('appliance') ||
        slug.contains('audio') ||
        slug.contains('mobile') ||
        name.contains('electronic') ||
        name.contains('gadget') ||
        name.contains('appliance')) {
      return TransitionContextType.essentials;
    }

    // 4. Cafe, Restaurant Kitchen & Hot Foods
    if (slug.contains('cafe') ||
        slug.contains('restaurant') ||
        slug.contains('kitchen') ||
        slug.contains('fastfood') ||
        name.contains('cafe') ||
        name.contains('restaurant') ||
        name.contains('kitchen')) {
      return TransitionContextType.cafe;
    }

    // 5. Default Grocery Express (Veggies, Fruits, Milk, Staples)
    return TransitionContextType.grocery;
  }

  /// Pushes a category screen with the Blinkit-style contextual interstitial loader
  static void pushCategoryWithTransition(
    BuildContext context,
    WidgetRef ref,
    Category category, {
    Duration duration = const Duration(milliseconds: 1200),
  }) {
    final catKey = (category.id.isNotEmpty &&
            (category.id.toUpperCase().startsWith('CAT-') ||
                category.id.toUpperCase().startsWith('SUB-')))
        ? category.id
        : (category.slug.isNotEmpty ? category.slug : category.id);

    // 1. Proactively prefetch catalog data in background during the transition
    ref.read(productsProvider(catKey));

    Navigator.push(
      context,
      FadeThroughRoute(
        page: CategoryProductsScreen(
          category: category,
          loadingContext: resolveContext(category),
          loadingTimeout: duration,
        ),
      ),
    );
  }
}
