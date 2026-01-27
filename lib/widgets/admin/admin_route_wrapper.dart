import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../state/app_state.dart';
import '../../theme/brand_colors.dart';

class AdminRoute extends StatelessWidget {
  final Widget child;

  const AdminRoute({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    
    // We use ValueListenableBuilder to reactively check permission
    return ValueListenableBuilder<bool>(
      valueListenable: app.isManager,
      builder: (context, isManager, _) {
        if (!isManager) {
          // Identify Guest/User vs Admin
          // Redirect to Home after a brief "Access Denied" frame?
          // Or just show Access Denied screen.
          // Better: Show Access Denied screen.
          
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_person, size: 80, color: Colors.red),
                  const SizedBox(height: 20),
                  const Text(
                    "Access Denied",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text("You do not have permission to view this page."),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: nvGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Go Home"),
                  ),
                ],
              ).animate().fadeIn().scale(),
            ),
          );
        }

        return child;
      },
    );
  }
}
