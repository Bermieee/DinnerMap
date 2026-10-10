import '../../layout/adaptive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'account_controller.dart';
import 'account_models.dart';

class HouseholdScreen extends StatefulWidget {
  final AccountState state;
  final AccountController? controller;
  final bool shared;
  final VoidCallback? onUseShared, onUseLocal, onImportLocal;
  const HouseholdScreen({
    super.key,
    required this.state,
    this.controller,
    this.shared = false,
    this.onUseShared,
    this.onUseLocal,
    this.onImportLocal,
  });
  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController(),
      invite = TextEditingController();
  bool register = false, changingPassword = false;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    invite.dispose();
    super.dispose();
  }

  Widget button(String label, VoidCallback? action) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: FilledButton(
      onPressed: widget.state.busy ? null : action,
      child: Text(label),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final c = widget.controller;
    return AdaptivePage(
      maxWidth: 800,
      child: ListView(
        key: const PageStorageKey('household-scroll'),
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Your household',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          if (s.busy) const LinearProgressIndicator(),
          if (s.error != null)
            Text(
              s.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (s.message != null) Text(s.message!),
          if (c == null) ...[
            const Text(
              'Shared accounts are not configured in this build. Your local meal plans and groceries remain available.',
            ),
          ] else if (s.session == null) ...[
            const Text(
              'Separate accounts let everyone in your household edit the same meals and grocery list.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            button(register ? 'Create account' : 'Sign in', () async {
              final p = password.text;
              password.clear();
              if (register) {
                await c.signUp(email.text, p);
              } else {
                await c.signIn(email.text, p);
              }
            }),
            TextButton(
              onPressed: s.busy
                  ? null
                  : () => setState(() => register = !register),
              child: Text(
                register
                    ? 'Already have an account? Sign in'
                    : 'Create a new account',
              ),
            ),
            TextButton(
              onPressed: s.busy ? null : () => c.resetPassword(email.text),
              child: const Text('Reset password'),
            ),
          ] else ...[
            Text(s.session!.email),
            const SizedBox(height: 12),
            if (s.session!.passwordRecovery || changingPassword) ...[
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              button('Save new password', () async {
                final p = password.text;
                password.clear();
                await c.updatePassword(p);
                if (mounted && c.state.error == null)
                  setState(() => changingPassword = false);
              }),
            ] else if (!s.session!.verified) ...[
              const Text(
                'Verify your email using the link in your inbox, then refresh.',
              ),
              button('Refresh verification', c.refresh),
            ] else if (s.household == null) ...[
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Household name'),
              ),
              button('Create household', () => c.createHousehold(name.text)),
              const SizedBox(height: 24),
              TextField(
                controller: invite,
                decoration: const InputDecoration(
                  labelText: 'Invitation token',
                ),
              ),
              button('Join household', () async {
                final t = invite.text;
                await c.redeemInvitation(t);
                if (c.state.household != null) invite.clear();
              }),
            ] else ...[
              Text(
                s.household!.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final m in s.members)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(m.email),
                ),
              button(
                widget.shared
                    ? 'Using shared household'
                    : 'Use shared household',
                widget.shared ? null : widget.onUseShared,
              ),
              button('Use local planner', widget.onUseLocal),
              if (widget.shared)
                button(
                  'Import local plan into empty household',
                  widget.onImportLocal,
                ),
              button('Create invitation', () async {
                final token = await c.createInvitation();
                if (token == null || !context.mounted) return;
                await showDinnerMapDialog<void>(
                  context: context,
                  builder: (ctx) => AdaptiveAlertDialog(
                    title: const Text('Invite a household member'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Single use; expires in 24 hours. Anyone you give this token can edit your household.',
                        ),
                        const SizedBox(height: 12),
                        SelectableText(token),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: token)),
                        child: const Text('Copy'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              }),
              button('Leave household', () async {
                final leave = await showDinnerMapDialog<bool>(
                  context: context,
                  builder: (ctx) => AdaptiveAlertDialog(
                    title: const Text('Leave this household?'),
                    content: const Text(
                      'You will lose shared access. Other members keep the plans.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Leave'),
                      ),
                    ],
                  ),
                );
                if (leave == true &&
                    mounted &&
                    identical(widget.controller, c) &&
                    c.state.session?.userId == s.session?.userId &&
                    c.state.household?.id == s.household?.id &&
                    !c.state.busy) {
                  widget.onUseLocal?.call();
                  await c.leaveHousehold();
                }
              }),
            ],
            if (!changingPassword && !s.session!.passwordRecovery)
              TextButton(
                onPressed: s.busy
                    ? null
                    : () => setState(() => changingPassword = true),
                child: const Text('Change password'),
              ),
            button('Sign out', () async {
              widget.onUseLocal?.call();
              await c.signOut();
            }),
          ],
          const SizedBox(height: 24),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Kroger and Walmart are not connected yet. Live product prices and cart transfer follow household sharing.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
