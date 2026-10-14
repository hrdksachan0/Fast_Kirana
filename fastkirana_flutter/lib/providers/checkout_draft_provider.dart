import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/checkout_draft.dart';
import '../data/models/address.dart';

class CheckoutDraftNotifier extends StateNotifier<CheckoutDraft> {
  CheckoutDraftNotifier() : super(const CheckoutDraft());

  void updateDeliveryMethod(String method) {
    if (state.isFrozenForPayment) return;
    state = state.copyWith(deliveryMethod: method);
  }

  void updateAddress(Address? address, int index) {
    if (state.isFrozenForPayment) return;
    state = state.copyWith(
      selectedAddress: address,
      selectedAddressIndex: index,
      clearAddress: address == null,
    );
  }

  void updateReceiverDetails({String? name, String? phone}) {
    if (state.isFrozenForPayment) return;
    state = state.copyWith(
      customReceiverName: name,
      customReceiverPhone: phone,
      clearReceiver: name == null && phone == null,
    );
  }

  void toggleDeliveryInstruction(String instructionId) {
    if (state.isFrozenForPayment) return;
    final updated = Set<String>.from(state.selectedDeliveryInstructions);
    if (updated.contains(instructionId)) {
      updated.remove(instructionId);
    } else {
      updated.add(instructionId);
    }
    state = state.copyWith(selectedDeliveryInstructions: updated);
  }

  void setDeliveryInstructions(Set<String> instructions) {
    if (state.isFrozenForPayment) return;
    state = state.copyWith(selectedDeliveryInstructions: instructions);
  }

  void updateCookingInstruction(String? instruction) {
    if (state.isFrozenForPayment) return;
    state = state.copyWith(cookingInstruction: instruction);
  }

  void updateCustomNotes(String? notes) {
    if (state.isFrozenForPayment) return;
    state = state.copyWith(customDeliveryNotes: notes);
  }

  void applyCoupon(String code, double discount) {
    if (state.isFrozenForPayment) return;
    state = state.copyWith(
      couponCode: code,
      discountAmount: discount,
    );
  }

  void removeCoupon() {
    if (state.isFrozenForPayment) return;
    state = state.copyWith(clearCoupon: true);
  }

  void setTipAmount(double tip) {
    if (state.isFrozenForPayment) return;
    state = state.copyWith(tipAmount: tip.clamp(0.0, 1000.0));
  }

  void updatePackaging(String packaging) {
    if (state.isFrozenForPayment) return;
    state = state.copyWith(selectedPackaging: packaging);
  }

  void updatePaymentMethod(String method) {
    if (state.isFrozenForPayment) return;
    state = state.copyWith(selectedPayment: method);
  }

  void freezeForPayment(String paymentSessionId) {
    state = state.copyWith(
      isFrozenForPayment: true,
      activePaymentSessionId: paymentSessionId,
    );
  }

  void unfreezePayment() {
    state = state.copyWith(
      isFrozenForPayment: false,
      clearPaymentSession: true,
    );
  }

  void resetAfterOrderPlaced() {
    state = const CheckoutDraft();
  }
}

final checkoutDraftProvider = StateNotifierProvider<CheckoutDraftNotifier, CheckoutDraft>((ref) {
  return CheckoutDraftNotifier();
});
