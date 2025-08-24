import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LogoTest extends StatelessWidget {
  const LogoTest({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logo Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Testing SVG Logo:'),
            const SizedBox(height: 20),
            
            // Test direct SVG loading
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
              ),
              child: SvgPicture.asset(
                'assets/images/SmartSpender.svg',
                width: 80,
                height: 80,
                fit: BoxFit.contain,
                placeholderBuilder: (context) => const Center(
                  child: Text('SVG Loading...'),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            const Text('If you see the logo above, SVG is working!'),
            
            const SizedBox(height: 20),
            
            // Test PNG fallback
            const Text('PNG Version:'),
            const SizedBox(height: 10),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
              ),
              child: Image.asset(
                'assets/images/SmartSpender.png',
                width: 80,
                height: 80,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Text('PNG Error'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
