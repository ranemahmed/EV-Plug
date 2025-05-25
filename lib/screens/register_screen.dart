import 'package:flutter/material.dart';
import '../colors.dart';
import 'registration_success_screen.dart';
import 'welcome_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final nicknameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  List<CarDetails> cars = [CarDetails()];

  final List<String> chargerTypes = ['GB/T', 'Type 2', 'CCS 2', 'CHAdeMO'];

  Future<void> registerUser() async {
    if (_formKey.currentState!.validate() &&
        cars.every((car) => car.isValid())) {
      try {
        // Step 1: Create user with Firebase Authentication
        final auth = FirebaseAuth.instance;
        final userCredential = await auth.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        final user = userCredential.user;

        if (user != null) {
          //Step 2: Navigate to success screen immediately
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const RegistrationSuccessScreen(),
            ),
            (route) => false,
          );

          //Step 3: Save user profile + car info to Firestore in background
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                "first_name": firstNameController.text.trim(),
                "last_name": lastNameController.text.trim(),
                "nickname": nicknameController.text.trim(),
                "phone": phoneController.text.trim(),
                "email": emailController.text.trim(),
                "cars":
                    cars
                        .map(
                          (car) => {
                            "brand": car.brandController.text.trim(),
                            "model": car.modelController.text.trim(),
                            "year": car.yearController.text.trim(),
                            "charger_type": car.selectedChargerType,
                          },
                        )
                        .toList(),
              });
        }
      } on FirebaseAuthException catch (e) {
        String message;
        if (e.code == 'email-already-in-use') {
          message = 'This email is already registered.';
        } else {
          message = 'Registration failed. Try again.';
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unexpected error occurred.')),
        );
      }
    }
  }

  void addCar() {
    setState(() {
      cars.add(CarDetails());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondaryBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),

            IconButton(
              icon: const Icon(Icons.arrow_back),
              color: AppColors.textPrimary,
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                );
              },
            ),

            const SizedBox(height: 10),

            Center(
              child: Image.asset(
                'assets/images/register_illustration.png',
                height: 200,
              ),
            ),

            const SizedBox(height: 30),

            Form(
              key: _formKey,
              child: Container(
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

                    _buildTextField(
                      firstNameController,
                      'First Name',
                      Icons.person,
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Enter your first name';
                        if (!RegExp(r'^[a-zA-Z]+$').hasMatch(value))
                          return 'Only letters allowed';
                        if (value.length > 30)
                          return 'Maximum 30 characters allowed';
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    _buildTextField(
                      lastNameController,
                      'Last Name',
                      Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Enter your last name';
                        if (!RegExp(r'^[a-zA-Z]+$').hasMatch(value))
                          return 'Only letters allowed';
                        if (value.length > 30)
                          return 'Maximum 30 characters allowed';
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    _buildTextField(
                      nicknameController,
                      'Nickname',
                      Icons.tag_faces,
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Enter your nickname';
                        if (!RegExp(r'^[a-zA-Z]+$').hasMatch(value))
                          return 'Only letters allowed';
                        if (value.length > 30)
                          return 'Maximum 30 characters allowed';
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    _buildTextField(
                      phoneController,
                      'Phone Number',
                      Icons.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Enter your phone number';
                        if (!RegExp(r'^[0-9]{11}$').hasMatch(value))
                          return 'Phone must be exactly 11 digits';
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    _buildTextField(
                      emailController,
                      'Email Address',
                      Icons.email,
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Enter your email';
                        if (!RegExp(
                          r'^[a-zA-Z0-9_.]+@(gmail|outlook|yahoo|hotmail)\.com$',
                        ).hasMatch(value)) {
                          return 'Must be gmail, outlook, yahoo, or hotmail address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    _buildTextField(
                      passwordController,
                      'Password',
                      Icons.lock,
                      isPassword: true,
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Enter your password';
                        if (value.length < 6)
                          return 'Password must be at least 6 characters';
                        if (value.length > 20)
                          return 'Password cannot exceed 20 characters';
                        return null;
                      },
                    ),

                    const SizedBox(height: 30),

                    const Text(
                      'Car Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    ...cars.map((car) => _buildCarSection(car)).toList(),

                    const SizedBox(height: 10),

                    Center(
                      child: OutlinedButton.icon(
                        onPressed: addCar,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Another Car'),
                      ),
                    ),

                    const SizedBox(height: 30),

                    Center(
                      child: SizedBox(
                        width: 250,
                        child: ElevatedButton(
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
                          onPressed: registerUser,
                          child: const Text(
                            'Register',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.textPrimary),
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildCarSection(CarDetails car) {
    return Column(
      children: [
        const Divider(thickness: 1, color: Colors.black26),
        const SizedBox(height: 10),
        _buildCarTextField(
          car.brandController,
          'Car Brand',
          Icons.directions_car,
          (value) {
            if (value == null || value.isEmpty) return 'Enter car brand';
            if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value))
              return 'Only letters allowed';
            return null;
          },
        ),
        const SizedBox(height: 10),
        _buildCarTextField(
          car.modelController,
          'Car Model',
          Icons.directions_car_filled,
          (value) {
            if (value == null || value.isEmpty) return 'Enter car model';
            if (!RegExp(r'^[a-zA-Z0-9\s]+$').hasMatch(value))
              return 'Only letters and numbers allowed';

            return null;
          },
        ),
        const SizedBox(height: 10),
        _buildCarTextField(
          car.yearController,
          'Car Year',
          Icons.calendar_today,
          (value) {
            if (value == null || value.isEmpty) return 'Enter car year';
            if (!RegExp(r'^[0-9]{4}$').hasMatch(value))
              return 'Year must be exactly 4 digits';
            return null;
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.ev_station,
              color: AppColors.textPrimary,
            ),
            filled: true,
            fillColor: AppColors.inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
          hint: const Text('Select Charger Type'),
          value: car.selectedChargerType,
          items:
              chargerTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
          onChanged: (value) {
            setState(() {
              car.selectedChargerType = value;
            });
          },
          validator:
              (value) => value == null ? 'Please select a charger type' : null,
        ),
      ],
    );
  }

  Widget _buildCarTextField(
    TextEditingController controller,
    String hint,
    IconData icon,
    String? Function(String?) validator,
  ) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.textPrimary),
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class CarDetails {
  final TextEditingController brandController = TextEditingController();
  final TextEditingController modelController = TextEditingController();
  final TextEditingController yearController = TextEditingController();
  String? selectedChargerType;

  bool isValid() {
    return brandController.text.isNotEmpty &&
        modelController.text.isNotEmpty &&
        yearController.text.isNotEmpty &&
        selectedChargerType != null;
  }
}
