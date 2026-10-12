import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../data/models/product.dart';
import '../../widgets/product_card.dart';
import 'navratri_animation.dart';
import 'navratri_data.dart';
import 'campaign_block_section.dart';

const navratriOrange = Color(0xFFFF831F);
const navratriCream = Color(0xFFFFF8DF);
const navratriBrown = Color(0xFF985F39);
// Small body text uses a deeper brown to meet contrast on the pinned palette.

class _CampaignStyle extends InheritedWidget {
  final NavratriData data;
  const _CampaignStyle({required this.data, required super.child});
  static NavratriAppearance of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_CampaignStyle>()
          ?.data
          .appearance ??
      const NavratriAppearance();
  @override
  bool updateShouldNotify(_CampaignStyle oldWidget) => oldWidget.data != data;
}

Widget _creamHeadline(String text, TextStyle style,
        {TextAlign textAlign = TextAlign.start,
        Color outline = const Color(0xFF713D21)}) =>
    Stack(
      alignment: Alignment.center,
      children: [
        ExcludeSemantics(
          child: Text(
            text,
            textAlign: textAlign,
            style: style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..color = outline,
            ),
          ),
        ),
        Text(text, textAlign: textAlign, style: style),
      ],
    );

typedef NavratriNavigate = void Function(NavratriDestination destination);

class NavratriIllustration extends StatelessWidget {
  final String image;
  final BoxFit fit;
  const NavratriIllustration(
      {super.key, required this.image, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    final source = navratriAsset(image);
    final network = source.startsWith('https://');
    Widget error() => Center(
        child: Icon(Icons.shopping_bag_outlined,
            color: _CampaignStyle.of(context).text));
    final Widget content;
    if (navratriImageIsSvg(source)) {
      content = SvgPicture(
        network ? SvgNetworkLoader(source) : SvgAssetLoader(source),
        fit: fit,
        excludeFromSemantics: true,
        placeholderBuilder: (_) => const SizedBox.expand(),
        errorBuilder: (_, __, ___) => error(),
      );
    } else if (network) {
      content = CachedNetworkImage(
          imageUrl: source,
          fit: fit,
          placeholder: (_, __) => const SizedBox.expand(),
          errorWidget: (_, __, ___) => error());
    } else {
      content =
          Image.asset(source, fit: fit, errorBuilder: (_, __, ___) => error());
    }
    return ExcludeSemantics(child: content);
  }
}

class NavratriStickyHeader extends StatefulWidget {
  final NavratriData data;
  final NavratriNavigate onNavigate;
  final VoidCallback onSearch;
  final VoidCallback? onVoiceSearch;
  const NavratriStickyHeader({
    super.key,
    required this.data,
    required this.onNavigate,
    required this.onSearch,
    this.onVoiceSearch,
  });

  static double height(BuildContext context,
      {NavratriData? data, bool voice = true}) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    if (data == null) return 64 + math.max(0, scale - 1) * 60;
    final contentWidth = math.max(
        60.0, MediaQuery.sizeOf(context).width - 62 - (voice ? 48 : 0));
    final prefix = _prefixWidth(context, data, contentWidth);
    double textHeight(String text, double width) {
      final painter = TextPainter(
        text: TextSpan(
            text: text,
            style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 13) ??
                const TextStyle(fontSize: 13)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: width);
      return painter.height;
    }

    final suggestionHeight = data.searchSuggestions
        .map(
            (text) => textHeight(text, math.max(20, contentWidth - prefix - 5)))
        .reduce(math.max);
    return math.max(64 + math.max(0, scale - 1) * 60,
        math.max(textHeight(data.searchPrefix, prefix), suggestionHeight) + 36);
  }

  static double _prefixWidth(
      BuildContext context, NavratriData data, double available) {
    final painter = TextPainter(
      text: TextSpan(
          text: data.searchPrefix,
          style:
              Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13) ??
                  const TextStyle(fontSize: 13)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return math.min(painter.width + 4, available * .45);
  }

  @override
  State<NavratriStickyHeader> createState() => _NavratriStickyHeaderState();
}

class _NavratriStickyHeaderState
    extends NavratriAutoplayState<NavratriStickyHeader> {
  int _suggestion = 0;
  @override
  bool get manuallyPaused => !widget.data.autoplay;

  @override
  void didUpdateWidget(covariant NavratriStickyHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _suggestion %= widget.data.searchSuggestions.length;
      syncAutoplay(force: true);
    }
  }

  @override
  void startTimers() => periodic(widget.data.timings.search, () {
        setState(() {
          _suggestion =
              (_suggestion + 1) % widget.data.searchSuggestions.length;
        });
      });

  @override
  Widget build(BuildContext context) {
    final suggestion = widget.data.searchSuggestions[_suggestion];
    final available = math.max(
        60.0,
        MediaQuery.sizeOf(context).width -
            62 -
            (widget.onVoiceSearch != null ? 48 : 0));
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          children: [
            Container(
              height: NavratriStickyHeader.height(context,
                      data: widget.data, voice: widget.onVoiceSearch != null) -
                  16,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEADDD1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: 'Search FastKirana products',
                      excludeSemantics: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: widget.onSearch,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              Icon(Icons.search_rounded,
                                  size: 22,
                                  color: widget.data.appearance.smallText),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: NavratriStickyHeader._prefixWidth(
                                    context, widget.data, available),
                                child: Text(widget.data.searchPrefix,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color:
                                            widget.data.appearance.smallText)),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: reducedMotion
                                      ? Duration.zero
                                      : widget.data.timings.crossfade,
                                  layoutBuilder: navratriSwitcherLayout,
                                  transitionBuilder: (child, animation) =>
                                      FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, .18),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  ),
                                  child: Align(
                                    key: ValueKey('suggestion-$suggestion'),
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      suggestion,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: widget.data.appearance.text),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.onVoiceSearch != null)
                    IconButton(
                      tooltip: 'Voice search',
                      onPressed: widget.onVoiceSearch,
                      icon: Icon(Icons.mic_none_rounded,
                          size: 21, color: widget.data.appearance.smallText),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NavratriPinnedHeader extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  const NavratriPinnedHeader({required this.height, required this.child});
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      SizedBox.expand(child: child);
  @override
  bool shouldRebuild(covariant NavratriPinnedHeader oldDelegate) =>
      height != oldDelegate.height || child != oldDelegate.child;
}

class NavratriShoppingSection extends StatefulWidget {
  final NavratriData data;
  final List<Product> catalog;
  final bool catalogLoading;
  final bool catalogFailed;
  final NavratriNavigate onNavigate;
  final ValueChanged<Product>? onProductSelected;
  const NavratriShoppingSection({
    super.key,
    required this.data,
    required this.catalog,
    required this.onNavigate,
    this.catalogLoading = false,
    this.catalogFailed = false,
    this.onProductSelected,
  });
  @override
  State<NavratriShoppingSection> createState() =>
      _NavratriShoppingSectionState();
}

class _NavratriShoppingSectionState
    extends NavratriAutoplayState<NavratriShoppingSection> {
  int _header = 0;
  int _product = 0;
  int _tab = 0;
  bool _paused = false;

  @override
  bool get manuallyPaused =>
      _paused || !widget.data.autoplay || !widget.data.enabled;
  NavratriAppearance get _appearance => widget.data.appearance;
  NavratriLabels get _labels => widget.data.labels;
  Color get _headerSecondary {
    final background = _appearance.background.computeLuminance();
    double contrast(Color color) {
      final foreground = color.computeLuminance();
      return (math.max(background, foreground) + .05) /
          (math.min(background, foreground) + .05);
    }

    return contrast(_appearance.headerText) > contrast(_appearance.smallText)
        ? _appearance.headerText
        : _appearance.smallText;
  }

  List<NavratriProduct> get _promotions => widget.data.products.where((item) {
        final promotion = NavratriPromotion.resolve(item, widget.catalog);
        return promotion.linked ? promotion.available : widget.data.demo;
      }).toList(growable: false);

  @override
  void didUpdateWidget(covariant NavratriShoppingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.data.enabled) {
      syncAutoplay(force: true);
      return;
    }
    _header %= widget.data.headers.length;
    _product = _promotions.isEmpty ? 0 : _product % _promotions.length;
    _tab %= widget.data.tabs.length;
    if (oldWidget.data != widget.data || oldWidget.catalog != widget.catalog) {
      syncAutoplay(force: true);
    }
    _preloadNext();
  }

  @override
  void startTimers() {
    if (widget.data.composition == 'blocks') return;
    periodic(widget.data.timings.header, () {
      setState(() => _header = (_header + 1) % widget.data.headers.length);
      _preloadNext();
    });
    if (_promotions.isNotEmpty) {
      periodic(widget.data.timings.product, () {
        if (_promotions.isEmpty) return;
        setState(() => _product = (_product + 1) % _promotions.length);
        _preloadNext();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preloadNext();
  }

  void _preloadNext() {
    if (!widget.data.enabled) return;
    final promotions = _promotions;
    for (final image in {
      widget.data.headers[_header].image,
      widget.data.headers[(_header + 1) % widget.data.headers.length].image,
      if (promotions.isNotEmpty)
        NavratriPromotion.resolve(promotions[_product], widget.catalog).image,
      if (promotions.isNotEmpty)
        NavratriPromotion.resolve(
                promotions[(_product + 1) % promotions.length], widget.catalog)
            .image,
    }) {
      // SvgAssetLoader populates flutter_svg's decoded cache as well as the
      // bundle cache. The next full product unit is ready before its transition.
      if (image == null) continue;
      final source = navratriAsset(image);
      final network = source.startsWith('https://');
      if (navratriImageIsSvg(source)) {
        final loader =
            network ? SvgNetworkLoader(source) : SvgAssetLoader(source);
        unawaited(loader
            .loadBytes(context)
            .then<void>((_) {}, onError: (Object _, StackTrace __) {}));
      } else {
        final ImageProvider provider;
        if (network) {
          provider = CachedNetworkImageProvider(source);
        } else {
          provider = AssetImage(source);
        }
        unawaited(precacheImage(provider, context, onError: (_, __) {}));
      }
    }
  }

  Duration get _duration =>
      reducedMotion ? Duration.zero : widget.data.timings.crossfade;

  Widget _switcher(Widget child) => AnimatedSwitcher(
        duration: _duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: navratriSwitcherLayout,
        child: child,
      );

  Widget _headerSlide(NavratriHeaderSlide slide) {
    final banner = widget.data.layout == 'banner';
    final compact = widget.data.layout == 'deals';
    final copy = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (slide.eyebrow.isNotEmpty)
          Text(slide.eyebrow,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: _headerSecondary)),
        _creamHeadline(
          slide.title,
          TextStyle(
              fontFamily: 'Poppins',
              fontSize: compact
                  ? 23
                  : (banner ? 27 : (slide.kind == 'title' ? 39 : 19)),
              height: 1.18,
              fontWeight: FontWeight.w700,
              color: _appearance.headerText),
          outline: _appearance.headerOutline,
          textAlign: TextAlign.center,
        ),
        if (slide.subtitle.isNotEmpty)
          Text(slide.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _headerSecondary)),
      ],
    );
    if (slide.image == null) return copy;
    if (banner) {
      return Column(children: [
        Expanded(child: copy),
        SizedBox(
            height: 76,
            width: double.infinity,
            child: NavratriIllustration(image: slide.image!)),
      ]);
    }
    return LayoutBuilder(
        builder: (context, constraints) => Row(children: [
              SizedBox(
                  width: math.min(108, constraints.maxWidth * .3),
                  height: constraints.maxHeight,
                  child: NavratriIllustration(image: slide.image!)),
              const SizedBox(width: 8),
              Expanded(child: copy),
            ]));
  }

  double _headerHeight(double width) {
    final available = width - 56;
    final banner = widget.data.layout == 'banner';
    final compact = widget.data.layout == 'deals';
    double textHeight(String text, TextStyle style, double maxWidth) {
      if (text.isEmpty) return 0;
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: maxWidth);
      return painter.height;
    }

    // Reserve the tallest slide before playback so accessibility expansion
    // cannot shift the stationary grid when the header changes.
    final heights = widget.data.headers.map((slide) {
      final copyWidth = slide.image == null || banner
          ? available
          : available - math.min(108, available * .3) - 8;
      return textHeight(
              slide.eyebrow,
              const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
              copyWidth) +
          textHeight(
              slide.title,
              TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: compact
                      ? 23
                      : (banner ? 27 : (slide.kind == 'title' ? 39 : 19)),
                  fontWeight: FontWeight.w700,
                  height: 1.18),
              copyWidth) +
          textHeight(
              slide.subtitle,
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              copyWidth) +
          (banner && slide.image != null ? 76 : 0);
    });
    return math.max(
        banner ? 174 : (compact ? 78 : 100), heights.reduce(math.max) + 21);
  }

  double _gridHeight(double width, double scale) {
    final contentWidth = math.max(24.0, (width - 40) / 3 - 16);
    double height(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(
            text: text, style: DefaultTextStyle.of(context).style.merge(style)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: contentWidth);
      return painter.height;
    }

    final categories = widget.data.categories.map((item) =>
        height(
            item.label,
            const TextStyle(
                fontSize: 10.5, height: 1.14, fontWeight: FontWeight.w700)) +
        74);
    final names = _promotions.map((item) => height(
        NavratriPromotion.resolve(item, widget.catalog).name,
        const TextStyle(
            fontSize: 12, height: 1.2, fontWeight: FontWeight.w700)));
    final tallestName = names.isEmpty
        ? height(_labels.emptyText, const TextStyle(fontSize: 11))
        : names.reduce(math.max);
    final tallCard = height(
            _labels.specialsHeading,
            const TextStyle(
                fontSize: 13, height: 1.15, fontWeight: FontWeight.w800)) +
        tallestName +
        height(_labels.demoLabel, const TextStyle(fontSize: 9)) +
        31 * scale +
        (scale > 1.2 ? 18 * scale : 0) +
        93;
    return [
      230.0 + math.max(0, scale - 1) * 220 + math.max(0, 366 - width) * .65,
      categories.reduce(math.max) * 2 + 8,
      tallCard,
    ].reduce(math.max);
  }

  void _openProduct(NavratriProduct product) {
    final promotion = NavratriPromotion.resolve(product, widget.catalog);
    if (promotion.live != null && widget.onProductSelected != null) {
      widget.onProductSelected!(promotion.live!);
    } else {
      widget.onNavigate(widget.data.destination(product.destinationId));
    }
  }

  Widget _productUnit(NavratriProduct product) {
    final promotion = NavratriPromotion.resolve(product, widget.catalog);
    return Column(
      key: ValueKey('promotion-${product.id}'),
      children: [
        const SizedBox(height: 7),
        if (promotion.showPrice) _PricePill(promotion: promotion),
        Expanded(child: NavratriIllustration(image: promotion.image)),
        Text(
          promotion.name,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: _appearance.smallText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.2),
        ),
        if (promotion.demo || !promotion.available)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
                promotion.demo ? _labels.demoLabel : 'Check availability',
                style: TextStyle(fontSize: 9, color: _appearance.smallText)),
          ),
      ],
    );
  }

  Widget _category(NavratriCategory category) => _CreamCard(
        key: ValueKey('category-${category.id}'),
        label: 'Shop ${category.label}',
        onTap: () =>
            widget.onNavigate(widget.data.destination(category.destinationId)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(category.label,
                style: TextStyle(
                    color: _appearance.smallText,
                    fontSize: 10.5,
                    height: 1.14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Expanded(child: NavratriIllustration(image: category.image)),
          ],
        ),
      );

  double _measureCopy(String text, double width, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(
          text: text, style: DefaultTextStyle.of(context).style.merge(style)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: math.max(24, width));
    return painter.height;
  }

  double _categoryHeight(double width, double artHeight) =>
      widget.data.categories
          .map((item) => _measureCopy(
              item.label,
              width - 16,
              const TextStyle(
                  fontSize: 10.5, height: 1.14, fontWeight: FontWeight.w700)))
          .reduce(math.max) +
      artHeight +
      24;

  double _horizontalPromotionHeight(
      double width, double scale, bool emphasize) {
    final copyWidth = (width - 16) * .63 - 12;
    final heading = _measureCopy(
        _labels.specialsHeading,
        copyWidth,
        const TextStyle(
            fontSize: 13, height: 1.15, fontWeight: FontWeight.w800));
    final names = _promotions.map((item) => _measureCopy(
        NavratriPromotion.resolve(item, widget.catalog).name,
        copyWidth,
        const TextStyle(
            fontSize: 14, height: 1.2, fontWeight: FontWeight.w700)));
    final name = names.isEmpty
        ? _measureCopy(
            _labels.emptyText, copyWidth, const TextStyle(fontSize: 11))
        : names.reduce(math.max);
    final demo = _measureCopy(
        _labels.demoLabel, copyWidth, const TextStyle(fontSize: 9));
    return math.max(emphasize ? 174 : 130,
        heading + name + demo + (emphasize ? 64 : 45) * scale + 40);
  }

  Widget _horizontalProductUnit(NavratriProduct product,
      {required bool emphasize}) {
    final promotion = NavratriPromotion.resolve(product, widget.catalog);
    return Row(
      key: ValueKey('promotion-${product.id}'),
      children: [
        Expanded(flex: 37, child: NavratriIllustration(image: promotion.image)),
        const SizedBox(width: 12),
        Expanded(
            flex: 63,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(promotion.name,
                    style: TextStyle(
                        color: _appearance.smallText,
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (promotion.showPrice)
                  _PricePill(promotion: promotion, emphasize: emphasize),
                if (promotion.demo || !promotion.available)
                  Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                          promotion.demo
                              ? _labels.demoLabel
                              : 'Check availability',
                          style: TextStyle(
                              fontSize: 9, color: _appearance.smallText))),
              ],
            )),
      ],
    );
  }

  Widget _promotionCard(NavratriProduct? product,
      {bool horizontal = false, bool emphasize = false}) {
    final promotion = product == null
        ? null
        : NavratriPromotion.resolve(product, widget.catalog);
    return _CreamCard(
      key: ValueKey(horizontal ? 'navratri-promo-strip' : 'navratri-tall-card'),
      label: promotion == null
          ? _labels.emptyText
          : 'Explore ${promotion.name}. ${promotion.demo ? _labels.demoLabel : ''}',
      onTap: product == null ? null : () => _openProduct(product),
      child: Column(
        crossAxisAlignment:
            horizontal ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Text(_labels.specialsHeading,
              textAlign: horizontal ? TextAlign.start : TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.15,
                  color: _appearance.text,
                  fontWeight: FontWeight.w800)),
          Expanded(
              child: product == null
                  ? Center(
                      child: Text(_labels.emptyText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11, color: _appearance.smallText)))
                  : _switcher(horizontal
                      ? _horizontalProductUnit(product, emphasize: emphasize)
                      : _productUnit(product))),
        ],
      ),
    );
  }

  Widget _categoryRow(double scale, {bool compact = false}) {
    final cardWidth = (compact ? 104.0 : 120.0) + math.max(0, scale - 1) * 30;
    return SizedBox(
      key: const ValueKey('navratri-category-row'),
      height: _categoryHeight(cardWidth, compact ? 54 : 78),
      child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (var index = 0; index < 4; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              SizedBox(
                  width: cardWidth,
                  child: _category(widget.data.categories[index])),
            ],
          ])),
    );
  }

  Widget _categoryPair(int start, double width, {required double artHeight}) =>
      SizedBox(
        height: _categoryHeight((width - 8) / 2, artHeight),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _category(widget.data.categories[start])),
          const SizedBox(width: 8),
          Expanded(child: _category(widget.data.categories[start + 1])),
        ]),
      );

  Widget _layoutBody(double width, double scale, NavratriProduct? product) {
    final layout = widget.data.layout;
    final contentWidth = width - 24;
    if (layout == 'classic') {
      return SizedBox(
        key: const ValueKey('navratri-grid'),
        height: _gridHeight(width, scale),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _promotionCard(product)),
          const SizedBox(width: 8),
          for (var column = 0; column < 2; column++) ...[
            if (column > 0) const SizedBox(width: 8),
            Expanded(
                child: Column(children: [
              Expanded(child: _category(widget.data.categories[column])),
              const SizedBox(height: 8),
              Expanded(child: _category(widget.data.categories[column + 2])),
            ])),
          ],
        ]),
      );
    }
    final promo = SizedBox(
      height:
          _horizontalPromotionHeight(contentWidth, scale, layout == 'deals'),
      child: _promotionCard(product,
          horizontal: true, emphasize: layout == 'deals'),
    );
    return Column(
      key: ValueKey('navratri-layout-$layout'),
      children: switch (layout) {
        'banner' => [promo, const SizedBox(height: 10), _categoryRow(scale)],
        'split' => [
            _categoryPair(0, contentWidth, artHeight: 144),
            const SizedBox(height: 8),
            _categoryPair(2, contentWidth, artHeight: 64),
            const SizedBox(height: 10),
            promo,
          ],
        'grid' => [
            _categoryPair(0, contentWidth, artHeight: 92),
            const SizedBox(height: 8),
            _categoryPair(2, contentWidth, artHeight: 92),
            const SizedBox(height: 10),
            promo,
          ],
        _ => [
            promo,
            const SizedBox(height: 10),
            _categoryRow(scale, compact: true)
          ],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.data.enabled) return const SizedBox.shrink();
    if (widget.data.composition == 'blocks') {
      return Semantics(
          label: _labels.sectionLabel,
          child: _CampaignStyle(
              data: widget.data,
              child: CampaignBlockSection(
                  data: widget.data,
                  catalog: widget.catalog,
                  loading: widget.catalogLoading,
                  paused: _paused,
                  onPause: () {
                    setState(() => _paused = !_paused);
                    syncAutoplay();
                  },
                  onNavigate: widget.onNavigate,
                  onProductSelected: widget.onProductSelected,
                  artwork: (image) => NavratriIllustration(image: image))));
    }
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final products = _promotions;
    final product = products.isEmpty ? null : products[_product];
    final selectedTab = widget.data.tabs[_tab];
    return Semantics(
        label: _labels.sectionLabel,
        child: _CampaignStyle(
            data: widget.data,
            child: Column(
              children: [
                Container(
                  color: _appearance.background,
                  child: LayoutBuilder(builder: (context, constraints) {
                    final width = math.min(constraints.maxWidth, 720.0);
                    final headerHeight = _headerHeight(width);
                    return Center(
                      child: SizedBox(
                        width: width,
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                SizedBox(
                                  height: headerHeight,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        28, 13, 28, 4),
                                    child: _switcher(SizedBox.expand(
                                      key: ValueKey(
                                          'header-${widget.data.headers[_header].id}'),
                                      child: _headerSlide(
                                          widget.data.headers[_header]),
                                    )),
                                  ),
                                ),
                                if (widget.data.decorationImage != null)
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    child: ExcludeSemantics(
                                      child: IgnorePointer(
                                        child: SizedBox(
                                          height: 18,
                                          child: NavratriIllustration(
                                              image:
                                                  widget.data.decorationImage!,
                                              fit: BoxFit.fill),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (!reducedMotion && widget.data.autoplay)
                                  Positioned(
                                    right: 0,
                                    top: 2,
                                    child: IconButton(
                                      key: const ValueKey('navratri-pause'),
                                      tooltip: _paused
                                          ? 'Resume campaign animations'
                                          : 'Pause campaign animations',
                                      iconSize: 18,
                                      color: _headerSecondary,
                                      onPressed: () {
                                        setState(() => _paused = !_paused);
                                        syncAutoplay();
                                      },
                                      icon: Icon(_paused
                                          ? Icons.play_arrow
                                          : Icons.pause),
                                    ),
                                  ),
                              ],
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: _layoutBody(width, scale, product),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.fromLTRB(30, 10, 30, 5),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.elliptical(75, 35),
                                ),
                              ),
                              child: Text(_labels.curvedTabLabel,
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: _appearance.smallText)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                Container(
                  color: Colors.white,
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      children: [
                        _NavratriTabs(
                          tabs: widget.data.tabs,
                          selected: _tab,
                          onSelected: (index) => setState(() => _tab = index),
                        ),
                        _productResults(selectedTab, scale),
                      ],
                    ),
                  ),
                ),
              ],
            )));
  }

  Widget _productResults(NavratriTab tab, double scale) {
    if (widget.catalogLoading) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          label: _labels.loadingText,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_labels.loadingText,
                style: TextStyle(fontSize: 12, color: _appearance.smallText)),
            const SizedBox(height: 8),
            LinearProgressIndicator(color: _appearance.background),
          ]),
        ),
      );
    }
    final matches = widget.data.filterProducts(widget.catalog, tab);
    final demos = widget.data.demo
        ? widget.data
            .demoProductsFor(tab)
            .where((item) => item.productId?.isNotEmpty != true)
            .toList()
        : <NavratriProduct>[];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tab.label,
              style: TextStyle(
                  color: _appearance.smallText,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (matches.isNotEmpty)
            SizedBox(
              height: 270 + math.max(0, scale - 1) * 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: matches.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) => SizedBox(
                  width: 165 + math.max(0, scale - 1) * 40,
                  child: ProductCard(
                    product: matches[index],
                    width: 165 + math.max(0, scale - 1) * 40,
                  ),
                ),
              ),
            )
          else ...[
            Text(
              '${_labels.emptyText}${demos.isEmpty ? '' : ' ${_labels.resultsDemoLabel}'}',
              style: TextStyle(
                  fontSize: 12, color: _appearance.smallText, height: 1.4),
            ),
            const SizedBox(height: 12),
            if (demos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                    'Browse this category in search to check availability.',
                    style:
                        TextStyle(fontSize: 12, color: _appearance.smallText)),
              )
            else
              SizedBox(
                height: 208 + math.max(0, scale - 1) * 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: demos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, index) => SizedBox(
                    width: 150 + math.max(0, scale - 1) * 40,
                    child: _CreamCard(
                      label: 'Search for ${demos[index].name}. Demo example.',
                      onTap: () => _openProduct(demos[index]),
                      child: _productUnit(demos[index]),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CreamCard extends StatelessWidget {
  final Widget child;
  final String label;
  final VoidCallback? onTap;
  const _CreamCard(
      {super.key,
      required this.child,
      required this.label,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        button: onTap != null,
        label: label,
        child: Material(
          color: _CampaignStyle.of(context).card,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(padding: const EdgeInsets.all(8), child: child),
          ),
        ),
      );
}

class _PricePill extends StatelessWidget {
  final NavratriPromotion promotion;
  final bool emphasize;
  const _PricePill({required this.promotion, this.emphasize = false});
  String price(double value) =>
      '₹${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)}';
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: _CampaignStyle.of(context).background.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            if (promotion.originalPrice > promotion.price)
              Text(price(promotion.originalPrice),
                  style: TextStyle(
                      color: _CampaignStyle.of(context).smallText,
                      fontSize: emphasize ? 12 : 9,
                      decoration: TextDecoration.lineThrough)),
            Text(price(promotion.price),
                style: TextStyle(
                    color: _CampaignStyle.of(context).smallText,
                    fontSize: emphasize ? 26 : 13,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _NavratriTabs extends StatelessWidget {
  final List<NavratriTab> tabs;
  final int selected;
  final ValueChanged<int> onSelected;
  const _NavratriTabs(
      {required this.tabs, required this.selected, required this.onSelected});
  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: LayoutBuilder(builder: (context, constraints) {
        final contentWidth = math
            .max(
                constraints.maxWidth,
                tabs.length * (85 + math.max(0, scale - 1) * 30) +
                    (tabs.length - 1) * 8)
            .toDouble();
        final tabWidth = (contentWidth - (tabs.length - 1) * 8) / tabs.length;
        final measured = tabs.map((tab) {
          final painter = TextPainter(
            text: TextSpan(
                text: tab.label,
                style: DefaultTextStyle.of(context).style.merge(const TextStyle(
                    fontSize: 10.5,
                    height: 1.25,
                    fontWeight: FontWeight.w800))),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: tabWidth);
          return painter.height;
        }).reduce(math.max);
        final labelHeight =
            math.max(42 + math.max(0, scale - 1) * 95, measured + 2).toDouble();
        return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
                width: contentWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < tabs.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: Semantics(
                          selected: i == selected,
                          button: true,
                          child: InkWell(
                            key: ValueKey('tab-${tabs[i].id}'),
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => onSelected(i),
                            child: Column(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color:
                                        _CampaignStyle.of(context).tabSurface,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: NavratriIllustration(
                                      image: tabs[i].image),
                                ),
                                const SizedBox(height: 7),
                                SizedBox(
                                  height: labelHeight,
                                  child: Text(tabs[i].label,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: i == selected
                                              ? _CampaignStyle.of(context)
                                                  .underline
                                              : _CampaignStyle.of(context)
                                                  .smallText,
                                          fontSize: 10.5,
                                          height: 1.25,
                                          fontWeight: i == selected
                                              ? FontWeight.w800
                                              : FontWeight.w500)),
                                ),
                                Container(
                                    height: 3,
                                    color: i == selected
                                        ? _CampaignStyle.of(context).underline
                                        : Colors.transparent),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                )));
      }),
    );
  }
}
