import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/services/logger_service.dart';

class ReferralInfo {
  final String referralCode;
  final String shareLink;
  final String whatsappShareText;
  final double referrerReward;
  final double refereeDiscount;
  final double minOrderValue;
  final bool isEnabled;

  ReferralInfo({
    required this.referralCode,
    required this.shareLink,
    required this.whatsappShareText,
    required this.referrerReward,
    required this.refereeDiscount,
    required this.minOrderValue,
    required this.isEnabled,
  });

  factory ReferralInfo.fromJson(Map<String, dynamic> json) {
    return ReferralInfo(
      referralCode: json['referralCode']?.toString() ?? '',
      shareLink: json['shareLink']?.toString() ?? 'https://fastkirana.in',
      whatsappShareText: json['whatsappShareText']?.toString() ?? '',
      referrerReward: (json['referrerReward'] as num?)?.toDouble() ?? 100.0,
      refereeDiscount: (json['refereeDiscount'] as num?)?.toDouble() ?? 50.0,
      minOrderValue: (json['minOrderValue'] as num?)?.toDouble() ?? 199.0,
      isEnabled: json['isEnabled'] == true,
    );
  }
}

class ReferralStats {
  final int totalInvited;
  final int completedReferrals;
  final double totalEarned;
  final List<Map<String, dynamic>> recentReferrals;

  ReferralStats({
    required this.totalInvited,
    required this.completedReferrals,
    required this.totalEarned,
    required this.recentReferrals,
  });

  factory ReferralStats.fromJson(Map<String, dynamic> json) {
    return ReferralStats(
      totalInvited: (json['totalInvited'] as num?)?.toInt() ?? 0,
      completedReferrals: (json['completedReferrals'] as num?)?.toInt() ?? 0,
      totalEarned: (json['totalEarned'] as num?)?.toDouble() ?? 0.0,
      recentReferrals: List<Map<String, dynamic>>.from(json['recentReferrals'] ?? []),
    );
  }
}

final referralInfoProvider = FutureProvider.autoDispose<ReferralInfo?>((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final response = await dio.get('/api/referral/my-code');
    if (response.statusCode == 200 && response.data['success'] == true) {
      return ReferralInfo.fromJson(response.data);
    }
  } catch (e) {
    LoggerService.error('Error fetching referral info', e);
  }
  return null;
});

final referralStatsProvider = FutureProvider.autoDispose<ReferralStats?>((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final response = await dio.get('/api/referral/stats');
    if (response.statusCode == 200 && response.data['success'] == true) {
      return ReferralStats.fromJson(response.data);
    }
  } catch (e) {
    LoggerService.error('Error fetching referral stats', e);
  }
  return null;
});
