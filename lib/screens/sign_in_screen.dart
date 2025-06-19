import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:web_app/screens/flower_page.dart';
import 'package:geolocator/geolocator.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    // ////print("DEBUG: SignInScreen initialized");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBE4DF),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset('assets/web_logo2.png', height: 150),
              const SizedBox(height: 50),

              // Sign-in button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  minimumSize: const Size(250, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _isSigningIn
                    ? null
                    : () async {
                        setState(() {
                          _isSigningIn = true;
                        });

                        try {
                          User? user = await _signInWithGoogle();
                          if (user != null) {
                            //print("Sign-in successful, user: ${user.displayName}");
                          }
                        } catch (e) {
                          //print("Error during sign-in process: $e");
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Sign-in failed: $e")),
                          );
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isSigningIn = false;
                            });
                          }
                        }
                      },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/google_logo.png',
                      height: 24,
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Sign in with Google',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<User?> _signInWithGoogle() async {
    try {
      // Use Firebase Auth with popup for both web and non-web
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider
          .addScope('https://www.googleapis.com/auth/userinfo.profile');

      // Set custom parameters to force account selection
      googleProvider.setCustomParameters({
        'prompt': 'select_account' // Force account selection UI
      });

      // Use popup sign-in for both web and mobile
      final userCredential =
          await FirebaseAuth.instance.signInWithPopup(googleProvider);
      final user = userCredential.user;

      if (user != null) {
        print(
            "DEBUG: Sign-in successful - User: ${user.displayName}, Email: ${user.email}");
        await _createOrUpdateUserDocument(user);
        //print("DEBUG: User document created/updated in Firestore");

        // After successful sign-in, navigate to FlowerPage
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const FlowerPage()),
          );
        }
      } else {
        //print("DEBUG: Sign-in completed but user is null");
      }

      return user;
    } catch (e) {
      print('ERROR in _signInWithGoogle: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _createOrUpdateUserDocument(User user) async {
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    // Attempt to get the current location; on error fallback to (0.0, 0.0)
    GeoPoint userLocation;
    try {
      final position = await _determinePosition();
      userLocation = GeoPoint(position.latitude, position.longitude);
    } catch (e) {
      // Log the error or inform the user if needed
      userLocation = const GeoPoint(0.0, 0.0);
    }

    final userDoc = await userDocRef.get();
    if (!userDoc.exists) {
      await userDocRef.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'createdAt': FieldValue.serverTimestamp(),
        'ecoPoints': 0,
        'lastChannelRequestTime': null,
        'location': userLocation, // Ensure location is stored on creation
      });

      // Optionally create subcollections for carts, messages, etc.
      await userDocRef.collection('carts').doc('info').set({
        'created': FieldValue.serverTimestamp(),
      });
      await userDocRef.collection('messages').doc('info').set({
        'created': FieldValue.serverTimestamp(),
      });
    } else {
      await userDocRef.update({
        'displayName': user.displayName,
        'email': user.email,
        'lastLogin': FieldValue.serverTimestamp(),
        'location': userLocation, // Update location on every login
      });
    }
  }
}
