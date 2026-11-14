import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'campaign_bento_models.dart';
export 'campaign_bento_models.dart';
import 'campaign_bento_provider.dart';
import '../../providers/store_hub_provider.dart';
import 'widgets/fresh_market_card.dart';
import 'widgets/daily_restock_card.dart';
import 'widgets/seasonal_switch_up_card.dart';
import 'widgets/value_picks_card.dart';
import 'widgets/gifting_boutique_card.dart';

class SingleCampaignBentoCard extends ConsumerWidget {
  final CampaignCardType type;

  const SingleCampaignBentoCard({
    super.key,
    required this.type,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(campaignBentoProvider);
    if (!config.enabled) return const SizedBox.shrink();

    final hub = ref.watch(currentStoreHubProvider);
    CampaignBentoCardConfig? card;
    for (final c in config.cards) {
      if (c.type == type && c.isVisibleForHub(hub.id)) {
        card = c;
        break;
      }
    }

    if (card == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: buildCardWidget(card),
    );
  }

  static Widget buildCardWidget(CampaignBentoCardConfig card) {
    switch (card.type) {
      case CampaignCardType.seasonalSwitchUp:
        return SeasonalSwitchUpCard(card: card);
      case CampaignCardType.freshMarket:
        return FreshMarketCard(card: card);
      case CampaignCardType.dailyRestock:
        return DailyRestockCard(card: card);
      case CampaignCardType.valuePicks:
        return ValuePicksCard(card: card);
      case CampaignCardType.giftingBoutique:
        return GiftingBoutiqueCard(card: card);
      case CampaignCardType.movieNight:
      case CampaignCardType.breakfastClub:
        return const SizedBox.shrink();
      case CampaignCardType.custom:
        return FreshMarketCard(card: card);
    }
  }
}

class CampaignBentoZone extends ConsumerWidget {
  final bool showLiveEditButton;

  const CampaignBentoZone({
    super.key,
    this.showLiveEditButton = false,
  });

  Widget _buildCard(CampaignBentoCardConfig card) {
    return SingleCampaignBentoCard.buildCardWidget(card);
  }

  void _openLiveCustomizer(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BentoLiveCustomizerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(campaignBentoProvider);
    if (!config.enabled) return const SizedBox.shrink();

    final hub = ref.watch(currentStoreHubProvider);
    final activeCards = config.cards
        .where((c) =>
            c.isVisibleForHub(hub.id) &&
            c.type != CampaignCardType.movieNight &&
            c.type != CampaignCardType.breakfastClub)
        .toList();
    activeCards.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (activeCards.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showLiveEditButton) ...[
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Customize campaigns',
                icon: const Icon(Icons.tune_rounded),
                onPressed: () => _openLiveCustomizer(context, ref),
              ),
            ),
            const SizedBox(height: 8),
          ],
          for (final card in activeCards) ...[
            _buildCard(card),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

/// Live on-device customizer sheet allowing full in-app editing
class _BentoLiveCustomizerSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_BentoLiveCustomizerSheet> createState() =>
      _BentoLiveCustomizerSheetState();
}

class _BentoLiveCustomizerSheetState
    extends ConsumerState<_BentoLiveCustomizerSheet> {
  @override
  Widget build(BuildContext context) {
    final config = ref.watch(campaignBentoProvider);
    final notifier = ref.read(campaignBentoProvider.notifier);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Campaign Bento Customizer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Edit card titles, badges, and toggle visibility',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: config.cards.length,
              itemBuilder: (context, index) {
                final card = config.cards[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: card.accentColor.withValues(alpha: 0.15),
                      child: Text(
                        card.badge.isNotEmpty ? card.badge : '${index + 1}',
                        style: TextStyle(
                          color: card.accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(card.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${card.items.length} items • ${card.type.name}'),
                    trailing: Switch(
                      value: card.enabled,
                      activeThumbColor: const Color(0xFF15803D),
                      onChanged: (val) {
                        notifier.toggleCard(card.id, val);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    notifier.resetToDefaults();
                    Navigator.pop(context);
                  },
                  child: const Text('Reset Defaults'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
