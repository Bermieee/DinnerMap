import '../../data/planner_repository.dart';
import 'shared_models.dart';

abstract class SharedRepository {
  Future<SharedView> fetch();
  Future<SharedView> apply(
    String requestId,
    List<Map<String, dynamic>> changes,
  );
  Future<SharedView> regenerate(
    String requestId,
    int revision,
    DateTime start,
    int weeks,
    List<Map<String, dynamic>> rows,
    List<String> warnings,
  );
  Future<void> importLocal(PlannerSnapshot snapshot);
  Stream<bool> watchConnection();
  Future<void> dispose();
}
