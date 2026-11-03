import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../theme/chat_glass.dart';

/// Which edge of a chrome plate carries its hairline.
enum GlassPlateEdge { none, top, bottom }

/// An optical plate for the chat chrome (app bar band, composer plate).
///
/// The package draws the material; this widget owns the app-level rules:
///
/// * content is never covered by glass — only the navigation/control layer is;
/// * [ChatGlassLevel.off] and high-contrast mode fall back to an opaque plate,
///   so the transcript is always readable;
/// * a 1px hairline keeps the plate's edge defined, which is what separates
///   "system chrome" from "a translucent rectangle".
class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    super.key,
    required this.level,
    this.borderRadius = 0,
    this.edge = GlassPlateEdge.none,
  });

  final ChatGlassLevel level;
  final double borderRadius;
  final GlassPlateEdge edge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final highContrast = MediaQuery.highContrastOf(context);
    final solid = level == ChatGlassLevel.off || highContrast;

    final hairline = BorderSide(
      color: theme.colorScheme.onSurface.withValues(alpha: dark ? .10 : .07),
      width: .6,
    );
    final border = Border(
      top: edge == GlassPlateEdge.top ? hairline : BorderSide.none,
      bottom: edge == GlassPlateEdge.bottom ? hairline : BorderSide.none,
    );

    if (solid) {
      return DecoratedBox(
        decoration: BoxDecoration(color: surface, border: border),
        child: const SizedBox.expand(),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        GlassTheme(
          data: GlassThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          child: AdaptiveGlass(
            shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
            quality: level.quality,
            platformViewBackdrop: false,
            useOwnLayer: true,
            settings: chatGlassSettings(
              level: level,
              dark: dark,
              surface: surface,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        if (edge != GlassPlateEdge.none)
          IgnorePointer(
            child: DecoratedBox(decoration: BoxDecoration(border: border)),
          ),
      ],
    );
  }
}
