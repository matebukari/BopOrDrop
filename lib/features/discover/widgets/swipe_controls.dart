import 'package:flutter/material.dart';

class SwipeControls extends StatelessWidget{
  final VoidCallback onDrop;
  final VoidCallback onBop;
  final VoidCallback onPlayPause;
  final VoidCallback onUndo;
  final bool isPlaying;

  const SwipeControls({
    super.key,
    required this.onDrop,
    required this.onBop,
    required this.onPlayPause,
    required this.isPlaying,
    required this.onUndo
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          onPressed: onUndo,
          icon: const Icon(Icons.replay, color: Colors.orangeAccent),
          iconSize: 32,
        ),
        FloatingActionButton(
          heroTag: 'drop',
          onPressed: onDrop,
          backgroundColor: Colors.redAccent,
          child: const Icon(
            Icons.close,
            size: 30,
            color: Colors.white,
          ),
        ),
        FloatingActionButton(
          heroTag: 'play_pause',
          onPressed: onPlayPause,
          backgroundColor: Colors.white,
          child: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            size: 35,
            color: Colors.black,
          ),
        ),
        FloatingActionButton(
          heroTag: 'bop',
          onPressed: onBop,
          backgroundColor: Colors.greenAccent[400],
          child: const Icon(
            Icons.favorite,
            size: 30,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}