import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/services/logger_service.dart';
import '../data/models/user.dart';
import 'auth_provider.dart';

class WalletState {
  final double balance;
  final double promoBalance;
  final double totalUsable;
  final bool isLoading;
  final String? error;

  const WalletState({
    this.balance = 0.0,
    this.promoBalance = 0.0,
    this.totalUsable = 0.0,
    this.isLoading = false,
    this.error,
  });

  WalletState copyWith({
    double? balance,
    double? promoBalance,
    double? totalUsable,
    bool? isLoading,
    String? error,
  }) {
    return WalletState(
      balance: balance ?? this.balance,
      promoBalance: promoBalance ?? this.promoBalance,
      totalUsable: totalUsable ?? this.totalUsable,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class WalletTransactionItem {
  final String id;
  final double amount;
  final String type;
  final String status;
  final String description;
  final double balanceAfter;
  final String? createdAt;

  WalletTransactionItem({
    required this.id,
    required this.amount,
    required this.type,
    required this.status,
    required this.description,
    required this.balanceAfter,
    this.createdAt,
  });

  bool get isCredit => type.toUpperCase().startsWith('CREDIT');

  factory WalletTransactionItem.fromJson(Map<String, dynamic> json) {
    return WalletTransactionItem(
      id: json['id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      type: json['type']?.toString() ?? 'CREDIT_TOPUP',
      status: json['status']?.toString() ?? 'SUCCESS',
      description: json['description']?.toString() ?? 'Wallet Transaction',
      balanceAfter: (json['balanceAfter'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt']?.toString(),
    );
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  final Ref _ref;

  WalletNotifier(this._ref) : super(const WalletState()) {
    // Listen to authentication changes so wallet balance is NEVER leaked across accounts
    _ref.listen<AsyncValue<User?>>(authProvider, (previous, next) {
      final prevUser = previous?.value;
      final nextUser = next.value;

      if (nextUser == null) {
        // User logged out -> reset to empty state immediately
        reset();
      } else if (prevUser?.id != nextUser.id) {
        // Different user logged in -> reset and fetch balance for new account
        reset();
        fetchBalance();
      }
    });

    final currentUser = _ref.read(authProvider).value;
    if (currentUser != null) {
      fetchBalance();
    }
  }

  void reset() {
    state = const WalletState();
  }

  Future<void> fetchBalance() async {
    final currentUser = _ref.read(authProvider).value;
    if (currentUser == null) {
      reset();
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.get('/api/wallet/balance');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data;
        state = WalletState(
          balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
          promoBalance: (data['promoBalance'] as num?)?.toDouble() ?? 0.0,
          totalUsable: (data['totalUsable'] as num?)?.toDouble() ?? 0.0,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      LoggerService.error('Error fetching wallet balance', e);
      final user = _ref.read(authProvider).value;
      if (user == null) {
        reset();
      } else {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  Future<Map<String, dynamic>?> initiateTopup(double amount) async {
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.post('/api/wallet/topup/initiate', data: {
        'amount': amount,
      });
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      LoggerService.error('Error initiating wallet topup', e);
    }
    return null;
  }

  Future<bool> syncTopupStatus(String cfOrderId) async {
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.post('/api/wallet/topup/sync-status', data: {
        'cfOrderId': cfOrderId,
      });
      if (response.statusCode == 200 && response.data['success'] == true) {
        await fetchBalance();
        return response.data['status'] == 'SUCCESS';
      }
    } catch (e) {
      LoggerService.error('Error syncing topup status', e);
    }
    return false;
  }
}

final walletNotifierProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier(ref);
});

final walletTransactionsProvider = FutureProvider.autoDispose<List<WalletTransactionItem>>((ref) async {
  final user = ref.watch(authProvider).value;
  if (user == null) return [];

  final dio = ref.read(dioProvider);
  try {
    final response = await dio.get('/api/wallet/transactions');
    if (response.statusCode == 200 && response.data['success'] == true) {
      final list = response.data['transactions'] as List<dynamic>? ?? [];
      return list
          .map((item) => WalletTransactionItem.fromJson(item as Map<String, dynamic>))
          .where((item) => item.status.toUpperCase() == 'SUCCESS')
          .toList();
    }
  } catch (e) {
    LoggerService.error('Error fetching wallet transactions', e);
  }
  return [];
});
