enum PaymentMethod { cash, transfer, linePay }

extension PaymentMethodX on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return '現金';
      case PaymentMethod.transfer:
        return '轉帳';
      case PaymentMethod.linePay:
        return 'LinePay';
    }
  }

  String get code {
    switch (this) {
      case PaymentMethod.cash:
        return '1';
      case PaymentMethod.transfer:
        return '2';
      case PaymentMethod.linePay:
        return '3';
    }
  }

  static PaymentMethod fromLabel(String label) {
    switch (label) {
      case '現金':
        return PaymentMethod.cash;
      case '轉帳':
        return PaymentMethod.transfer;
      case 'LinePay':
        return PaymentMethod.linePay;
      default:
        throw ArgumentError('未知付款方式: $label');
    }
  }
}
