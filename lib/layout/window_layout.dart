import 'dart:math' as math;

class WindowRegion {
  final double left, top, width, height;
  const WindowRegion(this.left, this.top, this.width, this.height);
  double get right => left + width;
  double get bottom => top + height;
  double get area => width * height;
}

class WindowObstacle {
  final double left, top, width, height;
  final bool separating;
  const WindowObstacle({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.separating = true,
  });
}

class WindowLayout {
  final WindowRegion primary;
  final WindowRegion? secondary;
  final bool useRail, canSplitCalendar;
  const WindowLayout(
    this.primary,
    this.secondary,
    this.useRail,
    this.canSplitCalendar,
  );
  static WindowLayout resolve({
    required double width,
    required double height,
    double textScale = 1,
    List<WindowObstacle> obstacles = const [],
  }) {
    var regions = [WindowRegion(0, 0, math.max(0, width), math.max(0, height))];
    var separated = false;
    for (final obstacle in obstacles.where((o) => o.separating)) {
      final next = <WindowRegion>[];
      for (final r in regions) {
        final right = obstacle.left + obstacle.width,
            bottom = obstacle.top + obstacle.height;
        if (right < r.left ||
            obstacle.left > r.right ||
            bottom < r.top ||
            obstacle.top > r.bottom) {
          next.add(r);
          continue;
        }
        if (obstacle.height >= obstacle.width &&
            obstacle.top <= r.top &&
            bottom >= r.bottom) {
          if (obstacle.left > r.left)
            next.add(
              WindowRegion(r.left, r.top, obstacle.left - r.left, r.height),
            );
          if (right < r.right)
            next.add(WindowRegion(right, r.top, r.right - right, r.height));
          separated = true;
        } else if (obstacle.left <= r.left && right >= r.right) {
          if (obstacle.top > r.top)
            next.add(
              WindowRegion(r.left, r.top, r.width, obstacle.top - r.top),
            );
          if (bottom < r.bottom)
            next.add(WindowRegion(r.left, bottom, r.width, r.bottom - bottom));
          separated = true;
        } else {
          next.add(r);
        }
      }
      if (next.isNotEmpty) regions = next;
    }
    regions.sort((a, b) {
      final area = b.area.compareTo(a.area);
      if (area != 0) return area;
      final top = a.top.compareTo(b.top);
      return top != 0 ? top : a.left.compareTo(b.left);
    });
    final factor = math.max(1.0, textScale);
    // A physical gap replaces the normal 24-pixel inter-pane spacing.
    for (final left in regions) {
      for (final right in regions) {
        if (left.right <= right.left &&
            left.top == right.top &&
            left.height == right.height &&
            left.width >= 560 * factor &&
            right.width >= 320 * factor) {
          return WindowLayout(
            left,
            right,
            left.width >= 600 && left.height >= 400,
            true,
          );
        }
      }
    }
    final primary = regions.first;
    return WindowLayout(
      primary,
      null,
      primary.width >= 600 && primary.height >= 400,
      !separated && math.min(primary.width, 1440) >= (560 + 320) * factor + 24,
    );
  }
}
