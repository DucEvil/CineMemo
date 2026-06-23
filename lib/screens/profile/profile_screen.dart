import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_provider.dart';
import '../../providers/movie_provider.dart';
import '../../providers/review_provider.dart';
import '../../services/firebase/firebase_storage_service.dart';
import '../../utils/app_routes.dart';
import '../../widgets/common/custom_bottom_nav_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _uploadingAvatar = false;

  static final Uri _zohoFormUri = Uri.parse(
    'https://nhom6ca4.zoholandingpage.com/form-feedback/',
  );

  Future<void> _openZohoForm(BuildContext context) async {
    final opened = await launchUrl(
      _zohoFormUri,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được form phản hồi.')),
      );
    }
  }

  String _formatBirthDate(DateTime? date) {
    if (date == null) {
      return 'Chưa cập nhật';
    }
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _buildInitials(String displayName) {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'U';
    }
    if (parts.length == 1) {
      final value = parts.first;
      return value.substring(0, value.length > 1 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _avatarFallback(String initials) {
    return Container(
      width: 76,
      height: 76,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(38),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(AuthProvider auth) {
    final photoUrl = auth.photoUrl.trim();
    final fallback = _avatarFallback(_buildInitials(auth.displayName));

    if (photoUrl.isEmpty) {
      return fallback;
    }

    return ClipOval(
      child: Image.network(
        photoUrl,
        width: 76,
        height: 76,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stackTrace) => fallback,
      ),
    );
  }

  Future<void> _editDisplayName(BuildContext context, AuthProvider auth) async {
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để chỉnh sửa tên.')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    var draftName = auth.displayName == 'Guest' ? '' : auth.displayName;

    final nextName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Chỉnh sửa tên hiển thị'),
          content: Form(
            key: formKey,
            child: TextFormField(
              initialValue: draftName,
              textInputAction: TextInputAction.done,
              maxLength: 50,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Tên hiển thị',
                hintText: 'Nhập tên bạn muốn dùng',
              ),
              validator: (value) {
                final normalized = (value ?? '').trim();
                if (normalized.isEmpty) {
                  return 'Vui lòng nhập tên hiển thị.';
                }
                return null;
              },
              onChanged: (value) {
                draftName = value;
              },
              onFieldSubmitted: (_) {
                final valid = formKey.currentState?.validate() ?? false;
                if (!valid) {
                  return;
                }
                Navigator.of(dialogContext).pop(draftName.trim());
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final valid = formKey.currentState?.validate() ?? false;
                if (!valid) {
                  return;
                }
                Navigator.of(dialogContext).pop(draftName.trim());
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );

    if (nextName == null || nextName.trim().isEmpty) {
      return;
    }

    // Wait one frame so the dialog route teardown completes before provider updates.
    await Future<void>.delayed(Duration.zero);
    if (!context.mounted) {
      return;
    }

    final success = await auth.updateDisplayName(nextName);
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Đã cập nhật tên hiển thị.'
              : (auth.error ?? 'Không thể cập nhật tên hiển thị.'),
        ),
      ),
    );
  }

  Future<ImageSource?> _pickAvatarSource(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Chụp ảnh bằng camera'),
                onTap: () {
                  Navigator.of(sheetContext).pop(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Chọn từ thư viện'),
                onTap: () {
                  Navigator.of(sheetContext).pop(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _changeAvatar(BuildContext context, AuthProvider auth) async {
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để cập nhật ảnh đại diện.'),
        ),
      );
      return;
    }

    final selectedSource = await _pickAvatarSource(context);
    if (selectedSource == null || !context.mounted) {
      return;
    }

    final file = await _imagePicker.pickImage(
      source: selectedSource,
      imageQuality: 85,
    );
    if (file == null || !context.mounted) {
      return;
    }

    final storageService = Provider.of<FirebaseStorageService>(
      context,
      listen: false,
    );

    setState(() => _uploadingAvatar = true);
    try {
      try {
        final uploadedUrl = await storageService.uploadFile(
          folder: 'cinememo/avatars',
          file: file,
          ownerUid: auth.uid,
        );

        if (!context.mounted) {
          return;
        }

        if (uploadedUrl == null || uploadedUrl.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload ảnh thất bại. Vui lòng thử lại.'),
            ),
          );
          return;
        }

        final success = await auth.updatePhotoUrl(uploadedUrl);
        if (!context.mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Đã cập nhật ảnh đại diện.'
                  : (auth.error ?? 'Không thể cập nhật ảnh đại diện.'),
            ),
          ),
        );
      } catch (error, st) {
        // log and show user-friendly message
        // ignore: avoid_print
        print('Avatar upload error: $error\n$st');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi upload ảnh: ${error.toString()}')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
      }
    }
  }

  Future<void> _editBirthDate(BuildContext context, AuthProvider auth) async {
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để chỉnh sửa tuổi.')),
      );
      return;
    }

    final now = DateTime.now();
    final currentBirthDate = auth.birthDate;
    final initialDate =
        currentBirthDate ?? DateTime(now.year - 18, now.month, now.day);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: 'Chỉnh sửa ngày sinh',
    );

    if (pickedDate == null) {
      return;
    }

    await auth.saveBirthDate(pickedDate);
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã cập nhật độ tuổi xác minh.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isUpdatingProfile = auth.isLoading || _uploadingAvatar;

    if (!auth.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tài khoản')),
        body: Center(
          child: SizedBox(
            width: 220,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.login);
              },
              icon: const Icon(Icons.login_rounded),
              label: const Text('Đăng nhập'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        bottomNavigationBar: const CustomBottomNavBar(currentIndex: 3),
      );
    }

    final reviewProvider = Provider.of<ReviewProvider>(context);
    final movieProvider = Provider.of<MovieProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _buildProfileAvatar(auth),
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            elevation: 2,
                            child: IconButton(
                              onPressed: isUpdatingProfile
                                  ? null
                                  : () => _changeAvatar(context, auth),
                              icon: _uploadingAvatar
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.camera_alt_rounded),
                              tooltip: 'Đổi ảnh đại diện',
                              iconSize: 18,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          if (auth.email.isNotEmpty)
                            Text(
                              auth.email,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Số nhật ký: ${reviewProvider.reviewCount}'),
                Row(
                  children: [
                    Expanded(child: Text('Tên hiển thị: ${auth.displayName}')),
                    TextButton.icon(
                      onPressed: isUpdatingProfile
                          ? null
                          : () => _editDisplayName(context, auth),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Đổi tên'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ngày sinh: ${_formatBirthDate(auth.birthDate)}',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: isUpdatingProfile
                          ? null
                          : () => _editBirthDate(context, auth),
                      icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                      label: const Text('Chỉnh sửa'),
                    ),
                  ],
                ),
                Text(
                  'Độ tuổi xác minh: ${auth.age?.toString() ?? 'Chưa cập nhật'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            leading: const Icon(Icons.history_rounded),
            title: const Text('Lịch sử đặt chỗ'),
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.booking,
              arguments: {'historyOnly': true},
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            leading: const Icon(
              Icons.favorite_rounded,
              color: Color(0xFFF43F5E),
            ),
            title: Text('Danh sách yêu thích (${movieProvider.favoriteCount})'),
            subtitle: const Text('Nhấn để xem tất cả phim yêu thích'),
            onTap: () => Navigator.pushNamed(context, AppRoutes.favorites),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            leading: const Icon(Icons.auto_stories_rounded),
            title: Text('Nhật ký của tôi (${reviewProvider.reviewCount})'),
            subtitle: const Text('Sửa, xóa và quản lý nhật ký cá nhân'),
            onTap: () => Navigator.pushNamed(context, AppRoutes.myReviews),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            leading: const Icon(Icons.insights_rounded),
            title: const Text('Xem thống kê cá nhân'),
            subtitle: const Text('Đánh giá, rạp hay xem và phim đã xem'),
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.personalStatistics),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            leading: const Icon(Icons.admin_panel_settings_rounded),
            title: const Text('Admin và seed dữ liệu'),
            onTap: () => Navigator.pushNamed(context, AppRoutes.adminDashboard),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            leading: const Icon(Icons.smart_toy_rounded),
            title: const Text('Gemini / Dịch thuật AI'),
            subtitle: const Text(
              'Gửi yêu cầu AI qua Cloud Firestore extension',
            ),
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.geminiTranslation),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            leading: const Icon(Icons.description_rounded),
            title: const Text('Gửi phản hồi (Zoho Form)'),
            subtitle: const Text('Mở form góp ý trong tab mới'),
            onTap: () => _openZohoForm(context),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Đăng xuất'),
            onTap: () async {
              await Provider.of<AuthProvider>(context, listen: false).signOut();
              if (context.mounted) {
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 3),
    );
  }
}
