import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/planner/planner_controller.dart';
import 'features/planner/planner_screen.dart';
import 'features/planner/recipe_screen.dart';
import 'features/shopping/shopping_screen.dart';

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
              label: const Text('LOCAL DEMO'),
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
              } else if (action == 'import') {
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
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
                  Expanded(
                    child: switch (tab) {
                      0 => PlannerScreen(snapshot: s),
                      1 => RecipeScreen(snapshot: s),
                      2 => ShoppingScreen(snapshot: s),
                      _ => const HouseholdScreen(),
                    },
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

class HouseholdScreen extends StatelessWidget {
  const HouseholdScreen({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text('Your household', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 16),
      const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.group_outlined, size: 40),
              SizedBox(height: 12),
              Text('Shared plans are the next stage'),
              SizedBox(height: 8),
              Text(
                'This demo saves only on this browser or device. Accounts, invitations and live sync are not connected yet. Everyone in your household will be able to edit once sharing is implemented.',
              ),
            ],
          ),
        ),
      ),
      const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kroger • Not connected'),
              SizedBox(height: 8),
              Text('Walmart • Access approval required'),
              SizedBox(height: 8),
              Text(
                'Product matching, lowest/highest price sorting and reviewed cart transfer are planned. No live prices or cart actions are available in this demo.',
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
