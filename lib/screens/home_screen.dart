import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../colors.dart';
import 'profile_screen.dart';
import 'map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool fromNearby = false;

  List<Widget> get _screens => [
        HomeMainScreen(onNearbyPressed: () {
          setState(() {
            fromNearby = true;
            _selectedIndex = 1;
          });
        }),
        MapScreen(showNearby: fromNearby),
        const ProfileScreen(),
      ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index != 1) fromNearby = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondaryBackground,
      body: SafeArea(child: _screens[_selectedIndex]),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Charging Stations',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeMainScreen extends StatefulWidget {
  final VoidCallback onNearbyPressed;

  const HomeMainScreen({super.key, required this.onNearbyPressed});

  @override
  State<HomeMainScreen> createState() => _HomeMainScreenState();
}

class _HomeMainScreenState extends State<HomeMainScreen> with TickerProviderStateMixin {
  String? userName;
  bool isLoading = true;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    fetchUserName();
  }

  Future<void> fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data != null && data['nickname'] != null) {
        setState(() {
          userName = data['nickname'];
          isLoading = false;
        });
      } else {
        setState(() {
          userName = 'Guest';
          isLoading = false;
        });
      }
    } else {
      setState(() {
        userName = 'Guest';
        isLoading = false;
      });
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(26),
              borderRadius: BorderRadius.circular(15),
            ),
            padding: const EdgeInsets.all(12),
            child: Icon(icon, size: 28, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'Welcome ${userName ?? 'Guest'} to',
                    style: TextStyle(
                      fontSize: 22,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'EV Plug',
                  style: TextStyle(
                    fontSize: 50,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Power up your journey now! \nHow can we help you today?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 30),

                // Quick Actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuickAction(
                      Icons.ev_station,
                      'Nearby Stations',
                      widget.onNearbyPressed,
                    ),
                    const SizedBox(height: 15),
                    _buildQuickAction(
                      Icons.car_repair,
                      'My Cars',
                      () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                          final data = doc.data();
                          final cars = data?['cars'] ?? [];
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: AppColors.secondaryBackground,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: Text(
                                'My Cars',
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              content: cars.isEmpty
                                  ? Text('No cars registered.', style: TextStyle(color: AppColors.textSecondary))
                                  : SizedBox(
                                      width: double.maxFinite,
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        itemCount: cars.length,
                                        separatorBuilder: (_, __) => const Divider(),
                                        itemBuilder: (context, index) {
                                          final car = cars[index];
                                          return ListTile(
                                            leading: const Icon(Icons.directions_car, color: AppColors.primary),
                                            title: Text(
                                              car['model'] ?? 'Unknown Model',
                                              style: TextStyle(color: AppColors.textPrimary),
                                            ),
                                            subtitle: Text(
                                              'Plug: ${car['charger_type'] ?? 'N/A'}',
                                              style: TextStyle(color: AppColors.textSecondary),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 15),
                    _buildQuickAction(
                      Icons.lightbulb,
                      'Recharge Tips',
                      () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: AppColors.secondaryBackground,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: Text(
                              'Recharge Tips',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            content: Text(
                              '⚡ Charge between 20–80% to extend battery life.\n\n'
                              '🚗 Avoid frequent fast charging if not necessary.\n\n'
                              '🧊 Park in shaded areas to protect the battery.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                                child: const Text('Got it'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Center(
                  child: Image.asset(
                    'assets/images/hero_ev_plug.png',
                    height: 300,
                  ),
                ),
              ],
            ),
          );
  }
}
