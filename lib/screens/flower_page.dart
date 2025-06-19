import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'channel_page.dart';
import 'package:web_app/models/channels.dart';

class FlowerPage extends StatefulWidget {
  const FlowerPage({super.key});

  @override
  State<FlowerPage> createState() => _FlowerPageState();
}

class _FlowerPageState extends State<FlowerPage> {
  @override
  void initState() {
    super.initState();
    // Delay navigation, so FlowerPage is visible before ChannelPage appears.
    Timer(const Duration(seconds: 1), _navigateToDefaultChannel);
  }

  Future<void> _navigateToDefaultChannel() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('channels')
        .where('approved', isEqualTo: true)
        .limit(1)
        .get();

    Channel defaultChannel;
    if (snapshot.docs.isNotEmpty) {
      defaultChannel = Channel.fromFirestore(snapshot.docs.first);
    } else {
      defaultChannel =
          Channel(id: 'fallback', approved: false, name: 'Default Channel');
    }

    // Navigate to the ChannelPage with the default channel
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) => ChannelPage(
            selectedChannel: defaultChannel,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBE4DF),
      body: Center(
        child: Image.asset('assets/flower.png', height: 300),
      ),
    );
  }
}
