import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// How much optical glass the chat chrome carries.
///
/// Deliberately "restrained": chat is long-form text, so glass is limited to the
/// navigation / control layer (app bar band, composer plate). Message content
/// always stays opaque.
enum ChatGlassLevel {
  /// No glass: solid surface plates (the pre-glass behaviour).
  off,

  /// Frost only — BackdropFilter, no shader. Cheapest, still reads as glass.
  light,

  /// Default. Shader refraction with a soft rim light.
  standard,

  /// Thicker lens: stronger refraction and specular, still flat and quiet.
  strong,
}

extension ChatGlassLevelX on ChatGlassLevel {
  String get labelZh => switch (this) {
    ChatGlassLevel.off => '关闭',
    ChatGlassLevel.light => '轻',
    ChatGlassLevel.standard => '标准',
    ChatGlassLevel.strong => '浓',
  };

  /// Stored value: keep it stable, the preference persists this.
  int get storageValue => index;

  static ChatGlassLevel fromStorage(int? value) {
    if (value == null || value < 0 || value >= ChatGlassLevel.values.length) {
      return ChatGlassLevel.standard;
    }
    return ChatGlassLevel.values[value];
  }

  GlassQuality get quality => switch (this) {
    ChatGlassLevel.off => GlassQuality.minimal,
    ChatGlassLevel.light => GlassQuality.minimal,
    ChatGlassLevel.standard => GlassQuality.standard,
    ChatGlassLevel.strong => GlassQuality.premium,
  };

  /// Lens thickness in logical pixels. The three levels stay within a range
  /// that keeps text on top of the plate readable at normal viewing distance.
  double get thickness => switch (this) {
    ChatGlassLevel.off => 0,
    ChatGlassLevel.light => 18,
    ChatGlassLevel.standard => 30,
    ChatGlassLevel.strong => 42,
  };

  double get lightIntensity => switch (this) {
    ChatGlassLevel.off => 0,
    ChatGlassLevel.light => .20,
    ChatGlassLevel.standard => .40,
    ChatGlassLevel.strong => .62,
  };

  double get saturation => switch (this) {
    ChatGlassLevel.off => 1,
    ChatGlassLevel.light => 1.04,
    ChatGlassLevel.standard => 1.08,
    ChatGlassLevel.strong => 1.12,
  };
}

/// Builds the material for a chat chrome plate at the given level.
///
/// Calibrated against the browser chrome, which already ships this pipeline on
/// iOS 15+: same lens model, same colour wash rule (dark chrome stays dark over
/// bright content), but flatter lighting because a bar is not a floating button.
LiquidGlassSettings chatGlassSettings({
  required ChatGlassLevel level,
  required bool dark,
  required Color surface,
}) {
  return LiquidGlassSettings(
    visibility: 1,
    // A translucent wash keeps the bar legible while the transcript scrolls
    // underneath; fully clear glass over body text loses contrast. Tinting with
    // the theme surface keeps the plate in the palette's family (a pure-black
    // skin gets a black wash, not a grey one).
    glassColor: surface.withValues(alpha: dark ? .52 : .46),
    bodyMode: GlassBodyMode.clear,
    lensModel: GlassLensModel.edgeWarp,
    thickness: level.thickness,
    blur: level == ChatGlassLevel.light ? 0 : 2,
    refractiveIndex: switch (level) {
      ChatGlassLevel.off => 1,
      ChatGlassLevel.light => 1.12,
      ChatGlassLevel.standard => 1.20,
      ChatGlassLevel.strong => 1.26,
    },
    chromaticAberration: level == ChatGlassLevel.strong ? .35 : 0,
    // Fixed overhead light: the bar does not track the finger.
    lightAngle: -.75,
    lightIntensity: level.lightIntensity,
    ambientStrength: .15,
    ambientRim: .07,
    saturation: level.saturation,
    shadow: const [],
    backerColor: null,
  );
}
