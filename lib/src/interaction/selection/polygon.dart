import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:graphic/src/common/dim.dart';
import 'package:graphic/src/coord/coord.dart';
import 'package:graphic/src/dataflow/tuple.dart';
import 'package:graphic/src/graffiti/element/element.dart';
import 'package:graphic/src/util/path.dart';
import 'package:graphic/src/graffiti/element/spline.dart';
import 'package:graphic/src/interaction/gesture.dart';
import 'package:graphic/src/util/math.dart';

import 'selection.dart';

/// The selection to select a continuous range of data values
///
/// A polygon mark is shown to depict the extents of the points.
class PolygonSelection extends Selection {
  /// Creates an interval selection.
  PolygonSelection({
    this.color,
    Dim? dim,
    String? variable,
    Set<GestureType>? clear,
    Set<PointerDeviceKind>? devices,
    int? layer,
  }) : super(
          dim: dim,
          variable: variable,
          clear: clear,
          devices: devices,
          layer: layer,
        );

  /// The color of the interval mark.
  ///
  /// If null, a default `Color(0x10101010)` is set.
  Color? color;

  @override
  bool operator ==(Object other) =>
      other is PolygonSelection && super == other && color == other.color;
}

/// The interval selector.
///
/// The [points] are path points.
class PolygonSelector extends Selector {
  PolygonSelector(
    this.color,
    Dim? dim,
    String? variable,
    List<Offset> points,
  ) : super(
          dim,
          variable,
          points,
        );

  /// The color of the interval mark.
  final Color color;

  @override
  Set<int>? select(
    AttributesGroups groups,
    List<Tuple> tuples,
    Set<int>? preSelects,
    CoordConv coord,
  ) {
    final List<Offset> invertPoints =
        points.map((e) => coord.invert(e)).toList();

    bool Function(Attributes) test;
    if (dim == null) {
      final path = Path();
      path.addPolygon(invertPoints, true);
      test = (attributes) {
        final p = attributes.representPoint;
        return path.contains(p);
      };
    } else {
      if (dim == Dim.x) {
        final minDx = invertPoints.map((e) => e.dx).reduce(min);
        final maxDx = invertPoints.map((e) => e.dx).reduce(max);
        test = (attributes) {
          final p = attributes.representPoint;
          return p.dx.between(minDx, maxDx);
        };
      } else {
        final minDy = invertPoints.map((e) => e.dy).reduce(min);
        final maxDy = invertPoints.map((e) => e.dy).reduce(max);
        test = (attributes) {
          final p = attributes.representPoint;
          return p.dy.between(minDy, maxDy);
        };
      }
    }

    final rst = <int>{};
    for (var group in groups) {
      for (var attributes in group) {
        if (test(attributes)) {
          rst.add(attributes.index);
        }
      }
    }

    if (rst.isEmpty) {
      return null;
    }

    if (variable != null) {
      final values = <dynamic>{};
      for (var index in rst) {
        values.add(tuples[index][variable]);
      }
      for (var i = 0; i < tuples.length; i++) {
        if (values.contains(tuples[i][variable])) {
          rst.add(i);
        }
      }
    }

    return rst.isEmpty ? null : rst;
  }
}

// Renders polygon selector.

List<MarkElement>? renderPolygonSelector(
  List<Offset> points,
  Color color,
) {
  return [
    SplineElement(
      start: points.first,
      cubics: getCubicControls(points, false, true),
      style: PaintStyle(fillColor: color),
    ),
  ];
}
