import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../config/voucher_catalog.dart';
import '../../models/movie_model.dart';
import '../../utils/app_routes.dart';

class _ComboOption {
  const _ComboOption({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.icon,
  });

  final String id;
  final String name;
  final String description;
  final double price;
  final IconData icon;
}

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const List<_ComboOption> _comboOptions = [
    _ComboOption(
      id: 'comboSolo',
      name: 'Combo Solo',
      description: '1 bắp vừa + 1 nước ngọt',
      price: 69000,
      icon: Icons.local_drink_rounded,
    ),
    _ComboOption(
      id: 'comboDouble',
      name: 'Combo Couple',
      description: '1 bắp lớn + 2 nước ngọt',
      price: 119000,
      icon: Icons.local_bar_rounded,
    ),
    _ComboOption(
      id: 'comboFamily',
      name: 'Combo Family',
      description: '2 bắp lớn + 4 nước ngọt',
      price: 209000,
      icon: Icons.groups_2_rounded,
    ),
  ];

  final TextEditingController _voucherController = TextEditingController();
  final Map<String, int> _comboQuantities = {
    for (final combo in _comboOptions) combo.id: 0,
  };

  VoucherOffer? _appliedVoucher;
  String? _voucherStatus;
  bool _voucherStatusIsError = false;

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  void _changeComboQuantity(String comboId, int delta) {
    final current = _comboQuantities[comboId] ?? 0;
    setState(() {
      _comboQuantities[comboId] = math.max(0, current + delta);
      _voucherStatus = null;
      _voucherStatusIsError = false;
    });
  }

  double _comboTotal() {
    var total = 0.0;
    for (final combo in _comboOptions) {
      final qty = _comboQuantities[combo.id] ?? 0;
      total += combo.price * qty;
    }
    return total;
  }

  List<Map<String, dynamic>> _selectedComboItems() {
    final result = <Map<String, dynamic>>[];
    for (final combo in _comboOptions) {
      final qty = _comboQuantities[combo.id] ?? 0;
      if (qty <= 0) {
        continue;
      }
      result.add({
        'id': combo.id,
        'name': combo.name,
        'description': combo.description,
        'quantity': qty,
        'unitPrice': combo.price,
        'totalPrice': combo.price * qty,
      });
    }
    return result;
  }

  double _discountAmount(double subtotal) {
    final voucher = _appliedVoucher;
    if (voucher == null) {
      return 0;
    }
    return voucher.discountFor(subtotal).clamp(0, subtotal).toDouble();
  }

  void _applyVoucher(double subtotal) {
    final code = _voucherController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _appliedVoucher = null;
        _voucherStatus = 'Vui lòng nhập mã ưu đãi.';
        _voucherStatusIsError = true;
      });
      return;
    }

    final matchedOffer = VoucherCatalog.findByCode(code);
    if (matchedOffer == null) {
      setState(() {
        _appliedVoucher = null;
        _voucherStatus = 'Mã ưu đãi không hợp lệ hoặc đã hết hạn.';
        _voucherStatusIsError = true;
      });
      return;
    }

    final discount = matchedOffer.discountFor(subtotal);
    if (discount <= 0) {
      setState(() {
        _appliedVoucher = matchedOffer;
        _voucherStatus =
            'Đơn hàng chưa đạt mức tối thiểu ${_formatVnd(matchedOffer.minimumOrder)} để áp dụng mã.';
        _voucherStatusIsError = true;
      });
      return;
    }

    setState(() {
      _appliedVoucher = matchedOffer;
      _voucherStatus = 'Áp dụng mã ${matchedOffer.code} thành công.';
      _voucherStatusIsError = false;
    });
  }

  void _clearVoucher() {
    setState(() {
      _appliedVoucher = null;
      _voucherController.clear();
      _voucherStatus = 'Đã bỏ mã ưu đãi.';
      _voucherStatusIsError = false;
    });
  }

  static String _formatVnd(double value) {
    final integer = value.round().toString();
    final withSeparator = integer.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
    return '$withSeparator VND';
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map<String, dynamic>) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thanh toán')),
        body: const Center(child: Text('Thiếu dữ liệu thanh toán.')),
      );
    }

    final movie = args['movie'] as MovieModel?;
    final showtimeLabel = args['showtimeLabel'] as String? ?? '--:--';
    final selectedSeats =
        (args['selectedSeats'] as List?)?.whereType<String>().toList() ??
        const [];
    final seatTotal = (args['totalPrice'] as num?)?.toDouble() ?? 0;

    final comboTotal = _comboTotal();
    final selectedComboItems = _selectedComboItems();
    final subTotal = seatTotal + comboTotal;
    final discount = _discountAmount(subTotal);
    final payableTotal = (subTotal - discount)
        .clamp(0, double.infinity)
        .toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán MoMo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movie?.title ?? 'Phim',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Suất chiếu: $showtimeLabel'),
                        const SizedBox(height: 4),
                        Text(
                          'Ghế: ${selectedSeats.isEmpty ? 'Chưa chọn' : selectedSeats.join(', ')}',
                        ),
                        const SizedBox(height: 10),
                        const _SectionLabel('Chi tiết thanh toán'),
                        const SizedBox(height: 6),
                        _SummaryLine(
                          label: 'Tiền ghế',
                          value: _formatVnd(seatTotal),
                        ),
                        _SummaryLine(
                          label: 'Combo bắp nước',
                          value: _formatVnd(comboTotal),
                        ),
                        _SummaryLine(
                          label: 'Giảm giá voucher',
                          value: '- ${_formatVnd(discount)}',
                          valueColor: const Color(0xFF16A34A),
                        ),
                        const Divider(height: 24),
                        _SummaryLine(
                          label: 'Tổng thanh toán',
                          value: _formatVnd(payableTotal),
                          emphasize: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _SectionLabel('Chọn combo bắp nước'),
                  const SizedBox(height: 8),
                  ..._comboOptions.map((combo) {
                    final quantity = _comboQuantities[combo.id] ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(combo.icon, color: const Color(0xFFE11D48)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  combo.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  combo.description,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatVnd(combo.price),
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: quantity == 0
                                    ? null
                                    : () => _changeComboQuantity(combo.id, -1),
                              ),
                              Text(
                                '$quantity',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () =>
                                    _changeComboQuantity(combo.id, 1),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  const _SectionLabel('Mã voucher ưu đãi'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _voucherController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: 'Ví dụ: HELLO30',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onSubmitted: (_) => _applyVoucher(subTotal),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _applyVoucher(subTotal),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Áp dụng'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: VoucherCatalog.vouchers
                        .map((offer) => Chip(label: Text(offer.code)))
                        .toList(),
                  ),
                  if (_appliedVoucher != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_appliedVoucher!.title}: ${_appliedVoucher!.subtitle}',
                              style: const TextStyle(
                                color: Color(0xFF334155),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _clearVoucher,
                            child: const Text('Bỏ mã'),
                          ),
                        ],
                      ),
                    ),
                  if (_voucherStatus != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _voucherStatus!,
                        style: TextStyle(
                          color: _voucherStatusIsError
                              ? const Color(0xFFB91C1C)
                              : const Color(0xFF166534),
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.momoQrPayment,
                    arguments: {
                      ...args,
                      'payableTotal': payableTotal,
                      'movieTitle': movie?.title ?? 'Phim',
                      'movieDuration': movie?.duration ?? 0,
                      'comboItems': selectedComboItems,
                      'comboTotal': comboTotal,
                      'ticketCount': selectedSeats.length,
                    },
                  );
                },
                icon: const Icon(Icons.qr_code_2_rounded),
                label: Text(
                  '${AppConfig.useMomoPersonalQrMode ? 'Thanh toán MoMo cá nhân' : 'Thanh toán MoMo Sandbox'} (${_formatVnd(payableTotal)})',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
      fontSize: emphasize ? 17 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: style.copyWith(color: const Color(0xFF334155)),
            ),
          ),
          Text(
            value,
            style: style.copyWith(color: valueColor ?? const Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }
}
