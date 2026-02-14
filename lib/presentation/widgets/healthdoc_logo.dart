import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../config/app_config.dart';

class HealthDocLogo extends StatelessWidget {
  final double? logoSize;
  final double? fontSize;

  const HealthDocLogo({
    super.key,
    this.logoSize,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Document Icon
        Container(
          width: logoSize ?? 48,
          height: logoSize ?? 48,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.description,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(height: 12),
        // HealthDoc Text
        Text(
          AppConfig.appName,
          style: AppTheme.headingLarge.copyWith(
            fontSize: fontSize ?? 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        // Tagline
        Text(
          AppConfig.appTagline,
          style: AppTheme.bodySmall.copyWith(
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
