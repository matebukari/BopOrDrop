import 'package:flutter/material.dart';

class DroppedScreen extends StatelessWidget {
  const DroppedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Dropped Music', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: const Center(
        child: Text(
          'Fetching your Dropped music...',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      ),
    );
  }
}