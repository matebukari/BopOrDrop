import 'package:flutter/material.dart';

class EmptyDeckView extends StatelessWidget {
  const EmptyDeckView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.greenAccent[400]),
          const SizedBox(height: 20),
          const Text(
            "You're all caught up!", 
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            "Check back later for more music.", 
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
        ],
      ),
    );
  }
}