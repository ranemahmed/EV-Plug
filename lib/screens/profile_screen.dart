import 'package:flutter/material.dart';
import '../colors.dart';
import '../screens/welcome_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        setState(() {
          userData = doc.data();
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load profile data")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondaryBackground,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : userData == null
              ? const Center(child: Text('Failed to load user data.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      Image.asset(
                        'assets/images/profile_illustration.png',
                        height: 60,
                      ),
                      const SizedBox(height: 30),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Personal Information',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildProfileRow('First Name', userData!['first_name'] ?? ''),
                            const SizedBox(height: 15),
                            _buildProfileRow('Last Name', userData!['last_name'] ?? ''),
                            const SizedBox(height: 15),
                            _buildProfileRow('Nickname', userData!['nickname'] ?? ''),
                            const SizedBox(height: 15),
                            _buildProfileRow('Phone Number', userData!['phone'] ?? ''),
                            const SizedBox(height: 15),
                            _buildProfileRow('Email', userData!['email'] ?? ''),
                            const SizedBox(height: 30),
                            const Divider(thickness: 1, color: Colors.black12),
                            const SizedBox(height: 20),
                            const Text(
                              'Car Details',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (userData!['cars'] != null)
                              for (var car in userData!['cars'])
                                Column(
                                  children: [
                                    _buildProfileRow('Brand', car['brand'] ?? ''),
                                    const SizedBox(height: 10),
                                    _buildProfileRow('Model', car['model'] ?? ''),
                                    const SizedBox(height: 10),
                                    _buildProfileRow('Year', car['year'] ?? ''),
                                    const SizedBox(height: 10),
                                    _buildProfileRow('Charger Type', car['charger_type'] ?? ''),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                            ElevatedButton.icon(
                              onPressed: () => _showAddCarDialog(),
                              icon: const Icon(Icons.add),
                              label: const Text('Add New Car'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      Center(
                        child: SizedBox(
                          width: 250,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 8,
                              shadowColor: Colors.black45,
                              minimumSize: const Size.fromHeight(50),
                            ),
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                                (route) => false,
                              );
                            },
                            icon: const Icon(Icons.logout),
                            label: const Text(
                              'Logout',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileRow(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showAddCarDialog() {
    final brandController = TextEditingController();
    final modelController = TextEditingController();
    final yearController = TextEditingController();
    final chargerTypeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.secondaryBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Add New Car',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              children: [
                _buildCarInputField('Brand', brandController),
                const SizedBox(height: 10),
                _buildCarInputField('Model', modelController),
                const SizedBox(height: 10),
                _buildCarInputField('Year', yearController, keyboard: TextInputType.number),
                const SizedBox(height: 10),
                _buildCarInputField('Charger Type', chargerTypeController),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final car = {
                    'brand': brandController.text.trim(),
                    'model': modelController.text.trim(),
                    'year': yearController.text.trim(),
                    'charger_type': chargerTypeController.text.trim(),
                  };

                  await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                    'cars': FieldValue.arrayUnion([car])
                  });

                  Navigator.pop(context);
                  fetchUserData(); // refresh
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCarInputField(String label, TextEditingController controller,
      {TextInputType keyboard = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
