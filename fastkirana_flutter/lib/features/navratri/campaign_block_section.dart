import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/models/product.dart';
import '../../widgets/product_card.dart';
import 'campaign_block.dart';
import 'navratri_animation.dart';
import 'navratri_data.dart';

String navratriPrice(double value) =>
    '₹${value == value.roundToDouble() ? value.toInt() : value.toStringAsFixed(2)}';

class CampaignBlockSection extends StatelessWidget {
  final NavratriData data;
  final List<Product> catalog;
  final bool loading, paused;
  final VoidCallback onPause;
  final void Function(NavratriDestination) onNavigate;
  final ValueChanged<Product>? onProductSelected;
  final Widget Function(String) artwork;
  const CampaignBlockSection(
      {super.key,
      required this.data,
      required this.catalog,
      required this.loading,
      required this.paused,
      required this.onPause,
      required this.onNavigate,
      this.onProductSelected,
      required this.artwork});

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('campaign-block-canvas'),
        color: data.appearance.background,
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child: Text(data.labels.sectionLabel,
                          style: TextStyle(
                              color: _headerSecondary(data.appearance),
                              fontSize: 12,
                              fontWeight: FontWeight.w600))),
                  TextButton.icon(
                      onPressed: onPause,
                      icon: Icon(paused ? Icons.play_arrow : Icons.pause,
                          size: 18),
                      label: Text(paused ? 'Play' : 'Pause'),
                      style: TextButton.styleFrom(
                          foregroundColor: _headerSecondary(data.appearance))),
                ]),
                for (final block in data.blocks.where((block) => block.enabled))
                  Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: _BlockView(
                          key: ValueKey('campaign-block-${block.id}'),
                          block: block,
                          data: data,
                          catalog: catalog,
                          loading: loading,
                          paused: paused,
                          onNavigate: onNavigate,
                          onProductSelected: onProductSelected,
                          artwork: artwork)),
              ])),
        ),
      );
}

Color _headerSecondary(NavratriAppearance appearance) {
  final background = appearance.background.computeLuminance();
  double contrast(Color color) {
    final foreground = color.computeLuminance();
    return (math.max(background, foreground) + .05) /
        (math.min(background, foreground) + .05);
  }

  return contrast(appearance.headerText) > contrast(appearance.smallText)
      ? appearance.headerText
      : appearance.smallText;
}

class _BlockView extends StatefulWidget {
  final CampaignBlock block;
  final NavratriData data;
  final List<Product> catalog;
  final bool loading, paused;
  final void Function(NavratriDestination) onNavigate;
  final ValueChanged<Product>? onProductSelected;
  final Widget Function(String) artwork;
  const _BlockView(
      {super.key,
      required this.block,
      required this.data,
      required this.catalog,
      required this.loading,
      required this.paused,
      required this.onNavigate,
      this.onProductSelected,
      required this.artwork});
  @override
  State<_BlockView> createState() => _BlockViewState();
}

class _BlockViewState extends NavratriAutoplayState<_BlockView> {
  int _index = 0;
  CampaignBlock get block => widget.block;
  NavratriAppearance get appearance => widget.data.appearance;
  List<NavratriHeaderSlide> get headers =>
      campaignBlockItems(widget.data.headers, block.itemIds, (item) => item.id);
  List<NavratriProduct> get promotions =>
      campaignBlockItems(widget.data.products, block.itemIds, (item) => item.id)
          .where((item) {
        final result = NavratriPromotion.resolve(item, widget.catalog);
        return result.linked ? result.available : widget.data.demo;
      }).toList();
  int get count => block.type == 'banner'
      ? headers.length
      : block.type == 'spotlight'
          ? promotions.length
          : 0;
  @override
  bool get manuallyPaused => widget.paused || !widget.data.autoplay;
  @override
  void startTimers() {
    if (count > 1) {
      periodic(
          block.motion.interval(block.type == 'banner'
              ? widget.data.timings.header
              : widget.data.timings.product), () {
        if (count > 0) setState(() => _index = (_index + 1) % count);
      });
    }
  }

  @override
  void didUpdateWidget(covariant _BlockView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _index %= math.max(1, count);
    syncAutoplay(force: true);
  }

  Widget art(String image) => CampaignArtworkMotion(
      motion: block.motion,
      paused: manuallyPaused,
      color: appearance.smallText,
      transitionDuration: widget.data.timings.crossfade,
      assetKey: image,
      child: widget.artwork(image));
  double measure(String text, double width, double size,
      {FontWeight weight = FontWeight.w500}) {
    final painter = TextPainter(
        text: TextSpan(
            text: text,
            style: DefaultTextStyle.of(context)
                .style
                .copyWith(fontSize: size, height: 1.3, fontWeight: weight)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context))
      ..layout(maxWidth: math.max(24, width));
    return painter.height;
  }

  Widget text(String value, double size,
          {FontWeight weight = FontWeight.w500, Color? color}) =>
      Text(value,
          style: TextStyle(
              fontSize: size,
              height: 1.3,
              fontWeight: weight,
              color: color ?? appearance.smallText));
  List<Widget> copy({String fallback = ''}) => [
        if ((block.title.isEmpty ? fallback : block.title).isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: text(block.title.isEmpty ? fallback : block.title, 19,
                  weight: FontWeight.w700)),
        if (block.body.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: text(block.body, 14)),
      ];
  Widget switcher(Widget child) => AnimatedSwitcher(
      duration: reducedMotion
          ? Duration.zero
          : block.motion.fade(widget.data.timings.crossfade),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: navratriSwitcherLayout,
      transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: block.motion.preset == 'slide' && !reducedMotion
              ? SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(.06, 0), end: Offset.zero)
                      .animate(animation),
                  child: child)
              : child),
      child: child);
  void openPromotion(NavratriProduct item) {
    final result = NavratriPromotion.resolve(item, widget.catalog);
    if (result.live != null && widget.onProductSelected != null) {
      widget.onProductSelected!(result.live!);
    } else {
      widget.onNavigate(widget.data.destination(item.destinationId));
    }
  }

  Widget card({required Widget child, VoidCallback? onTap, String? label}) =>
      Semantics(
          label: label,
          button: onTap != null,
          child: Material(
              color: appearance.card,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                      padding: const EdgeInsets.all(8), child: child))));

  Widget banner(double width) {
    final slides = headers;
    if (slides.isEmpty) return text(widget.data.labels.emptyText, 13);
    double height(NavratriHeaderSlide slide) {
      final copyWidth = block.image != null || slide.image != null
          ? math.max(24.0, (width - 14) * .6)
          : width;
      return measure(slide.eyebrow, copyWidth, 12) +
          measure(
              block.title.isEmpty ? slide.title : block.title, copyWidth, 26,
              weight: FontWeight.w800) +
          measure(
              block.body.isEmpty ? slide.subtitle : block.body, copyWidth, 13) +
          36;
    }

    final current = slides[_index % slides.length];
    final title = block.title.isEmpty ? current.title : block.title;
    final titleStyle = TextStyle(
        fontSize: 26,
        height: 1.3,
        fontWeight: FontWeight.w800,
        color: appearance.headerText);
    return SizedBox(
        height: math.max(200, slides.map(height).reduce(math.max)),
        child: switcher(
            Row(key: ValueKey('block-header-${current.id}'), children: [
          Expanded(
              flex: 60,
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (current.eyebrow.isNotEmpty)
                      text(current.eyebrow, 12,
                          color: _headerSecondary(appearance)),
                    Stack(children: [
                      ExcludeSemantics(
                          child: Text(title,
                              style: titleStyle.copyWith(
                                  foreground: Paint()
                                    ..style = PaintingStyle.stroke
                                    ..strokeWidth = 2
                                    ..color = appearance.headerOutline))),
                      Text(title, style: titleStyle)
                    ]),
                    text(block.body.isEmpty ? current.subtitle : block.body, 13,
                        color: _headerSecondary(appearance)),
                  ])),
          if (block.image != null || current.image != null)
            const SizedBox(width: 14),
          if (block.image != null || current.image != null)
            Expanded(
                flex: 40,
                child: block.image != null || current.image != null
                    ? SizedBox(
                        height: 190, child: art(block.image ?? current.image!))
                    : const SizedBox.shrink()),
        ])));
  }

  Widget spotlight(double width) {
    final items = promotions;
    if (items.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ...copy(fallback: widget.data.labels.specialsHeading),
        text(widget.data.labels.emptyText, 13)
      ]);
    }
    final current = items[_index % items.length];
    final result = NavratriPromotion.resolve(current, widget.catalog);
    final priceSize = block.presentation == 'offer' ? 40.0 : 30.0;
    final copyWidth = (width - 14) * .58;
    final height = items.map((item) {
      final promotion = NavratriPromotion.resolve(item, widget.catalog);
      return measure(navratriPrice(promotion.price), copyWidth, priceSize,
              weight: FontWeight.w800) +
          measure(promotion.name, copyWidth, 16, weight: FontWeight.w700) +
          measure(navratriPrice(promotion.originalPrice), copyWidth, 12) +
          (promotion.demo
              ? measure(widget.data.labels.demoLabel, copyWidth, 10)
              : 0) +
          40;
    }).reduce(math.max);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...copy(fallback: widget.data.labels.specialsHeading),
      Semantics(
          button: true,
          label: 'Explore ${result.name}${result.demo ? '. Demo price' : ''}',
          child: InkWell(
              onTap: () => openPromotion(current),
              child: SizedBox(
                  height: math.max(170, height),
                  child: switcher(Row(
                      key: ValueKey('block-promotion-${current.id}'),
                      children: [
                        Expanded(
                            flex: 58,
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (result.originalPrice > result.price)
                                    Text(navratriPrice(result.originalPrice),
                                        style: TextStyle(
                                            fontSize: 12,
                                            height: 1.3,
                                            color: appearance.smallText,
                                            decoration:
                                                TextDecoration.lineThrough)),
                                  text(navratriPrice(result.price), priceSize,
                                      weight: FontWeight.w800),
                                  const SizedBox(height: 8),
                                  text(result.name, 16,
                                      weight: FontWeight.w700),
                                  if (result.demo)
                                    text(widget.data.labels.demoLabel, 10),
                                ])),
                        const SizedBox(width: 14),
                        Expanded(
                            flex: 42,
                            child: SizedBox(
                                height: 150, child: art(result.image))),
                      ]))))),
    ]);
  }

  Widget categories(double width) {
    final items = campaignBlockItems(
        widget.data.categories, block.itemIds, (item) => item.id);
    final row = block.presentation == 'row';
    final columns = math.max(1, math.min(items.length, width >= 600 ? 4 : 2));
    final cardWidth = row ? 128.0 : (width - (columns - 1) * 10) / columns;
    final heights = items.map((item) =>
        measure(item.label, cardWidth - 16, 16, weight: FontWeight.w700) + 132);
    final height = heights.isEmpty ? 160.0 : heights.reduce(math.max);
    final cards = items
        .map((item) => SizedBox(
            width: cardWidth,
            height: height,
            child: card(
                label: 'Shop ${item.label}',
                onTap: () => widget
                    .onNavigate(widget.data.destination(item.destinationId)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      text(item.label, 16, weight: FontWeight.w700),
                      const SizedBox(height: 8),
                      Expanded(child: art(item.image))
                    ]))))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...copy(),
      row
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  cards[i]
                ]
              ]))
          : Wrap(spacing: 10, runSpacing: 10, children: cards),
    ]);
  }

  Widget collection(double width) {
    final tab = widget.data.tabs.firstWhere((tab) => tab.id == block.tabId);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final matches =
        widget.data.filterProducts(widget.catalog, tab).take(12).toList();
    final demos = widget.catalog.isEmpty && widget.data.demo
        ? widget.data
            .demoProductsFor(tab)
            .where((item) => item.productId == null)
            .toList()
        : <NavratriProduct>[];
    final row = block.presentation == 'row';
    final columns = width >= 600 ? 4 : 2;
    final itemWidth = row
        ? 168.0 + math.max(0.0, scale - 1) * 40
        : (width - (columns - 1) * 10) / columns;
    final cards = matches.isNotEmpty
        ? matches
            .map((product) => SizedBox(
                width: itemWidth,
                height: 270 + math.max(0, scale - 1) * 160,
                child: ProductCard(
                    product: product,
                    width: itemWidth,
                    imageBuilder: (child) => CampaignArtworkMotion(
                        motion: block.motion,
                        paused: manuallyPaused,
                        color: appearance.smallText,
                        transitionDuration: widget.data.timings.crossfade,
                        assetKey: '${product.id}:${product.imageUrl}',
                        child: child),
                    heroTag: 'campaign-${block.id}-${product.id}')))
            .toList()
        : demos
            .map((item) => SizedBox(
                width: itemWidth,
                child: card(
                    label: 'Search ${item.name}. Demo example',
                    onTap: () => openPromotion(item),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 120, child: art(item.image)),
                          const SizedBox(height: 8),
                          text(item.name, 14, weight: FontWeight.w700),
                          text('${navratriPrice(item.price)} · Demo', 14),
                          const SizedBox(height: 6),
                          text('Search catalogue', 11),
                        ]))))
            .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...copy(fallback: tab.label),
      if (widget.loading)
        text(widget.data.labels.loadingText, 13)
      else if (cards.isEmpty)
        text(widget.data.labels.emptyText, 13)
      else ...[
        if (matches.isEmpty)
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: text(widget.data.labels.resultsDemoLabel, 11)),
        row
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        cards[i]
                      ],
                    ]))
            : Wrap(spacing: 10, runSpacing: 10, children: cards),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color:
                block.type == 'banner' ? Colors.transparent : appearance.card,
            borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.all(block.type == 'banner' ? 4 : 16),
        child: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (block.type == 'banner') return banner(width);
          if (block.type == 'spotlight') return spotlight(width);
          if (block.type == 'categories') return categories(width);
          if (block.type == 'collection') return collection(width);
          final content =
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (block.type == 'image' && block.image != null)
              SizedBox(height: 210, width: width, child: art(block.image!)),
            ...copy(),
            if (block.destinationId != null)
              text('Browse collection', 13, weight: FontWeight.w600),
          ]);
          final message = block.type == 'text'
              ? TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.75, end: 1),
                  duration: reducedMotion || manuallyPaused
                      ? Duration.zero
                      : block.motion.fade(widget.data.timings.crossfade),
                  curve: Curves.easeOutCubic,
                  child: content,
                  builder: (context, value, child) =>
                      block.motion.preset == 'slide'
                          ? Transform.translate(
                              offset: Offset((1 - value) * 40, 0), child: child)
                          : block.motion.preset == 'fade'
                              ? Opacity(opacity: value, child: child)
                              : child!,
                )
              : content;
          return block.destinationId == null
              ? message
              : InkWell(
                  onTap: () => widget.onNavigate(
                      widget.data.destination(block.destinationId!)),
                  child: message);
        }),
      );
}

class CampaignArtworkMotion extends StatefulWidget {
  final CampaignMotion motion;
  final bool paused;
  final Color color;
  final Duration transitionDuration;
  final String assetKey;
  final Widget child;
  const CampaignArtworkMotion(
      {super.key,
      required this.motion,
      required this.paused,
      required this.color,
      this.transitionDuration = const Duration(milliseconds: 400),
      this.assetKey = '',
      required this.child});
  @override
  State<CampaignArtworkMotion> createState() => _ArtworkMotionState();
}

class _ArtworkMotionState extends NavratriAutoplayState<CampaignArtworkMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _wasAllowed = false;
  bool get _entrance => const ['fade', 'slide'].contains(widget.motion.preset);
  Duration get _duration => _entrance
      ? widget.motion.fade(widget.transitionDuration)
      : widget.motion.loop;
  @override
  bool get manuallyPaused => widget.paused || widget.motion.preset == 'none';
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
  }

  @override
  void startTimers() {}
  @override
  void syncAutoplay({bool force = false}) {
    super.syncAutoplay(force: force);
    final allowed = autoplayAllowed;
    final resumed = allowed && !_wasAllowed;
    _wasAllowed = allowed;
    if (allowed) {
      if (_entrance) {
        if (resumed || force) _controller.forward(from: 0);
      } else if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.value = _entrance ? 1 : 0;
    }
  }

  @override
  void didUpdateWidget(covariant CampaignArtworkMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.motion.speed != widget.motion.speed ||
        oldWidget.motion.preset != widget.motion.preset ||
        oldWidget.transitionDuration != widget.transitionDuration ||
        oldWidget.assetKey != widget.assetKey;
    if (changed) {
      _controller.stop();
      _controller.duration = _duration;
    }
    syncAutoplay(force: changed);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        if (!autoplayAllowed) return child!;
        final progress = Curves.easeOutCubic.transform(_controller.value);
        if (widget.motion.preset == 'fade') {
          return Opacity(opacity: .7 + .3 * progress, child: child);
        }
        if (widget.motion.preset == 'slide') {
          return Transform.translate(
              offset: Offset(10 * (1 - progress), 0), child: child);
        }
        final value = math.sin(_controller.value * math.pi);
        if (widget.motion.preset == 'float') {
          return Transform.translate(
              offset: Offset(0, -5 * value), child: child);
        }
        if (widget.motion.preset == 'zoom') {
          return Transform.scale(scale: 1 + .04 * value, child: child);
        }
        if (widget.motion.preset == 'sparkle') {
          return Stack(children: [
            child!,
            Positioned.fill(
                child: IgnorePointer(
                    child: ExcludeSemantics(
                        child: CustomPaint(
                            painter: _Sparkles(widget.color, value)))))
          ]);
        }
        return child!;
      });
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _Sparkles extends CustomPainter {
  final Color color;
  final double value;
  _Sparkles(this.color, this.value);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: value * .65);
    for (final point in [
      Offset(size.width * .12, size.height * .2),
      Offset(size.width * .86, size.height * .76)
    ]) {
      final radius = 3 + value * 2;
      final path = Path()
        ..moveTo(point.dx, point.dy - radius)
        ..lineTo(point.dx + radius, point.dy)
        ..lineTo(point.dx, point.dy + radius)
        ..lineTo(point.dx - radius, point.dy)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _Sparkles oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}
