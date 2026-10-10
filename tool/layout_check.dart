import '../lib/layout/window_layout.dart';

void main() {
  var passed = 0;
  void check(String name, bool value) {
    if (!value) throw StateError('FAIL $name');
    passed++;
    print('PASS $name');
  }

  WindowLayout window(
    double w,
    double h, {
    double scale = 1,
    List<WindowObstacle> obstacles = const [],
  }) => WindowLayout.resolve(
    width: w,
    height: h,
    textScale: scale,
    obstacles: obstacles,
  );
  check('compact navigation', !window(599, 900).useRail);
  check('medium navigation', window(600, 900).useRail);
  check('short navigation', !window(844, 390).useRail);
  check('split calendar boundary', window(904, 900).canSplitCalendar);
  check('stacked calendar boundary', !window(903, 900).canSplitCalendar);
  check(
    'large text stacked fallback',
    !window(1280, 900, scale: 2).canSplitCalendar,
  );
  final vertical = window(
    1200,
    900,
    obstacles: [
      const WindowObstacle(left: 650, top: 0, width: 24, height: 900),
    ],
  );
  check(
    'vertical regions exclude hinge',
    vertical.primary.right == 650 && vertical.secondary!.left == 674,
  );
  check('adequate hinge panes split', vertical.canSplitCalendar);
  final narrow = window(
    800,
    900,
    obstacles: [
      const WindowObstacle(left: 300, top: 0, width: 24, height: 900),
    ],
  );
  check(
    'asymmetric hinge largest region',
    narrow.primary.left == 324 && narrow.secondary == null,
  );
  final horizontal = window(
    800,
    1000,
    obstacles: [
      const WindowObstacle(left: 0, top: 350, width: 800, height: 24),
    ],
  );
  check(
    'horizontal chooses lower largest region',
    horizontal.primary.top == 374 && horizontal.primary.height == 626,
  );
  final crease = window(
    1200,
    900,
    obstacles: [
      const WindowObstacle(
        left: 600,
        top: 0,
        width: 0,
        height: 900,
        separating: false,
      ),
    ],
  );
  check(
    'non separating crease does not partition',
    crease.primary.width == 1200,
  );
  final fold = window(
    1200,
    900,
    obstacles: [const WindowObstacle(left: 600, top: 0, width: 0, height: 900)],
  );
  check(
    'zero width separating fold partitions',
    fold.primary.right == 600 && fold.secondary!.left == 600,
  );
  final tie = window(
    800,
    1000,
    obstacles: [
      const WindowObstacle(left: 0, top: 490, width: 800, height: 20),
    ],
  );
  check('equal regions prefer top', tie.primary.top == 0);
  print('$passed layout checks passed');
}
