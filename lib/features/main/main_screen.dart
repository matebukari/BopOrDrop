import 'package:flutter/material.dart';
import '../discover/discover_screen.dart';
import '../profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Start on the Discover tab (Index 1) by default
  int _selectedIndex = 1;

  // The 4 screens that map to the 4 tabs
  final List<Widget> _screens = [
    const Center(
      child: Text('Home Screen\n(Coming Soon)', 
      textAlign: TextAlign.center, 
      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
      
    const DiscoverScreen(),
    
    const Center(
      child: Text('Library Screen\n(Coming Soon)', 
      textAlign: TextAlign.center, 
      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
      
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      // Display the currently selected screen
      body: _screens[_selectedIndex],
      
      // The Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white24, width: 0.5), // Subtle top border
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: const Color(0xFF121212), // Match the dark theme
          selectedItemColor: Colors.greenAccent[400], // Spotify/Bop green for active tab
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed, // Forces all 4 labels to show
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.style_outlined),
              activeIcon: Icon(Icons.style),
              label: 'Discover',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.library_music_outlined),
              activeIcon: Icon(Icons.library_music),
              label: 'Library',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}