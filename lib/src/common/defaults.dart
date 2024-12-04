import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:graphic/src/graffiti/element/element.dart';
import 'package:graphic/src/graffiti/element/label.dart';
import 'package:graphic/src/guide/axis/axis.dart';
import 'package:graphic/src/interaction/event.dart';
import 'package:graphic/src/interaction/gesture.dart';

/// Gets event update for different dimensions.
EventUpdater<List<double>> _getRangeUpdate_old(
        bool isHorizontal, bool focusMouseScale) =>
    (
      List<double> init,
      List<double> pre,
      Event event,
    ) {
      if (event is GestureEvent) {
        final gesture = event.gesture;

        if (gesture.type == GestureType.scaleUpdate) {
          final detail = gesture.details as ScaleUpdateDetails;

          if (detail.pointerCount == 1) {
            // Panning.

            final deltaRatio = isHorizontal
                ? gesture.preScaleDetail!.focalPointDelta.dx
                : -gesture.preScaleDetail!.focalPointDelta.dy;
            final delta = deltaRatio /
                (isHorizontal
                    ? gesture.chartSize.width
                    : gesture.chartSize.height);
            return [pre.first + delta, pre.last + delta];
          } else {
            // Scaling.

            double getScaleDim(ScaleUpdateDetails p0) =>
                isHorizontal ? p0.horizontalScale : p0.verticalScale;
            final preScale = getScaleDim(gesture.preScaleDetail!);
            final scale = getScaleDim(detail);
            final deltaRatio = (scale - preScale) / preScale / 2;
            final preRange = pre.last - pre.first;
            final delta = deltaRatio * preRange;
            return [pre.first - delta, pre.last + delta];
          }
        } else if (gesture.type == GestureType.scroll) {
          const step = -0.1;
          final scrollDelta = gesture.details as Offset;
          final deltaRatio = scrollDelta.dy == 0
              ? 0.0
              : scrollDelta.dy > 0
                  ? (step / 2)
                  : (-step / 2);
          final preRange = pre.last - pre.first;
          final delta = deltaRatio * preRange;
          if (!focusMouseScale) {
            return [pre.first - delta, pre.last + delta];
          } else {
            double mousePos;
            if (isHorizontal) {
              mousePos = (gesture.localPosition.dx - 39.5) /
                  (gesture.chartSize.width - 51);
            } else {
              mousePos = 1 -
                  (gesture.localPosition.dy - 5) /
                      (gesture.chartSize.height - 25);
            }
            mousePos = (mousePos - pre.first) / (pre.last - pre.first);
            return [
              pre.first - delta * 2 * mousePos,
              pre.last + delta * 2 * (1 - mousePos)
            ];
          }
        } else if (gesture.type == GestureType.doubleTap) {
          return init;
        }
      }

      return pre;
    };

EventUpdater<List<double>> _getRangeUpdate(
  bool isHorizontal,
  bool focusMouseScale,
) =>
    (
      List<double> initialValue,
      List<double> previousBoundaries,
      Event event,
    ) {
      if (event is GestureEvent) {
        final Gesture gesture = event.gesture;

        if (gesture.type == GestureType.scaleUpdate) {
          final ScaleUpdateDetails details =
              gesture.details as ScaleUpdateDetails;

          if (details.pointerCount == 1) {
            /// Panning.

            final deltaRatio = isHorizontal
                ? gesture.preScaleDetail!.focalPointDelta.dx
                : -gesture.preScaleDetail!.focalPointDelta.dy;
            final delta = deltaRatio /
                (isHorizontal
                    ? gesture.chartSize.width
                    : gesture.chartSize.height);
            return [
              previousBoundaries.first + delta,
              previousBoundaries.last + delta
            ];
          } else {
            /// Scaling.

            /// Compute scaling strength [delta]
            final double previousScale = gesture.preScaleDetail!.scale;
            final double scale = details.scale;
            late final double deltaRatio;
            if (previousScale == 0) {
              deltaRatio = 0;
            } else {
              deltaRatio = scale - previousScale;
            }
            final double previousRange =
                previousBoundaries.last - previousBoundaries.first;
            final double delta = deltaRatio * previousRange;

            /// Compute new graph boundaries.

            /// Special case of the graph bounds perfectly matching the viewport.
            if (previousBoundaries.first.abs() +
                    previousBoundaries.last.abs() -
                    1 ==
                0) {
              return [
                previousBoundaries.first - delta,
                previousBoundaries.last + delta
              ];
            }

            /// To prevent the graph from moving out of the viewport when zoomed we define a focus point in the
            /// viewport (e.g. 0.5 for the center of the viewport) and we weigh the movement of the returned first and last
            /// boundary of the graph by a value proportional to the distance of the boundary to the focus point.
            const double focusPoint = 0.5;
            double computeBoundaryRatio(bool isFirstBound) {
              final double boundaryValue = isFirstBound
                  ? previousBoundaries.first
                  : previousBoundaries.last;
              return (boundaryValue - focusPoint).abs() /
                  (previousBoundaries.first.abs() +
                      previousBoundaries.last.abs() -
                      focusPoint * 2);
            }

            double normalizeBoundaryRatio(bool isFirstBound,
                double newBoundaryStart, double newBoundaryEnd) {
              final double newBoundaryValue =
                  isFirstBound ? newBoundaryStart : newBoundaryEnd;
              return newBoundaryValue / (newBoundaryStart + newBoundaryEnd);
            }

            final double unnormalizedFirstBoundaryRatio =
                computeBoundaryRatio(true);
            final double unnormalizedLastBoundaryRatio =
                computeBoundaryRatio(false);

            /// We normalize the final ratio to make sure the sum of the 2 ratios is always 1 (which keeps the zoom strength constant).
            final double firstBoundaryRatio = normalizeBoundaryRatio(true,
                unnormalizedFirstBoundaryRatio, unnormalizedLastBoundaryRatio);
            final double lastBoundaryRatio = normalizeBoundaryRatio(false,
                unnormalizedFirstBoundaryRatio, unnormalizedLastBoundaryRatio);

            final double newFirstBoundary =
                previousBoundaries.first - firstBoundaryRatio * delta;
            final double newLastBoundary =
                previousBoundaries.last + lastBoundaryRatio * delta;

            return [newFirstBoundary, newLastBoundary];
          }
        } else if (gesture.type == GestureType.scroll) {
          const step = -0.1;
          final scrollDelta = gesture.details as Offset;
          final deltaRatio = scrollDelta.dy == 0
              ? 0.0
              : scrollDelta.dy > 0
                  ? (step / 2)
                  : (-step / 2);
          final preRange = previousBoundaries.last - previousBoundaries.first;
          final delta = deltaRatio * preRange;
          if (!focusMouseScale) {
            return [
              previousBoundaries.first - delta,
              previousBoundaries.last + delta
            ];
          } else {
            double mousePos;
            if (isHorizontal) {
              mousePos = (gesture.localPosition.dx - 39.5) /
                  (gesture.chartSize.width - 51);
            } else {
              mousePos = 1 -
                  (gesture.localPosition.dy - 5) /
                      (gesture.chartSize.height - 25);
            }
            mousePos = (mousePos - previousBoundaries.first) /
                (previousBoundaries.last - previousBoundaries.first);
            return [
              previousBoundaries.first - delta * 2 * mousePos,
              previousBoundaries.last + delta * 2 * (1 - mousePos)
            ];
          }
        } else if (gesture.type == GestureType.doubleTap) {
          return initialValue;
        }
      }

      return previousBoundaries;
    };

/// Some useful default values for specifications.
abstract class Defaults {
  /// A single primary color.
  static Color primaryColor = const Color(0xff1890ff);

  /// A color for auxiliary lines.
  static Color strokeColor = const Color(0xffe8e8e8);

  /// A color for text.
  static Color textColor = const Color(0xff808080);

  /// A color palette of 10 colors.
  static List<Color> get colors10 => [
        const Color(0xff5b8ff9),
        const Color(0xff5ad8a6),
        const Color(0xff5d7092),
        const Color(0xfff6bd16),
        const Color(0xff6f5ef9),
        const Color(0xff6dc8ec),
        const Color(0xff945fb9),
        const Color(0xffff9845),
        const Color(0xff1e9493),
        const Color(0xffff99c3),
      ];

  /// A color palette of 20 colors.
  static List<Color> get colors20 => [
        const Color(0xff5b8ff9),
        const Color(0xffcdddfd),
        const Color(0xff5ad8a6),
        const Color(0xffcdf3e4),
        const Color(0xff5d7092),
        const Color(0xffced4de),
        const Color(0xfff6bd16),
        const Color(0xfffcebb9),
        const Color(0xff6f5ef9),
        const Color(0xffd3cefd),
        const Color(0xff6dc8ec),
        const Color(0xffd3eef9),
        const Color(0xff945fb9),
        const Color(0xffdecfea),
        const Color(0xffff9845),
        const Color(0xffffe0c7),
        const Color(0xff1e9493),
        const Color(0xffbbdede),
        const Color(0xffff99c3),
        const Color(0xffffe0ed),
      ];

  /// A stroke style for auxiliary lines.
  static PaintStyle get strokeStyle => PaintStyle(
        strokeColor: strokeColor,
        strokeWidth: 1,
      );

  /// A text style for labels.
  static TextStyle get textStyle => TextStyle(
        fontSize: 10,
        color: textColor,
      );

  /// A text style for labels curved in colored surfaces.
  static TextStyle get runeStyle => const TextStyle(
        fontSize: 10,
        color: Color(0xe6ffffff),
      );

  /// A specification for horizontal axis.
  static AxisGuide get horizontalAxis => AxisGuide(
        line: strokeStyle,
        label: LabelStyle(
          textStyle: textStyle,
          offset: const Offset(0, 7.5),
        ),
      );

  static AxisGuide get horizontalTopAxis => AxisGuide(
        line: strokeStyle,
        label: LabelStyle(
          textStyle: textStyle,
          offset: const Offset(0, 7.5),
        ),
        position: 1,
      );

  /// A specification for vertical axis.
  static AxisGuide get verticalAxis => AxisGuide(
        label: LabelStyle(
          textStyle: textStyle,
          offset: const Offset(-7.5, 0),
        ),
        line: strokeStyle,
      );

  static AxisGuide get verticalRightAxis => AxisGuide(
        label: LabelStyle(
          textStyle: textStyle,
          offset: const Offset(-7.5, 0),
        ),
        line: strokeStyle,
        position: 1,
      );

  /// A specification for radial axis.
  static AxisGuide get radialAxis => AxisGuide(
        line: strokeStyle,
        label: LabelStyle(textStyle: textStyle),
        grid: strokeStyle,
      );

  /// A specification for circular axis.
  static AxisGuide get circularAxis => AxisGuide(
        position: 1,
        line: strokeStyle,
        label: LabelStyle(textStyle: textStyle),
        grid: strokeStyle,
      );

  /// A event update for scaling and panning horizontal coordinate range.
  static EventUpdater<List<double>> get horizontalRangeEvent =>
      _getRangeUpdate(true, false);

  /// A event update for scaling and panning vertical coordinate range.
  static EventUpdater<List<double>> get verticalRangeEvent =>
      _getRangeUpdate(false, false);

  /// A event update for scaling and panning horizontal coordinate range by cursor focus.
  static EventUpdater<List<double>> get horizontalRangeFocusEvent =>
      _getRangeUpdate(true, true);

  /// A event update for scaling and panning vertical coordinate range by cursor focus.
  static EventUpdater<List<double>> get verticalRangeFocusEvent =>
      _getRangeUpdate(false, true);
}
