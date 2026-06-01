import 'package:flutter/material.dart';

import '../../utils/app_routes.dart';

class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({super.key, required this.currentIndex, this.onTap});

  final int currentIndex;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        if (onTap != null) {
          onTap!(index);
          return;
        }

        if (index == currentIndex) {
          return;
        }

        final route = switch (index) {
          0 => AppRoutes.movieList,
          1 => AppRoutes.booking,
          2 => AppRoutes.reviewList,
          3 => AppRoutes.profile,
          _ => null,
        };

        if (route != null) {
          Navigator.pushReplacementNamed(context, route);
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_rounded),
          label: 'Trang chủ',
        ),
        NavigationDestination(
          icon: Icon(Icons.confirmation_number_rounded),
          label: 'Vé của tôi',
        ),
        NavigationDestination(
          icon: Icon(Icons.auto_stories_rounded),
          label: 'Nhật ký',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_rounded),
          label: 'Tài khoản',
        ),
      ],
    );
  }
}
