import 'package:flutter/material.dart';

import '../app_state.dart';
import 'about_screen.dart';
import 'mind_map_screen.dart';
import 'person_list_screen.dart';
import 'tree_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          PersonListScreen(state: widget.state),
          TreeScreen(state: widget.state),
          MindMapScreen(state: widget.state),
          const AboutScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people), label: 'الأفراد'),
          NavigationDestination(icon: Icon(Icons.account_tree), label: 'الشجرة'),
          NavigationDestination(icon: Icon(Icons.hub), label: 'الخريطة'),
          NavigationDestination(icon: Icon(Icons.info_outline), label: 'حول'),
        ],
      ),
    );
  }
}
