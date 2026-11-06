import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'webotapp_theme.dart';

/// Pure vector representation of the official WebotApp 4-colored pills icon mark
class WebotAppLogoMark extends StatelessWidget {
  final double size;

  const WebotAppLogoMark({
    super.key,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    // 4 overlapping rounded pills with exact degrees from webotapp.com:
    // -6 deg (Red), +3 deg (Green), -3 deg (Blue), +6 deg (Orange)
    final pillW = size * 0.28;
    final pillH = size * 0.88;
    final radius = BorderRadius.circular(pillW * 0.5);

    return SizedBox(
      width: size * 1.35,
      height: size,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: -6 * math.pi / 180,
              child: Container(
                width: pillW,
                height: pillH,
                decoration: BoxDecoration(
                  color: WebotAppTheme.pillRed,
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(-pillW * 0.28, 0),
              child: Transform.rotate(
                angle: 3 * math.pi / 180,
                child: Container(
                  width: pillW,
                  height: pillH,
                  decoration: BoxDecoration(
                    color: WebotAppTheme.pillGreen,
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(-pillW * 0.56, 0),
              child: Transform.rotate(
                angle: -3 * math.pi / 180,
                child: Container(
                  width: pillW,
                  height: pillH,
                  decoration: BoxDecoration(
                    color: WebotAppTheme.pillBlue,
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(-pillW * 0.84, 0),
              child: Transform.rotate(
                angle: 6 * math.pi / 180,
                child: Container(
                  width: pillW,
                  height: pillH,
                  decoration: BoxDecoration(
                    color: WebotAppTheme.pillOrange,
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Official WebotApp Logo Wordmark with 4-Pill Mark + "WEBOT" + "APP" typography
class WebotAppLogo extends StatelessWidget {
  final double markSize;
  final double fontSize;
  final bool isDark;
  final String? subtitle;

  const WebotAppLogo({
    super.key,
    this.markSize = 28,
    this.fontSize = 18,
    this.isDark = false,
    this.subtitle = 'POS ECOSYSTEM',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        WebotAppLogoMark(size: markSize),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w900,
                  fontSize: fontSize,
                  letterSpacing: -0.5,
                  height: 1.0,
                ),
                children: [
                  TextSpan(
                    text: 'WEBOT',
                    style: TextStyle(
                      color: isDark ? Colors.white : WebotAppTheme.darkSlate,
                    ),
                  ),
                  const TextSpan(
                    text: 'APP',
                    style: TextStyle(
                      color: WebotAppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!.toUpperCase(),
                style: TextStyle(
                  fontSize: fontSize * 0.38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: isDark ? Colors.white70 : WebotAppTheme.slate500,
                  height: 1.0,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
