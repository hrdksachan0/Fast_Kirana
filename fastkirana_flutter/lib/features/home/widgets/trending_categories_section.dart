import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/routes/page_transitions.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/store_settings_provider.dart';
import '../../categories/category_products_screen.dart';
import '../featured_categories.dart';
import '../main_shell.dart';
import '../utils/category_visual_helper.dart';

/// A short editorial selection; Explore Categories remains the full catalogue.
class TrendingCategoriesSection extends ConsumerWidget {
  const TrendingCategoriesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final settings = ref.watch(storeSettingsProvider);
    // A store switch must not briefly display the previous store's curation.
    if (categories.isLoading ||
        (settings.isLoading && (!settings.hasValue || settings.isReloading))) {
      return const _LoadingRail();
    }
    return categories.when(
      loading: () => const _LoadingRail(),
      error: (_, __) => const SizedBox.shrink(),
      data: (sources) {
        final config = FeaturedCategoriesConfig.parse(
                settings.valueOrNull?.raw[featuredCategoriesKey]) ??
            FeaturedCategoriesConfig.defaults(sources);
        final selected = config.select(sources);
        if (selected.isEmpty) return const SizedBox.shrink();
        final scaler = MediaQuery.textScalerOf(context);
        const labelStyle = TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 14,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: Color(0xFF202A38));
        var labelHeight = scaler.scale(14) * 1.3;
        for (final category in selected) {
          final text = TextPainter(
              text: TextSpan(text: category.label, style: labelStyle),
              maxLines: 2,
              textDirection: Directionality.of(context),
              textScaler: scaler)
            ..layout(maxWidth: 120);
          labelHeight = math.max(labelHeight, text.height);
          text.dispose();
        }
        final hasBadge =
            selected.any((category) => category.item.badge.isNotEmpty);
        final badgeHeight = hasBadge ? scaler.scale(11) * 1.3 + 14 : 0.0;
        final height = 112 + 10 + labelHeight + badgeHeight + 20;
        return Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Expanded(
                      child: Text(config.title,
                          style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 18,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF202A38)))),
                  const SizedBox(width: 8),
                  TextButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        ref.read(selectedTabProvider.notifier).state = 2;
                      },
                      style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          foregroundColor: const Color(0xFFB4232A),
                          padding: const EdgeInsets.symmetric(horizontal: 8)),
                      child: const Text('View all',
                          style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 13,
                              fontWeight: FontWeight.w700))),
                ])),
            const SizedBox(height: 8),
            SizedBox(
                height: height,
                child: ListView.separated(
                  key: const ValueKey('featured-category-rail'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: selected.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => _FeaturedTile(
                      key: ValueKey(selected[index].category.id),
                      selection: selected[index],
                      labelStyle: labelStyle,
                      labelHeight: labelHeight,
                      badgeHeight: badgeHeight),
                )),
          ]),
        );
      },
    );
  }
}

class _FeaturedTile extends StatefulWidget {
  final FeaturedCategorySelection selection;
  final TextStyle labelStyle;
  final double labelHeight, badgeHeight;
  const _FeaturedTile(
      {super.key,
      required this.selection,
      required this.labelStyle,
      required this.labelHeight,
      required this.badgeHeight});
  @override
  State<_FeaturedTile> createState() => _FeaturedTileState();
}

class _FeaturedTileState extends State<_FeaturedTile> {
  bool pressed = false;
  void openCategory() {
    HapticFeedback.selectionClick();
    final page = CategoryProductsScreen(category: widget.selection.category);
    Navigator.of(context).push(MediaQuery.disableAnimationsOf(context)
        ? PageRouteBuilder<void>(
            pageBuilder: (_, __, ___) => page,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero)
        : FadeSlideRoute(page: page));
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.selection, item = selection.item;
    final tint = switch (item.tint) {
      'mint' => const Color(0xFFEFF8F0),
      'cream' => const Color(0xFFFFF8E7),
      'peach' => const Color(0xFFFFF1E7),
      'sky' => const Color(0xFFEEF5FC),
      'rose' => const Color(0xFFFFF0F3),
      'lilac' => const Color(0xFFF5F0FA),
      _ => CategoryVisualHelper.getSoftColor(
          selection.category.slug, selection.category.name),
    };
    return Semantics(
        button: true,
        onTap: openCategory,
        label:
            'Shop ${selection.label}${item.badge.isEmpty ? '' : ', ${item.badge}'}',
        child: ExcludeSemantics(
            child: AnimatedScale(
          scale: pressed ? .98 : 1,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 110),
          child: Material(
            color: tint,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                    color: Color.lerp(tint, const Color(0xFF78818C), .16)!)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onHighlightChanged: (value) => setState(() => pressed = value),
                onTap: openCategory,
                child: SizedBox(
                    width: 144,
                    child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                  borderRadius: BorderRadius.circular(9),
                                  child: SizedBox(
                                      width: 124,
                                      height: 112,
                                      child: _FeaturedArtwork(
                                          selection: selection))),
                              const SizedBox(height: 10),
                              SizedBox(
                                  height: widget.labelHeight,
                                  child: Text(selection.label,
                                      style: widget.labelStyle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis)),
                              if (widget.badgeHeight > 0)
                                SizedBox(
                                    height: widget.badgeHeight,
                                    child: item.badge.isEmpty
                                        ? null
                                        : Align(
                                            alignment: Alignment.bottomLeft,
                                            child: Text(item.badge,
                                                style: const TextStyle(
                                                    fontFamily:
                                                        'Plus Jakarta Sans',
                                                    fontSize: 11,
                                                    height: 1.3,
                                                    color: Color(0xFF536171),
                                                    fontWeight:
                                                        FontWeight.w600)))),
                            ])))),
          ),
        )));
  }
}

class _FeaturedArtwork extends StatelessWidget {
  final FeaturedCategorySelection selection;
  const _FeaturedArtwork({required this.selection});
  @override
  Widget build(BuildContext context) {
    final category = selection.category;
    final fit =
        selection.item.imageFit == 'contain' ? BoxFit.contain : BoxFit.cover;
    final key = '${category.slug} ${category.name}'.toLowerCase();
    final asset = switch (key) {
      final s when s.contains('fruit') || s.contains('veg') =>
        'fruits_vegetables',
      final s when s.contains('dairy') || s.contains('milk') =>
        'dairy_breakfast',
      final s when s.contains('snack') || s.contains('munch') =>
        'snacks_munchies',
      final s when s.contains('beverage') || s.contains('drink') => 'beverages',
      final s when s.contains('ice cream') || s.contains('ice-cream') =>
        'ice_cream',
      final s
          when s.contains('atta') || s.contains('rice') || s.contains('dal') =>
        'atta_rice_dal',
      final s when s.contains('personal') || s.contains('hygiene') =>
        'personal_care',
      final s
          when s.contains('home') ||
              s.contains('clean') ||
              s.contains('household') =>
        'household',
      final s when s.contains('bakery') || s.contains('biscuit') =>
        'bakery_biscuits',
      _ => null,
    };
    Widget fallback() => asset == null
        ? Center(
            child: Text(
                category.name.isEmpty
                    ? '?'
                    : category.name.characters.first.toUpperCase(),
                style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 32,
                    fontWeight: FontWeight.w700)))
        : Image.asset('assets/categories/${asset}_category.webp',
            fit: fit,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.shopping_basket_outlined));
    final source = selection.item.image ?? category.imageUrl;
    if (source == null || source.isEmpty) return fallback();
    final url =
        source.startsWith('/') ? 'https://www.fastkirana.in$source' : source;
    if (!url.startsWith('https://') && !url.startsWith('http://')) {
      return fallback();
    }
    if (Uri.tryParse(url)?.path.toLowerCase().endsWith('.svg') ?? false) {
      return SvgPicture.network(url,
          fit: fit,
          placeholderBuilder: (_) => fallback(),
          errorBuilder: (_, __, ___) => fallback());
    }
    return CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        memCacheWidth: 400,
        memCacheHeight: 400,
        placeholder: (_, __) => fallback(),
        errorWidget: (_, __, ___) => fallback());
  }
}

class _LoadingRail extends StatelessWidget {
  const _LoadingRail();
  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: SizedBox(
          height: 172,
          child: Row(children: [
            Expanded(
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: Color(0xFFF3F5F7),
                        borderRadius: BorderRadius.all(Radius.circular(14))),
                    child: SizedBox.expand())),
            SizedBox(width: 12),
            Expanded(
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: Color(0xFFF3F5F7),
                        borderRadius: BorderRadius.all(Radius.circular(14))),
                    child: SizedBox.expand())),
          ])));
}
