import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/text_styles.dart';

class ServiGoLogo extends StatelessWidget {
  final double size;
  final bool showTagline;
  final bool showIcon;
  final Color? primaryColor;
  final Color? accentColor;
  
  const ServiGoLogo({
    this.size = 40,
    this.showTagline = true,
    this.showIcon = false,
    this.primaryColor,
    this.accentColor,
    Key? key,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showIcon) ...[
              // Use Image.asset instead of the container with gradient
              Image.asset(
                'assets/images/app_icon.png', // Path to your logo
                width: size,
                height: size,
                fit: BoxFit.contain,
              ),
              SizedBox(width: 12),
            ],
            
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ServiGo',
                    style: AppTextStyles.logo.copyWith(
                      fontSize: size * 0.7,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  if (showTagline) ...[
                    SizedBox(height: 4),
                    Text(
                      'Find. Book. Fix.',
                      style: AppTextStyles.tagline.copyWith(
                        fontSize: size * 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Updated: ServiGoLogoCompact to use the logo image
class ServiGoLogoCompact extends StatelessWidget {
  final double size;
  
  const ServiGoLogoCompact({
    this.size = 32,
    Key? key,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.trustBlue.withOpacity(0.2),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: Image.asset(
          'assets/images/app_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

// Updated: Simpler logo for AppBar without text
class ServiGoAppBarLogo extends StatelessWidget {
  const ServiGoAppBarLogo({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ServiGoLogoCompact(size: 32),
        SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ServiGo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFamily: 'Montserrat',
              ),
            ),
            Text(
              'Find. Book. Fix.',
              style: TextStyle(
                fontSize: 9,
                color: Colors.white.withOpacity(0.8),
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Optional: Add a version without text if needed
class ServiGoImageLogo extends StatelessWidget {
  final double size;
  
  const ServiGoImageLogo({
    this.size = 40,
    Key? key,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/app_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}