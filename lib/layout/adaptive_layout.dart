import 'dart:ui' show DisplayFeature, DisplayFeatureType, DisplayFeatureState;
import 'package:flutter/material.dart';
import 'window_layout.dart';

class AdaptiveLayout {
  final Rect primaryRegion;
  final Rect? secondaryRegion;
  final bool useRail, canSplitCalendar;
  const AdaptiveLayout(
    this.primaryRegion,
    this.secondaryRegion,
    this.useRail,
    this.canSplitCalendar,
  );
  static AdaptiveLayout resolve({
    required Size size,
    required EdgeInsets padding,
    required List<DisplayFeature> displayFeatures,
    required double textScale,
  }) {
    final width = (size.width - padding.horizontal).clamp(0.0, double.infinity);
    final height = (size.height - padding.vertical).clamp(0.0, double.infinity);
    final result = WindowLayout.resolve(
      width: width,
      height: height,
      textScale: textScale,
      obstacles: displayFeatures
          .map(
            (f) => WindowObstacle(
              left: f.bounds.left - padding.left,
              top: f.bounds.top - padding.top,
              width: f.bounds.width,
              height: f.bounds.height,
              separating:
                  f.type == DisplayFeatureType.hinge ||
                  (f.type == DisplayFeatureType.fold &&
                      f.state == DisplayFeatureState.postureHalfOpened),
            ),
          )
          .toList(),
    );
    Rect rect(WindowRegion r) => Rect.fromLTWH(
      r.left + padding.left,
      r.top + padding.top,
      r.width,
      r.height,
    );
    return AdaptiveLayout(
      rect(result.primary),
      result.secondary == null ? null : rect(result.secondary!),
      result.useRail,
      result.canSplitCalendar,
    );
  }
}

MediaQueryData shiftedMedia(MediaQueryData data, Offset offset, Size size) =>
    data.copyWith(
      size: size,
      padding: EdgeInsets.zero,
      viewPadding: EdgeInsets.zero,
      displayFeatures: data.displayFeatures
          .map(
            (f) => DisplayFeature(
              bounds: f.bounds.shift(-offset),
              type: f.type,
              state: f.state,
            ),
          )
          .toList(),
    );
