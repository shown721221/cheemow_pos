import '../config/constants.dart';

/// 計算付款相關衍生狀態，集中邏輯以便測試 / 後續擴充。
class PaymentComputeResult {
  final int effectivePaid; // 實際視為「付了多少」(現金未輸入=剛好 total)
  final int change; // 找零 (僅現金)
  final bool canConfirm; // 是否允許確認按鈕
  const PaymentComputeResult({
    required this.effectivePaid,
    required this.change,
    required this.canConfirm,
  });
}

class PaymentCompute {
  /// rawInput: 使用者 TextField 目前內容（僅數字或空字串）
  static PaymentComputeResult evaluate({
    required String method,
    required int totalAmount,
    required String rawInput,
  }) {
    final trimmed = rawInput.trim();
    final paidRaw = int.tryParse(trimmed) ?? 0;
    final bool isCash = method == PaymentMethods.cash;

    final effectivePaid = (isCash && trimmed.isEmpty) ? totalAmount : paidRaw;
    final change = isCash ? (effectivePaid - totalAmount) : 0;
    final canConfirm = isCash
        ? (trimmed.isEmpty || paidRaw >= totalAmount)
        : true;

    return PaymentComputeResult(
      effectivePaid: effectivePaid,
      change: change,
      canConfirm: canConfirm,
    );
  }
}
