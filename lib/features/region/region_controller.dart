import 'dart:async';
import 'region_models.dart';
import 'region_repository.dart';

class RegionState {
  final RegionProfile? profile;
  final ZipRegion? region;
  final List<StoreLocation> stores;
  final List<ProductOffer> offers;
  final bool busy;
  final String? error;
  const RegionState({
    this.profile,
    this.region,
    this.stores = const [],
    this.offers = const [],
    this.busy = false,
    this.error,
  });
}

class RegionController {
  final RegionRepository repository;
  final _changes = StreamController<RegionState>.broadcast();
  RegionState state = const RegionState();
  bool _disposed = false;
  int _generation = 0;
  RegionController(this.repository);
  Stream<RegionState> get changes async* {
    yield state;
    yield* _changes.stream;
  }

  void _emit(RegionState next) {
    if (_disposed) return;
    state = next;
    _changes.add(next);
  }

  Future<void> _run(
    Future<RegionState> Function() operation, {
    bool clearOffers = false,
  }) async {
    if (_disposed || state.busy) return;
    final generation = ++_generation;
    _emit(
      RegionState(
        profile: state.profile,
        region: state.region,
        stores: state.stores,
        offers: clearOffers ? const [] : state.offers,
        busy: true,
      ),
    );
    try {
      final next = await operation();
      if (!_disposed && generation == _generation) _emit(next);
    } catch (e) {
      if (!_disposed && generation == _generation)
        _emit(
          RegionState(
            profile: state.profile,
            region: state.region,
            stores: state.stores,
            offers: state.offers,
            error: '$e',
          ),
        );
    }
  }

  Future<void> load() =>
      _run(() async => RegionState(profile: await repository.load()));
  Future<void> saveProfile(String zip, int radius) => _run(() async {
    final changed =
        state.profile?.zip != zip || state.profile?.radiusMiles != radius;
    final p = RegionProfile(
      zip,
      radiusMiles: radius,
      selectedStoreId: changed ? null : state.profile?.selectedStoreId,
    );
    await repository.save(p);
    return RegionState(
      profile: p,
      region: changed ? null : state.region,
      stores: changed ? const [] : state.stores,
      offers: changed ? const [] : state.offers,
    );
  });
  Future<void> discover() => _run(() async {
    final p = state.profile;
    if (p == null) throw StateError('Save your ZIP code first.');
    final region = await repository.resolve(p.zip);
    if (_disposed) return const RegionState();
    if (region.zip != p.zip)
      throw StateError('ZIP lookup returned a different region.');
    final stores = await repository.stores(p.zip, p.radiusMiles);
    final selected = p.selectedStoreId;
    final stillPresent =
        selected == null || stores.any((s) => s.id == selected);
    final profile = stillPresent
        ? p
        : RegionProfile(p.zip, radiusMiles: p.radiusMiles);
    if (!stillPresent && !_disposed) await repository.save(profile);
    return RegionState(
      profile: profile,
      region: region,
      stores: stores,
      offers: stillPresent ? state.offers : const [],
    );
  });
  Future<void> selectStore(StoreLocation store) => _run(() async {
    final p = state.profile;
    if (p == null ||
        store.retailer != 'kroger' ||
        !state.stores.any((s) => s.id == store.id))
      throw StateError('Select a store from your search results.');
    final next = RegionProfile(
      p.zip,
      radiusMiles: p.radiusMiles,
      selectedStoreId: store.id,
    );
    await repository.save(next);
    return RegionState(
      profile: next,
      region: state.region,
      stores: state.stores,
    );
  });
  Future<void> search(String query) => _run(() async {
    final store = state.profile?.selectedStoreId;
    final term = query.trim();
    if (store == null) throw StateError('Select a store first.');
    if (term.length < 2 || term.length > 100)
      throw ArgumentError('Search must contain 2–100 characters.');
    final offers = await repository.search(store, term);
    if (offers.any((o) => o.storeId != store))
      throw StateError('Product results did not match your selected store.');
    return RegionState(
      profile: state.profile,
      region: state.region,
      stores: state.stores,
      offers: offers,
    );
  }, clearOffers: true);
  void dispose() {
    _disposed = true;
    _generation++;
    _changes.close();
  }
}
