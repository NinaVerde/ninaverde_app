}

/// Kitchen Operations hub - combines KDS and driver dashboard
class _KitchenOpsPage extends StatelessWidget {
  const _KitchenOpsPage();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFD84315),
          title: const Text(
            '🔥 Kitchen Operations',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.restaurant), text: 'Kitchen Display'),
              Tab(icon: Icon(Icons.delivery_dining), text: 'Drivers'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            KitchenDisplayScreen(),
            DriverDashboardScreen(),
          ],
        ),
      ),
    );
  }
}
