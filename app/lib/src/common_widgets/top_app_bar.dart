import 'package:flutter/material.dart';

// Fixed color for top bars - same in light and dark theme
const Color _topBarColor = Color(0xFF1E3A5F);
const Color _topBarTextColor = Colors.white;

class TopAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  
  const TopAppBar({
    super.key,
    this.title = 'Archipelago',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _topBarColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
          tooltip: 'Menu',
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Image.asset(
                'assets/images/translate_icon.png',
                height: 28,
                width: 28,
              ),
            ),
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: _topBarTextColor,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

