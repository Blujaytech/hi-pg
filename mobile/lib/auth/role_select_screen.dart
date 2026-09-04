import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// First screen shown to a signed-out user -- mirrors prototype.html's
/// Owner/Student entry split (technical plan §1).
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.apartment_rounded, size: 72),
              const SizedBox(height: 16),
              Text('PG Platform', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Manage or discover PG accommodation.', textAlign: TextAlign.center),
              const SizedBox(height: 40),
              FilledButton.icon(
                onPressed: () => context.go('/owner/login'),
                icon: const Icon(Icons.storefront_outlined),
                label: const Text("I'm a PG Owner"),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.go('/student/login'),
                icon: const Icon(Icons.school_outlined),
                label: const Text("I'm a Student"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
