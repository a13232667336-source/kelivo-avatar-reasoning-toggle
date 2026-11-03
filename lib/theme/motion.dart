import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// Motion tokens for an iOS 26/27-style feel.
///
/// Apple's interaction model is not "duration + easing curve": every
/// interactive transition is a spring described by a settle duration plus a
/// bounce amount (SwiftUI `.smooth` / `.snappy`, `CupertinoMotion`,
/// `SpringDescription.withDurationAndBounce`). A curve tween cannot be
/// interrupted mid-flight without a visible jump; a spring can.
///
/// Exposing springs as [Curve] keeps every existing `AnimatedX` /
/// `CurvedAnimation` / `TweenAnimationBuilder` call site untouched.
abstract final class AppMotion {
  /// Press feedback (buttons, cards, icon buttons).
  static const Duration press = Duration(milliseconds: 170);
  static const double pressBounce = 0.28;

  /// Small state changes (switch knob, chip selection, colour washes).
  static const Duration snappy = Duration(milliseconds: 220);
  static const double snappyBounce = 0.16;

  /// Standard expansion / collapse.
  static const Duration interactive = Duration(milliseconds: 340);
  static const double interactiveBounce = 0.10;

  /// Sheets, panels and anything that travels a long distance.
  static const Duration panel = Duration(milliseconds: 460);
  static const double panelBounce = 0.04;

  /// Scale / offset transitions. The small overshoot is what reads as
  /// "physical" rather than "animated".
  static final Curve pressCurve = SpringCurve(press, pressBounce);
  static final Curve panelCurve = SpringCurve(panel, panelBounce);

  /// Colour / opacity transitions must never overshoot: lerps are only defined
  /// on 0..1 and a colour lerp above 1 produces mud.
  static final Curve snappyColorCurve = SpringCurve(
    snappy,
    snappyBounce,
    overshoot: false,
  );
  static final Curve interactiveColorCurve = SpringCurve(
    interactive,
    interactiveBounce,
    overshoot: false,
  );

  /// Resolves a caller-supplied curve, falling back to the app default.
  static Curve colorOr(Curve? curve, {Curve? fallback}) =>
      curve ?? (fallback ?? snappyColorCurve);

  /// `Duration.zero` when the platform asks for reduced motion.
  static Duration scaleDuration(bool reduceMotion, Duration duration) =>
      reduceMotion ? Duration.zero : duration;
}

/// A [Curve] backed by the same spring model `CupertinoMotion` uses.
///
/// [settle] is the spring's response time: the point where it has effectively
/// reached the target. [overshoot] allows the curve to leave the 0..1 range
/// (only safe for transforms).
class SpringCurve extends Curve {
  SpringCurve(this.settle, double bounce, {this.overshoot = true})
    : _spring = SpringDescription.withDurationAndBounce(
        duration: settle,
        bounce: bounce,
      );

  final Duration settle;
  final bool overshoot;
  final SpringDescription _spring;

  late final SpringSimulation _simulation = SpringSimulation(_spring, 0, 1, 0);

  @override
  double transformInternal(double t) {
    final seconds = settle.inMicroseconds / Duration.microsecondsPerSecond;
    final value = _simulation.x(t * seconds);
    if (overshoot) return value;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }
}
