import 'package:flutter/material.dart';
import 'logo_widget.dart';

class LogoExample extends StatelessWidget {
  const LogoExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartSpender Logo Examples'),
        // Small logo in app bar
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: LogoWidget(width: 32, height: 32),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Large logo for splash screen or main screen
            LogoWidget(width: 200, height: 200),
            SizedBox(height: 20),
            Text(
              'SmartSpender',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 40),

            // Medium logo with custom color
            LogoWidget(width: 100, height: 100, color: Colors.blue),
            SizedBox(height: 10),
            Text('Colored Logo Example'),

            SizedBox(height: 40),

            // Small logo for buttons or list items
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LogoWidget(width: 24, height: 24),
                SizedBox(width: 8),
                Text('Small Logo in Row'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
