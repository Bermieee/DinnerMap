import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../layout/adaptive_page.dart';
import '../../layout/adaptive_layout.dart';
import 'region_controller.dart';
import 'region_models.dart';
import 'region_providers.dart';

class RegionScreen extends ConsumerWidget {
  const RegionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(regionControllerProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final policy = AdaptiveLayout.resolve(
          size: constraints.biggest,
          padding: EdgeInsets.fromLTRB(
            math.max(media.padding.left, media.viewInsets.left),
            math.max(media.padding.top, media.viewInsets.top),
            math.max(media.padding.right, media.viewInsets.right),
            math.max(media.padding.bottom, media.viewInsets.bottom),
          ),
          displayFeatures: media.displayFeatures,
          textScale: media.textScaler.scale(1),
        );
        var region = policy.primaryRegion;
        final second = policy.secondaryRegion;
        if (second != null &&
            second.width * second.height > region.width * region.height)
          region = second;
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: region,
                child: MediaQuery(
                  data: shiftedMedia(
                    media,
                    region.topLeft,
                    region.size,
                  ).copyWith(viewInsets: EdgeInsets.zero),
                  child: Scaffold(
                    resizeToAvoidBottomInset: false,
                    appBar: AppBar(
                      title: const Text(
                        'Stores & prices',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    body: RegionPanel(
                      key: ValueKey(controller),
                      controller: controller,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class RegionPanel extends StatefulWidget {
  final RegionController controller;
  const RegionPanel({super.key, required this.controller});
  @override
  State<RegionPanel> createState() => _RegionPanelState();
}

class _RegionPanelState extends State<RegionPanel> {
  final zip = TextEditingController(), query = TextEditingController();
  int radius = 25;
  OfferSort sort = OfferSort.packageLow;
  String unitFamily = 'mass';
  RegionProfile? _lastProfile;
  bool dirty = false;
  @override
  void dispose() {
    zip.dispose();
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<RegionState>(
    stream: widget.controller.changes,
    initialData: widget.controller.state,
    builder: (context, snapshot) {
      final s = snapshot.data ?? widget.controller.state;
      if (s.profile != null && !identical(s.profile, _lastProfile)) {
        if (!dirty) {
          zip.text = s.profile!.zip;
          radius = s.profile!.radiusMiles;
        }
        _lastProfile = s.profile;
      }
      final offers = sortProductOffers(s.offers, sort, unitFamily: unitFamily);
      final profileMatches =
          s.profile?.zip == zip.text.trim() && s.profile?.radiusMiles == radius;
      final selected = s.profile?.selectedStoreId;
      return AdaptivePage(
        maxWidth: 1000,
        child: ListView(
          key: const PageStorageKey('region-scroll'),
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Shop near you',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Location preferences belong to your account. Household plans and grocery lists stay shared.',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('region-zip'),
              controller: zip,
              enabled: !s.busy,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              decoration: const InputDecoration(
                labelText: 'US ZIP code',
                hintText: '40165',
              ),
              onChanged: (_) => setState(() => dirty = true),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              isExpanded: true,
              key: ValueKey(radius),
              initialValue: radius,
              decoration: const InputDecoration(labelText: 'Search radius'),
              items: ({5, 10, 25, 50, 100, radius}.toList()..sort())
                  .map(
                    (r) => DropdownMenuItem(value: r, child: Text('$r miles')),
                  )
                  .toList(),
              onChanged: s.busy
                  ? null
                  : (r) => setState(() {
                      radius = r!;
                      dirty = true;
                    }),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: s.busy
                      ? null
                      : () async {
                          await widget.controller.saveProfile(
                            zip.text.trim(),
                            radius,
                          );
                          if (mounted && widget.controller.state.error == null)
                            setState(() => dirty = false);
                        },
                  child: const Text('Save location'),
                ),
                OutlinedButton(
                  onPressed: s.busy || s.profile == null || !profileMatches
                      ? null
                      : widget.controller.discover,
                  child: const Text('Find nearby stores'),
                ),
              ],
            ),
            if (!profileMatches && s.profile != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Save your changed location before searching.'),
              ),
            if (s.busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
            if (s.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  s.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (s.profile != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Saved ZIP: ${s.profile!.zip} • ${s.profile!.radiusMiles} miles',
                ),
              ),
            if (s.region != null)
              Text(
                '${s.region!.city}, ${s.region!.state} • ${s.region!.zip}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            const SizedBox(height: 12),
            const Text(
              'Find Kroger-family stores and local prices using your saved ZIP and radius. Only returned nearby locations are shown.',
            ),
            const Text('Walmart: partner access pending.'),
            const Text('Amazon: comparison access pending.'),
            if (s.region != null &&
                s.stores.isEmpty &&
                !s.busy &&
                s.error == null)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'No Kroger-family locations returned within this radius. Try a wider search.',
                ),
              ),
            if (s.stores.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Nearby stores (up to 50 results)'),
              ...s.stores.map(
                (store) => Card(
                  child: ListTile(
                    title: Text(store.displayName),
                    subtitle: Text(store.address),
                    trailing: Icon(
                      selected == store.id
                          ? Icons.check_circle
                          : Icons.store_outlined,
                    ),
                    selected: selected == store.id,
                    onTap: s.busy || !profileMatches
                        ? null
                        : () async {
                            query.clear();
                            await widget.controller.selectStore(store);
                          },
                  ),
                ),
              ),
            ],
            if (selected != null) ...[
              const SizedBox(height: 16),
              Text(
                'Products at ${s.selectedStore?.displayName ?? 'selected store'} • store $selected',
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('product-query'),
                controller: query,
                enabled: !s.busy,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Search an ingredient or product',
                ),
                onSubmitted: s.busy || !profileMatches
                    ? null
                    : (_) => widget.controller.search(query.text),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: s.busy || !profileMatches
                      ? null
                      : () => widget.controller.search(query.text),
                  child: const Text('Search products'),
                ),
              ),
            ],
            if (s.searchedQuery != null &&
                s.offers.isEmpty &&
                !s.busy &&
                s.error == null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'No products returned for “${s.searchedQuery}”. Try a different search.',
                ),
              ),
            if (s.offers.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<OfferSort>(
                isExpanded: true,
                initialValue: sort,
                decoration: const InputDecoration(labelText: 'Sort prices'),
                items: const [
                  DropdownMenuItem(
                    value: OfferSort.packageLow,
                    child: Text(
                      'Package price: lowest first',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: OfferSort.packageHigh,
                    child: Text(
                      'Package price: highest first',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: OfferSort.unitLow,
                    child: Text(
                      'Unit price: lowest first',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: OfferSort.unitHigh,
                    child: Text(
                      'Unit price: highest first',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => sort = v!),
              ),
              if (sort == OfferSort.unitLow || sort == OfferSort.unitHigh) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: unitFamily,
                  decoration: const InputDecoration(labelText: 'Compare units'),
                  items: const [
                    DropdownMenuItem(
                      value: 'mass',
                      child: Text(
                        'Weight (per lb)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'volume',
                      child: Text(
                        'Volume (per fl oz)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'count',
                      child: Text(
                        'Count (each)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => unitFamily = v!),
                ),
                const Text(
                  'Other unit families and unknown quantities appear after comparable offers.',
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'Prices exclude taxes and may change. Availability is reported by the provider. Review package sizes before buying.',
              ),
              ...offers.map(
                (o) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(o.size.isEmpty ? 'Package size unknown' : o.size),
                        Text(
                          o.knownPrice
                              ? '\$${o.price!.toStringAsFixed(2)} ${o.soldBy == 'UNIT'
                                    ? 'per package'
                                    : o.soldBy == 'WEIGHT'
                                    ? '(variable weight)'
                                    : '(price basis unknown)'}'
                              : 'Price unavailable',
                        ),
                        if (o.unitPrice != null)
                          Text(
                            '\$${o.unitPrice!.toStringAsFixed(2)} ${o.unitLabel}',
                          ),
                        Text(
                          '${s.selectedStore?.displayName ?? 'Selected store'} • store ${o.storeId} • availability: ${o.availability}',
                        ),
                        if (o.retrievedAt != null)
                          Text('Retrieved ${o.retrievedAt!.toLocal()}'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}
