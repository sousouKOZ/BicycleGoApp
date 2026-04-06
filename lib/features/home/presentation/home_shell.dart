import 'package:flutter/material.dart';
import '../../parking/presentation/parking_map_page.dart';
import '../../coupons/presentation/coupon_list_page.dart';
import '../../mypage/presentation/my_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ParkingMapPage(),
      const CouponListPage(),
      const MyPage(),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map), label: '地図'),
          NavigationDestination(
              icon: Icon(Icons.confirmation_number), label: 'クーポン'),
          NavigationDestination(icon: Icon(Icons.person), label: 'マイページ'),
        ],
      ),
    );
  }
}
