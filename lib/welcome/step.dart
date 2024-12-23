import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:study/welcome/face.dart';

class OnboardingScreen extends StatelessWidget {
  final PageController _controller = PageController();
  final ValueNotifier<int> _currentPage = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBackground(),
          PageView(
            controller: _controller,
            physics: BouncingScrollPhysics(),
            onPageChanged: (index) {
              _currentPage.value = index;
            },
            children: [
              OnboardingPage(
                imageAsset: 'assets/image/mang.png',
                title: 'Enhanced\nTime Management',
                subtitle:
                    'Say goodbye to last-minute cramming and hello to a well-structured study routine.',
                pageIndex: 0,
              ),
              OnboardingPage(
                imageAsset: 'assets/image/focus.png',
                title: 'Improved\nFocus',
                subtitle:
                    'You\'ll find it easier to concentrate on your studies, resulting in better comprehension and retention.',
                pageIndex: 1,
              ),
              OnboardingPage(
                imageAsset: 'assets/image/final.png',
                title: 'Academic\nSuccess',
                subtitle:
                    'By consistently using StudyPlanner, you\'re equipping yourself with the tools for academic success.',
                pageIndex: 2,
                isLastPage: true,
              ),
            ],
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                SmoothPageIndicator(
                  controller: _controller,
                  count: 3,
                  effect: ExpandingDotsEffect(
                    dotColor: Colors.grey.shade600,
                    activeDotColor: Colors.grey.shade400,
                    dotHeight: 8,
                    dotWidth: 8,
                    expansionFactor: 4,
                    spacing: 6.0,
                  ),
                ),
                SizedBox(height: 30),
                ValueListenableBuilder<int>(
                  valueListenable: _currentPage,
                  builder: (context, pageIndex, child) {
                    return NavigationButtons(
                      controller: _controller,
                      currentPage: pageIndex,
                      onGetStarted: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                              builder: (context) => FaceIdScreen()),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1C1C1E),
            Color(0xFF1C1C1E),
            Color(0xFF1C1C1E),
          ],
        ),
      ),
      child: AnimatedOpacity(
        opacity: 0.15,
        duration: Duration(seconds: 2),
        child: CustomPaint(
          painter: BackgroundPainter(),
          child: Container(),
        ),
      ),
    );
  }
}

class BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.7,
      size.width * 0.5,
      size.height * 0.8,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.9,
      size.width,
      size.height * 0.8,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class OnboardingPage extends StatelessWidget {
  final String imageAsset;
  final String title;
  final String subtitle;
  final int pageIndex;
  final bool isLastPage;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.pageIndex,
    this.isLastPage = false,
    required this.imageAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            imageAsset,
            height: 250,
          ),
          SizedBox(height: 50),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          SizedBox(height: 20),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade300,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class NavigationButtons extends StatelessWidget {
  final PageController controller;
  final int currentPage;
  final VoidCallback onGetStarted;

  NavigationButtons({
    required this.controller,
    required this.currentPage,
    required this.onGetStarted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () {
              controller.jumpToPage(2);
            },
            child: Text(
              'Skip',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade300,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade400,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 8,
            ),
            onPressed: () {
              if (currentPage < 2) {
                controller.nextPage(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              } else {
                onGetStarted();
              }
            },
            child: Text(
              currentPage == 2 ? 'Get Started' : 'Next',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
