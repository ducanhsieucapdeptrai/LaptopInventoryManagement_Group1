import 'package:flutter/material.dart';

final GlobalKey<ScaffoldState> shellScaffoldKey = GlobalKey<ScaffoldState>();

class DrawerMenuButton extends StatelessWidget {
  const DrawerMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu),
      tooltip: 'Menu phân hệ & 7 chức năng',
      onPressed: () => shellScaffoldKey.currentState?.openDrawer(),
    );
  }
}
