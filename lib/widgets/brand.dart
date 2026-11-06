import 'package:flutter/material.dart';
import '../core/theme.dart';

/// شعارا وزارة المالية ومديرية مالية اللاذقية.
/// يوضعان على لوحة بيضاء ليبقيا واضحين في الوضعين الفاتح والداكن.
class BrandLogos extends StatelessWidget {
  final double logoHeight;
  final bool framed;
  final EdgeInsets padding;
  final double gap, radius;

  const BrandLogos({
    super.key,
    this.logoHeight = 54,
    this.framed = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    this.gap = 14,
    this.radius = 20,
  });

  Widget _logo(String asset) => Image.asset(
        asset,
        height: logoHeight,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (c, e, s) => Icon(Icons.image_not_supported_outlined,
            size: logoHeight * .7, color: kMuted),
      );

  @override
  Widget build(BuildContext context) {
    final row = Row(mainAxisSize: MainAxisSize.min, children: [
      _logo('assets/logos/dept_logo.png'),
      Container(
        width: .8,
        height: logoHeight * .8,
        margin: EdgeInsets.symmetric(horizontal: gap),
        color: const Color(0xFFE3E3E8),
      ),
      _logo('assets/logos/mof_logo.png'),
    ]);

    if (!framed) return row;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFEDEDF0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .07),
              blurRadius: 18,
              offset: const Offset(0, 7)),
        ],
      ),
      child: row,
    );
  }
}
