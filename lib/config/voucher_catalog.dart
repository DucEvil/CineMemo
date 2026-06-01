import 'package:flutter/foundation.dart';

@immutable
class VoucherOffer {
  const VoucherOffer({
    required this.title,
    required this.subtitle,
    required this.code,
    required this.imageUrl,
    required this.expiryDateText,
    required this.condition,
    this.percentDiscount,
    this.fixedDiscount,
    this.minimumOrder = 0,
    this.maxDiscount,
  }) : assert(
         (percentDiscount != null) != (fixedDiscount != null),
         'Provide either percentDiscount or fixedDiscount.',
       );

  final String title;
  final String subtitle;
  final String code;
  final String imageUrl;
  final String expiryDateText;
  final String condition;
  final double? percentDiscount;
  final double? fixedDiscount;
  final double minimumOrder;
  final double? maxDiscount;

  double discountFor(double subtotal) {
    if (subtotal < minimumOrder) {
      return 0;
    }

    final discount = percentDiscount != null
        ? subtotal * percentDiscount!
        : (fixedDiscount ?? 0);

    if (maxDiscount != null && discount > maxDiscount!) {
      return maxDiscount!;
    }

    return discount;
  }
}

class VoucherCatalog {
  const VoucherCatalog._();

  static const List<VoucherOffer> vouchers = [
    VoucherOffer(
      title: 'Mua 1 tặng 1',
      subtitle: 'Giảm mạnh cho đơn vé online',
      code: 'WED2X',
      imageUrl:
          'https://images.unsplash.com/photo-1596727147705-61a532a659bd?auto=format&fit=crop&w=800&q=80',
      expiryDateText: '30/06/2026',
      condition: 'Áp dụng cho đơn từ 120.000 VND; không cộng dồn mã khác.',
      percentDiscount: 0.5,
      minimumOrder: 120000,
      maxDiscount: 120000,
    ),
    VoucherOffer(
      title: 'Combo tiết kiệm 39K',
      subtitle: 'Bỏng lớn + 2 nước cho mỗi suất tối',
      code: 'COMBO39',
      imageUrl:
          'https://images.unsplash.com/photo-1578849278619-e73505e9610f?auto=format&fit=crop&w=800&q=80',
      expiryDateText: '15/07/2026',
      condition: 'Áp dụng cho đơn từ 150.000 VND; dùng được cả vé và combo.',
      fixedDiscount: 39000,
      minimumOrder: 150000,
    ),
    VoucherOffer(
      title: 'Giảm 30% vé đầu',
      subtitle: 'Cho tài khoản mới xác thực số điện thoại',
      code: 'HELLO30',
      imageUrl:
          'https://images.unsplash.com/photo-1536440136628-849c177e76a1?auto=format&fit=crop&w=800&q=80',
      expiryDateText: '31/12/2026',
      condition: 'Áp dụng cho đơn từ 100.000 VND; không cộng dồn mã khác.',
      percentDiscount: 0.3,
      minimumOrder: 100000,
      maxDiscount: 90000,
    ),
  ];

  static VoucherOffer? findByCode(String rawCode) {
    final code = rawCode.trim().toUpperCase();
    for (final voucher in vouchers) {
      if (voucher.code.toUpperCase() == code) {
        return voucher;
      }
    }
    return null;
  }
}
