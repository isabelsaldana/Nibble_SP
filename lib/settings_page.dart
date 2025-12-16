import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'pages/trash_page.dart';


class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _confirmAndLogout(BuildContext context) async {
    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can log back in anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // Account
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'Account',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (user?.email != null)
            ListTile(
              leading: const Icon(Icons.alternate_email),
              title: Text(user!.email!),
              subtitle: const Text('Signed in email'),
            ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Edit profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/profile/edit'),
          ),

          // ✅ Recently Deleted Recipes moved here
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Recently Deleted Recipes'),
            subtitle: const Text('View and restore deleted recipes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TrashPage()),
              );
            },
          ),

          // Preferences
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'Preferences',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: push notifications settings page
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Privacy & safety'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: push privacy settings page
            },
          ),

          // Dark Mode Toggle
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode'),
            trailing: Switch(
              value: themeProvider.isDarkMode,
              onChanged: (_) => themeProvider.toggleTheme(),
            ),
          ),

          // About
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'About',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Nibble'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Nibble',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2025 Nibble Team',
              );
            },
          ),

          const Divider(height: 32),

          // Logout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
              onPressed: () => _confirmAndLogout(context),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
