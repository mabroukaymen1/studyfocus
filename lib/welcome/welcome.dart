import 'package:flutter/material.dart';
import 'dart:async';
import 'package:study/welcome/step.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Timer to navigate to the next screen after 5 seconds
    Timer(Duration(seconds: 5), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => OnboardingScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1C1C1E), // Dark background color
      body: Center(
        child: RichText(
          text: TextSpan(
            text: 'Study',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white, // White color for 'Study'
            ),
            children: [
              TextSpan(
                text: 'focus',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.normal,
                  color: Colors.grey, // Grey color for 'Sprint'
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
