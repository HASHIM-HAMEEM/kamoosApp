import 'package:flutter/material.dart';

class AnimatedSplashScreen extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const AnimatedSplashScreen({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 2500),
  });

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _fadeController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _splashFadeAnimation;

  bool _showSplash = true;

  @override
  void initState() {
    super.initState();

    // Logo animation controller (for scale and fade in)
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Fade controller for splash screen exit
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Logo scale animation (subtle scale up, Airbnb style)
    _logoScaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Logo fade in animation
    _logoFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    // Splash screen fade out animation
    _splashFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeInOut,
      ),
    );

    // Start animations sequence
    _startAnimationSequence();
  }

  void _startAnimationSequence() async {
    // Wait a brief moment
    await Future.delayed(const Duration(milliseconds: 300));

    // Animate logo in
    await _logoController.forward();

    // Hold for a moment
    await Future.delayed(const Duration(milliseconds: 800));

    // Fade out splash
    await _fadeController.forward();

    // Hide splash screen
    if (mounted) {
      setState(() {
        _showSplash = false;
      });
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showSplash) {
      return widget.child;
    }

    return Stack(
      children: [
        // Main content (hidden behind splash)
        widget.child,

        // Animated splash overlay
        AnimatedBuilder(
          animation: _splashFadeAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _splashFadeAnimation.value,
              child: Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF0A0A0A)
                    : const Color(0xFFFAFAFA),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _logoFadeAnimation.value,
                        child: Transform.scale(
                          scale: _logoScaleAnimation.value,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(40),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(40),
                              child: Image.asset(
                                'assets/logo/DLogo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
