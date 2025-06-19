import 'package:flutter/material.dart';
import 'package:web_app/screens/sign_in_screen.dart'; // Make sure this import exists

class ReviveAndThrivePage extends StatelessWidget {
  const ReviveAndThrivePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBE4DF), // Light beige background color
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(80, 100, 0, 50),
              child: Image.asset('assets/web_logo2.png',
                  height: 300), // Replace with your logo asset
            ),
            // const Spacer(),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.only(left: 100.0),
              child: Text(
                "Borrow and lend items in your community!",
                style: TextStyle(fontSize: 24, color: Colors.black),
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.fromLTRB(100, 0, 0, 0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (context) => const SignInScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF8B5A3C), // Brown button color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    "GET STARTED →",
                    style: TextStyle(
                        fontSize: 16, color: Colors.white), // White text color
                  ),
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
