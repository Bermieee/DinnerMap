import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/planner_repository.dart';
import '../planner/models.dart';
import 'shared_repository.dart';
import 'shared_models.dart';

class SupabaseSharedRepository implements SharedRepository {
  final SupabaseClient client;
  final String householdId;
  final _events = StreamController<bool>.broadcast();
  RealtimeChannel? _channel;
  SupabaseSharedRepository(this.client, this.householdId);
  Future<SharedView> _call(String rpc, [Map<String, dynamic>? params]) async {
    try {
      return SharedView.fromJson(
        Map<String, dynamic>.from(await client.rpc(rpc, params: params) as Map),
      );
    } on PostgrestException catch (e) {
      if (e.code == 'P0002') throw SharedConflict(e.message);
      throw SharedUnavailable(e.message);
    } catch (e) {
      throw const SharedUnavailable(
        'Connection lost. Reload to check whether your change was saved.',
        uncertain: true,
      );
    }
  }

  @override
  Future<SharedView> fetch() => _call('read_shared_plan');
  @override
  Future<SharedView> apply(
    String requestId,
    List<Map<String, dynamic>> changes,
  ) => _call('apply_shared_change', {
    'p_request_id': requestId,
    'p_change': changes,
  });
  @override
  Future<SharedView> regenerate(
    String requestId,
    int revision,
    DateTime start,
    int weeks,
    List<Map<String, dynamic>> rows,
    List<String> warnings,
  ) => _call('regenerate_shared_list', {
    'p_request_id': requestId,
    'p_calendar_revision': revision,
    'p_start': dateKey(start),
    'p_weeks': weeks,
    'p_rows': rows,
    'p_warnings': warnings,
  });
  @override
  Future<void> importLocal(PlannerSnapshot snapshot) async {
    await client.rpc(
      'import_local_plan',
      params: {'p_snapshot': jsonDecode(snapshot.encode())},
    );
  }

  @override
  Stream<bool> watchConnection() {
    _channel ??= client
        .channel('household-$householdId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'households',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: householdId,
          ),
          callback: (_) {
            if (!_events.isClosed) _events.add(true);
          },
        );
    for (final table in [
      'calendar_entries',
      'recipes',
      'shopping_items',
      'shopping_lists',
      'household_preferences',
      'memberships',
    ]) {
      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'household_id',
          value: householdId,
        ),
        callback: (_) {
          if (!_events.isClosed) _events.add(true);
        },
      );
    }
    _channel!.subscribe((status, error) {
      if (!_events.isClosed)
        _events.add(status == RealtimeSubscribeStatus.subscribed);
    });
    return _events.stream;
  }

  @override
  Future<void> dispose() async {
    if (_channel != null) await client.removeChannel(_channel!);
    await _events.close();
  }
}
