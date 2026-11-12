import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../campaign_bento_models.dart';
import '../campaign_bento_provider.dart';
import 'campaign_artwork.dart';

/// The Movie Night Bento Zone Card
/// Perfectly matching the premium editorial design reference (3 white snack cards)
class MovieNightCard extends ConsumerStatefulWidget {
  final CampaignBentoCardConfig card;

  const MovieNightCard({super.key, required this.card});

  @override
  ConsumerState<MovieNightCard> createState() => _MovieNightCardState();
}

class _MovieNightCardState extends ConsumerState<MovieNightCard> {
  final Set<String> _addedItems = {};

  void _handleItemAdd(CampaignBentoItemConfig item) {
    HapticFeedback.lightImpact();
    setState(() => _addedItems.add(item.id));
    ref.read(campaignBentoProvider.notifier).addItemToCart(item, quantity: 1);

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _addedItems.remove(item.id));
    });
  }

  static const List<CampaignBentoItemConfig> _defaultSnackItems = [
    CampaignBentoItemConfig(
      id: 'mn-1',
      name: 'Popcorn',
      weight: '150g',
      price: 40,
      image: 'movie-popcorn.svg',
    ),
    CampaignBentoItemConfig(
      id: 'mn-2',
      name: 'Nachos',
      weight: '52g',
      price: 20,
      image: 'vrat-chips.svg',
    ),
    CampaignBentoItemConfig(
      id: 'mn-3',
      name: 'Chilled Cola',
      weight: '750ml',
      price: 35,
      image: 'chilled-cola.svg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final items = card.items.isNotEmpty ? card.items : _defaultSnackItems;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E0E38),
            Color(0xFF140828),
            Color(0xFF0E051D),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF381B60), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E051D).withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title & Subtitle (Clean & modern, matching reference)
          Text(
            card.title.isNotEmpty ? card.title : 'Movie Night',
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            card.subtitle.isNotEmpty
                ? card.subtitle
                : 'Snacks for the perfect watch time',
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFFB4A5D9),
            ),
          ),

          const SizedBox(height: 14),

          // Cinema Living Room Scene Artwork
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: double.infinity,
              height: 154,
              child: CampaignArtwork(
                image: card.heroImage ?? 'ref-movie-cinema-scene.png',
                fit: BoxFit.cover,
                fallbackIcon: Icons.movie_filter_rounded,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // 3 White Snack Cards Row (Matching reference screenshot exactly)
          Row(
            children: [
              for (var i = 0; i < items.length && i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _buildSnackCard(items[i]),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSnackCard(CampaignBentoItemConfig item) {
    final isAdded = _addedItems.contains(item.id);
    final rawWeight = item.weight.trim();
    final weightStr = rawWeight.startsWith('(') ? rawWeight : '($rawWeight)';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            weightStr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₹${item.price.toInt()}',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _handleItemAdd(item),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: isAdded ? const Color(0xFF16A34A) : const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: (isAdded
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFF7C3AED))
                              .withValues(alpha: 0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      isAdded ? 'Added' : '+ ADD',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
