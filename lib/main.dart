import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:web_app/screens/revive_and_thrive.dart';
import 'package:web_app/screens/flower_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    if (kIsWeb) {
      // print("Configuring Firebase for Web...");
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: "AIzaSyAINPzGAKqhAFtpNkfcAf7wr_k7acD11q0",
          authDomain: "revive-and-thrive-1d7e4.firebaseapp.com",
          projectId: "revive-and-thrive-1d7e4",
          storageBucket: "revive-and-thrive-1d7e4.firebasestorage.app",
          messagingSenderId: "577535068852",
          appId: "1:577535068852:web:359cd68415c3d832eb25e1",
        ),
      );
      // print("Firebase for Web initialized successfully");
    } else {
      // print("Initializing Firebase for non-web platform");
      await Firebase.initializeApp();
      // print("Firebase initialized for non-web platform");
    }
  }

  // Check current auth state
  FirebaseAuth.instance.authStateChanges().listen((User? user) {
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Revive & Thrive',
      theme: ThemeData(
        primarySwatch: Colors.brown,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // print("DEBUG: StreamBuilder - Connection state: ${snapshot.connectionState}");

          if (snapshot.connectionState != ConnectionState.active) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // If a user is signed in, show FlowerPage which auto-navigates forward
          if (snapshot.hasData) {
            // print( "DEBUG: StreamBuilder - User is signed in, navigating to FlowerPage");
            return const FlowerPage();
          }
          // print("DEBUG: StreamBuilder - User not signed in, showing ReviveAndThrivePage");
          return const ReviveAndThrivePage();
        },
      ),
    );
  }
}