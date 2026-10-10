import 'dart:ui' show DisplayFeature, DisplayFeatureType, DisplayFeatureState;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dinnermap/layout/adaptive_layout.dart';
import 'package:dinnermap/layout/adaptive_page.dart';

void main() {
  test('safe insets translate hinge into usable coordinates', () {
    final layout = AdaptiveLayout.resolve(
      size: const Size(1300, 900),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      textScale: 1,
      displayFeatures: const [
        DisplayFeature(
          bounds: Rect.fromLTWH(680, 0, 24, 900),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureFlat,
        ),
      ],
    );
    expect(layout.primaryRegion, const Rect.fromLTWH(20, 24, 660, 860));
    expect(layout.secondaryRegion, const Rect.fromLTWH(704, 24, 576, 860));
  });
  testWidgets('page is capped at readable width', (tester) async {
    tester.view.physicalSize = const Size(2400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: AdaptivePage(child: SizedBox(key: ValueKey('page-content'))),
      ),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('page-content'))).width,
      1440,
    );
  });
}
