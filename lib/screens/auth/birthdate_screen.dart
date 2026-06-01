import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/app_routes.dart';

class BirthdateScreen extends StatefulWidget {
  const BirthdateScreen({super.key});

  @override
  State<BirthdateScreen> createState() => _BirthdateScreenState();
}

class _BirthdateScreenState extends State<BirthdateScreen> {
  DateTime? _selectedDate;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1950),
      lastDate: now,
    );

    if (picked == null) {
      return;
    }

    setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = _selectedDate;

    return Scaffold(
      appBar: AppBar(title: const Text('Nhập ngày sinh')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const Text(
              'Thông tin ngày sinh được dùng để xác minh độ tuổi khi đặt phim có giới hạn.',
              style: TextStyle(color: Color(0xFF475569)),
            ),
            const SizedBox(height: 22),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  selectedDate == null
                      ? 'Chọn ngày sinh'
                      : '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: selectedDate == null
                    ? null
                    : () async {
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        final messenger = ScaffoldMessenger.maybeOf(context);
                        final navigator = Navigator.of(context);

                        try {
                          await authProvider.saveBirthDate(selectedDate);
                        } catch (_) {
                          if (!mounted) {
                            return;
                          }
                          messenger?.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Không lưu được ngày sinh. Vui lòng thử lại.',
                              ),
                            ),
                          );
                          return;
                        }

                        if (!mounted) {
                          return;
                        }

                        if (navigator.canPop()) {
                          navigator.pop(true);
                          return;
                        }

                        navigator.pushReplacementNamed(AppRoutes.movieList);
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Lưu và tiếp tục'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
