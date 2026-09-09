import 'package:flutter/material.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/map/screens/map_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/downloads/screens/downloads_screen.dart';
import '../../features/settings/screens/settings_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.deepPurple,
            ),
            child: Center(
              child: Text(
                'Archive Manager',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Главная'),
            onTap: () => _navigateTo(context, const HomeScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Карта'),
            onTap: () => _navigateTo(context, const MapScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Отчеты'),
            onTap: () => _navigateTo(context, const ReportsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Загрузки'),
            onTap: () => _navigateTo(context, const DownloadsScreen()),
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Настройки'),
            onTap: () => _navigateTo(context, const SettingsScreen()),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
