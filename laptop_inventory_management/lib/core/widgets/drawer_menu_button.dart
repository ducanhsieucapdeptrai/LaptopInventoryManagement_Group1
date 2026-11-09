import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final GlobalKey<ScaffoldState> shellScaffoldKey = GlobalKey<ScaffoldState>();
final shellTabIndexProvider = StateProvider<int>((ref) => 0);

class DrawerMenuButton extends ConsumerWidget {
  const DrawerMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Nếu màn hình được mở qua Navigator.push -> Nút Back để pop về màn trước
    if (Navigator.canPop(context)) {
      return IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Quay lại',
        onPressed: () => Navigator.pop(context),
      );
    }

    // 2. Nếu đang ở các tab con (Tab > 0) -> Nút Back để quay về Trang chủ / Tổng quan (Tab 0)
    final currentTab = ref.watch(shellTabIndexProvider);
    if (currentTab > 0) {
      return IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Quay lại Trang chủ',
        onPressed: () {
          ref.read(shellTabIndexProvider.notifier).state = 0;
        },
      );
    }

    // 3. Nếu đang ở Trang chủ (Tab 0) -> Nút Menu để mở Drawer
    return IconButton(
      icon: const Icon(Icons.menu),
      tooltip: 'Menu phân hệ & Chức năng',
      onPressed: () => shellScaffoldKey.currentState?.openDrawer(),
    );
  }
}
