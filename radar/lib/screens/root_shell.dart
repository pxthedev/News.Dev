import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../widgets/system.dart';
import '../state/app_state.dart';
import 'account_screen.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'saved_screen.dart';

/// Estrutura do app: 4 abas + tab bar flutuante com fade atrás.
class RootShell extends StatefulWidget {
  const RootShell({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  late int _index = widget.initialIndex;

  void _select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    if (!AppScope.of(context).isAccount) return const AccountScreen();
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: IndexedStack(
                index: _index,
                children: const [
                  HomeScreen(),
                  ExploreScreen(),
                  SavedScreen(),
                  ProfileScreen(),
                ],
              ),
            ),
          ),
          const Positioned(left: 0, right: 0, bottom: 0, child: BottomFade()),
          Positioned(
            left: RSpace.screen,
            right: RSpace.screen,
            bottom: math.max(bottom - 6, 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: FloatingTabBar(index: _index, onTap: _select),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
