import 'package:flutter/material.dart';

class LogoWidget extends StatelessWidget {
  final double? width;
  final double? height;
  final Color? color;

  const LogoWidget({super.key, this.width, this.height, this.color});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/SmartSpender Clear.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
      color: color, // This will tint the image if color is provided
      colorBlendMode: color != null ? BlendMode.srcIn : null,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            Icons.account_balance_wallet,
            size: (width ?? 24) * 0.5,
            color: Colors.grey[600],
          ),
        );
      },
    );
  }
}
