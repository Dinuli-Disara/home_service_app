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
          mainAxisAlignment: MainAxisAlignment.center, // ✅ Center align
          children: [
            if (showIcon) ...[
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor ?? AppColors.trustBlue,
                      accentColor ?? AppColors.modernTeal,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(size * 0.2),
                ),
                child: Center(
                  child: Text(
                    'SG',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.35,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
            ],
            
            // ✅ FIXED: Use Flexible to prevent overflow
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
                    overflow: TextOverflow.ellipsis, // ✅ Add overflow handling
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

// ✅ UPDATED: ServiGoLogoCompact for AppBar
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
        gradient: LinearGradient(
          colors: [AppColors.trustBlue, AppColors.vividAzure],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.trustBlue.withOpacity(0.2),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'SG',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.45,
            fontWeight: FontWeight.w800,
            fontFamily: 'Montserrat',
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

// ✅ UPDATED: Simpler logo for AppBar without text
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