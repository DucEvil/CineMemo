import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../config/voucher_catalog.dart';

class VoucherListScreen extends StatelessWidget {
  const VoucherListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vouchers = VoucherCatalog.vouchers;

    return Scaffold(
      appBar: AppBar(title: const Text('Tất cả voucher')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final contentWidth = _contentWidthFor(width);
          final columnCount = _columnCountFor(width);

          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: contentWidth,
              child: columnCount > 1
                  ? GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: vouchers.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columnCount,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 310,
                      ),
                      itemBuilder: (context, index) =>
                          _VoucherDetailCard(voucher: vouchers[index]),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: vouchers.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _VoucherDetailCard(voucher: vouchers[index]),
                    ),
            ),
          );
        },
      ),
    );
  }

  double _contentWidthFor(double width) {
    if (width >= 1480) {
      return 1320;
    }
    if (width >= 1200) {
      return 1120;
    }
    return width;
  }

  int _columnCountFor(double width) {
    if (width >= 1280) {
      return 3;
    }
    if (width >= 860) {
      return 2;
    }
    return 1;
  }
}

class _VoucherDetailCard extends StatelessWidget {
  const _VoucherDetailCard({required this.voucher});

  final VoucherOffer voucher;

  static String _formatVnd(double value) {
    final integer = value.round().toString();
    final withSeparator = integer.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
    return '$withSeparator VND';
  }

  String _buildDiscountText() {
    if (voucher.percentDiscount != null) {
      final percent = (voucher.percentDiscount! * 100).round();
      final maxLabel = voucher.maxDiscount != null
          ? ' (tối đa ${_formatVnd(voucher.maxDiscount!)})'
          : '';
      return 'Ưu đãi: giảm $percent%$maxLabel';
    }

    return 'Ưu đãi: giảm ${_formatVnd(voucher.fixedDiscount ?? 0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 142,
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: voucher.imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) =>
                        const ColoredBox(color: Color(0xFFF1F5F9)),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C1A2B),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      voucher.code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voucher.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    voucher.subtitle,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.local_offer_rounded,
                    label: _buildDiscountText(),
                  ),
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: Icons.event_available_rounded,
                    label: 'Hết hạn: ${voucher.expiryDateText}',
                  ),
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: Icons.rule_rounded,
                    label: 'Điều kiện: ${voucher.condition}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: const Color(0xFF334155)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
