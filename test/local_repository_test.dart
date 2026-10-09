import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dinnermap/data/local_planner_repository.dart';
import 'package:dinnermap/data/planner_repository.dart';

void main() {
  test('local snapshot saves and reloads', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = LocalPlannerRepository(await SharedPreferences.getInstance());
    await repo.save(
      const PlannerSnapshot(entries: [], recipes: {}, revision: 3),
    );
    expect((await repo.load())!.revision, 3);
  });
  test('corrupt payload is preserved for recovery', () async {
    SharedPreferences.setMockInitialValues({
      LocalPlannerRepository.key: '{bad',
    });
    final repo = LocalPlannerRepository(await SharedPreferences.getInstance());
    await expectLater(repo.load(), throwsFormatException);
    expect(await repo.rawBackup(), '{bad');
  });
  test('unsupported schema is rejected', () {
    expect(
      () => PlannerSnapshot.decode('{"version":99}'),
      throwsFormatException,
    );
  });
}
