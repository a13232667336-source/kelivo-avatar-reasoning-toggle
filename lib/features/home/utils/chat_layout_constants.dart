/// Shared layout constants for the Home chat UI (desktop/tablet).
class ChatLayoutConstants {
  /// Height of the chat app bar's toolbar row.
  ///
  /// Slightly shorter than [kToolbarHeight]: the icons sit a touch higher and
  /// the chrome band ends a few pixels earlier, so the transcript is not eaten
  /// by the top plate. Anything that computes the top inset must use this.
  static const double chatToolbarHeight = 52.0;

  /// Max readable width for the chat message list area.
  static const double maxContentWidth = 860.0;

  /// Max width for the chat input bar area.
  static const double maxInputWidth = 860.0;

  /// How long a deleted message fades out and collapses before its slot is
  /// actually removed from the timeline. The controller waits this long
  /// between flagging the slot and performing the deletion, so the widget
  /// animation and the data mutation stay in lockstep.
  static const Duration slotRemovalAnimationDuration = Duration(
    milliseconds: 240,
  );
}
