import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/planner/planner_controller.dart';
import 'data/planner_repository.dart';
import 'features/planner/planner_screen.dart';
import 'features/planner/recipe_screen.dart';
import 'features/shopping/shopping_screen.dart';
import 'features/household/account_providers.dart';
import 'features/household/account_models.dart';
import 'features/household/household_screen.dart';
import 'features/sync/shared_planner_controller.dart';

class DinnerMapApp extends StatelessWidget {
  const DinnerMapApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DinnerMap',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff628aff),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xff0b1019),
      cardTheme: const CardThemeData(color: Color(0xff151d2a)),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: const DinnerMapShell(),
  );
}

Future<void> saveText(
  BuildContext context,
  String text,
  String name,
  String extension,
) async {
  try {
    await FileSaver.instance.saveFile(
      name: name,
      bytes: Uint8List.fromList(utf8.encode(text)),
      fileExtension: extension,
      mimeType: MimeType.other,
    );
  } catch (e) {
    if (context.mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}

Future<String?> promptText(
  BuildContext context,
  String title, {
  String initial = '',
  String hint = '',
  int lines = 1,
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 500,
        child: TextField(
          controller: controller,
          autofocus: true,
          maxLines: lines,
          decoration: InputDecoration(hintText: hint),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  return result;
}

class DinnerMapShell extends ConsumerStatefulWidget {
  const DinnerMapShell({super.key});
  @override
  ConsumerState<DinnerMapShell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<DinnerMapShell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(plannerProvider);
    final accountController = ref.watch(accountControllerProvider);
    final account =
        ref.watch(accountStateProvider).asData?.value ??
        accountController?.state ??
        const AccountState();
    final sharedContext = ref.watch(activeHouseholdProvider);
    final editing = ref.read(plannerProvider.notifier);
    final householdFallback = HouseholdScreen(
      state: account,
      controller: accountController,
      shared: sharedContext != null,
      onUseShared: () => ref.read(useSharedProvider.notifier).state = true,
      onUseLocal: () => ref.read(useSharedProvider.notifier).state = false,
    );
    final wide = MediaQuery.sizeOf(context).width >= 850;
    const destinations = [
      NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined),
        label: 'Calendar',
      ),
      NavigationDestination(
        icon: Icon(Icons.restaurant_menu),
        label: 'Recipes',
      ),
      NavigationDestination(
        icon: Icon(Icons.shopping_basket_outlined),
        label: 'Shopping',
      ),
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        label: 'Household',
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('DinnerMap'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Chip(
              label: Text(sharedContext == null ? 'LOCAL DEMO' : 'SHARED'),
              avatar: const Icon(Icons.phonelink, size: 16),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (action) async {
              final controller = ref.read(plannerProvider.notifier);
              if (action == 'backup') {
                final s = data.asData?.value;
                final raw =
                    s?.encode() ??
                    await ref.read(repositoryProvider).rawBackup();
                if (raw != null && context.mounted)
                  await saveText(context, raw, 'dinnermap-backup', 'json');
              } else if (action == 'import' && sharedContext == null) {
                final raw = await promptText(
                  context,
                  'Restore JSON backup',
                  lines: 8,
                );
                if (raw != null && raw.isNotEmpty) {
                  try {
                    await controller.importBackup(raw);
                  } catch (e) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Backup not restored: $e')),
                      );
                  }
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'backup',
                child: Text('Export backup'),
              ),
              if (sharedContext == null)
                const PopupMenuItem(
                  value: 'import',
                  child: Text('Restore backup'),
                ),
            ],
          ),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              labelType: NavigationRailLabelType.all,
              destinations: destinations
                  .map(
                    (d) => NavigationRailDestination(
                      icon: d.icon,
                      label: Text(d.label),
                    ),
                  )
                  .toList(),
            ),
          Expanded(
            child: data.when(
              loading: () => tab == 3
                  ? householdFallback
                  : const Center(child: CircularProgressIndicator()),
              error: (e, st) => tab == 3
                  ? householdFallback
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber, size: 48),
                            const Text('Your saved data could not be loaded.'),
                            Text('$e'),
                            const Text(
                              'The saved payload has been preserved. Export it or restore a valid backup using the menu.',
                            ),
                          ],
                        ),
                      ),
                    ),
              data: (s) => Column(
                children: [
                  if (ref.read(plannerProvider.notifier).saveError != null)
                    MaterialBanner(
                      content: Text(
                        'Changes are not saved: ${ref.read(plannerProvider.notifier).saveError}',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Clipboard.setData(
                            ClipboardData(text: s.encode()),
                          ),
                          child: const Text('Copy backup'),
                        ),
                      ],
                    ),
                  if (editing.syncMessage != null)
                    MaterialBanner(
                      content: Text(editing.syncMessage!),
                      actions: [
                        if (editing is SharedPlannerController &&
                            editing.pendingChanges != null) ...[
                          TextButton(
                            onPressed: () async {
                              await showDialog<void>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Review uncertain edit'),
                                  content: SingleChildScrollView(
                                    child: SelectableText(
                                      editing.pendingChanges.toString(),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: const Text('Review'),
                          ),
                          TextButton(
                            onPressed: editing.online
                                ? editing.retryPending
                                : null,
                            child: const Text('Retry edit'),
                          ),
                          TextButton(
                            onPressed: editing.discardPending,
                            child: const Text('Keep current plan'),
                          ),
                        ],
                        if (editing is SharedPlannerController &&
                            editing.conflictChanges != null)
                          TextButton(
                            onPressed: () async {
                              final apply = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Review conflicting edit'),
                                  content: SizedBox(
                                    width: 600,
                                    child: SingleChildScrollView(
                                      child: SelectableText(
                                        editing.conflictPreview(),
                                      ),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Use current version'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Reapply my edit'),
                                    ),
                                  ],
                                ),
                              );
                              if (apply == true) {
                                await editing.reapplyConflict();
                              } else if (apply == false) {
                                await editing.discardConflict();
                              }
                            },
                            child: const Text('Review'),
                          ),
                        if (editing is SharedPlannerController)
                          TextButton(
                            onPressed: editing.refresh,
                            child: const Text('Reload'),
                          ),
                      ],
                    ),
                  Expanded(
                    child: AbsorbPointer(
                      absorbing: tab != 3 && !editing.canEdit,
                      child: switch (tab) {
                        0 => PlannerScreen(snapshot: s),
                        1 => RecipeScreen(snapshot: s),
                        2 => ShoppingScreen(snapshot: s),
                        _ => HouseholdScreen(
                          state: account,
                          controller: accountController,
                          shared: sharedContext != null,
                          onUseShared: () =>
                              ref.read(useSharedProvider.notifier).state = true,
                          onUseLocal: () =>
                              ref.read(useSharedProvider.notifier).state =
                                  false,
                          onImportLocal: () async {
                            final raw = await ref
                                .read(repositoryProvider)
                                .rawBackup();
                            if (raw == null || !context.mounted) return;
                            final local = PlannerSnapshot.decode(raw);
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Import local plan?'),
                                content: Text(
                                  '${local.entries.length} meals, ${local.recipes.length} recipes, and ${local.list?.manualItems.length ?? 0} manual groceries. Only an empty household can import. Your local copy stays on this phone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Import'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              try {
                                await editing.importBackup(raw);
                              } catch (e) {
                                if (context.mounted)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Import failed: $e'),
                                    ),
                                  );
                              }
                            }
                          },
                        ),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: destinations,
            ),
    );
  }
}
