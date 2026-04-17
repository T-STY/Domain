import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Assuming you have these established in your project
import '../../../components/icon_with_background.dart';
import '../../../constants/constants.dart';
import 'auth/components/terms_conds.dart';


class SignupWebPage extends StatefulWidget {
  const SignupWebPage({super.key});

  @override
  State<SignupWebPage> createState() => _SignupWebPageState();
}

class _SignupWebPageState extends State<SignupWebPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();

  bool _acceptTerms = false;
  bool _isLoading = false;

  Future<void> _signUpUser() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Reference the Master Coupon document
      final DocumentReference masterCouponRef =
      FirebaseFirestore.instance.collection('coupons').doc('WELCOME');

      // 2. Run a Transaction
      bool canRegister = await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(masterCouponRef);
        if (!snapshot.exists) throw Exception("El cupón maestro no existe.");

        int remaining = snapshot.get('remaining_uses') ?? 0;
        if (remaining > 0) {
          transaction.update(masterCouponRef, {'remaining_uses': remaining - 1});
          return true;
        } else {
          return false;
        }
      });

      // SAFETY CHECK 1: Ensure widget is still on screen
      if (!mounted) return;

      if (!canRegister) {
        _showLimitReachedDialog();
        setState(() => _isLoading = false);
        return;
      }

      // 3. Create Auth User
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // SAFETY CHECK 2
      if (!mounted) return;

      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName(_nameController.text);
      }

      final userDocRef = FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid);

      // 4. Save User Info
      await userDocRef.set({
        'userInfo': {
          'name': _nameController.text,
          'email': _emailController.text.trim(),
          'phone': _phoneNumberController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        }
      });

      // 5. Assign Coupon
      final expiryDate = DateTime(2026, 12, 30, 23, 59, 59);
      await userDocRef.collection('coupons').doc('MADRUGADOR').set({
        'code': 'WELCOME',
        'expiry_date': Timestamp.fromDate(expiryDate),
        'max_discount': 50,
        'percentage': 15,
        'used': false,
      });

      // 6. Send Verification
      await userCredential.user!.sendEmailVerification();

      // SAFETY CHECK 3
      if (!mounted) return;
      _showSuccessDialog();

    } on FirebaseAuthException catch (e) {
      if (!mounted) return; // FIX: Check mounted before using context in catch

      String message = "Ocurrió un error en la autenticación.";
      if (e.code == 'weak-password') {
        message = 'La contraseña es muy débil.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Ya existe una cuenta con este correo.';
      } else if (e.code == 'invalid-email') {
        message = 'El correo electrónico no es válido.';
      }
      _showErrorSnackbar(message);

    } on FirebaseException catch (e) {
      if (!mounted) return; // FIX: Check mounted here too

      String message = "Error de base de datos: ${e.message}";
      if (e.code == 'permission-denied') {
        message = "Permiso denegado: Revisa las reglas de Firestore.";
      }
      _showErrorSnackbar(message);

    } catch (e) {
      if (!mounted) return; // FIX: Check mounted here too
      _showErrorSnackbar("Error desconocido: $e");

    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- UI HELPER METHODS ---

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("¡Registro Exitoso!"),
        content: const Text("Hemos enviado un correo de verificación. Revisa tu bandeja de entrada."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Navigate to home or login screen here
            },
            child: const Text("Ir al Inicio"),
          )
        ],
      ),
    );
  }

  void _showLimitReachedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Lo sentimos"),
        content: const Text("Ya se han agotado los 50 registros de preventa."),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Entendido"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Section
              Padding(
                padding: const EdgeInsets.all(10),
                child: SizedBox(
                  height: 60,
                  width: 350,
                  child: AspectRatio(
                    aspectRatio: 1 / 1,
                    child: Image.asset(
                      isDarkMode ? AppImages.logowhite : AppImages.logo, // Conditionally set the logo based on the theme
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              Text(
                "Registro Anticipado",
                style: TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Gemini',
                  color: isDarkMode ? AppColors.defaultWhite : AppColors.defaultBlack,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Regístrate hoy y obtén 15% de descuento.",
                style: TextStyle(
                  fontSize: 14.0,
                  fontFamily: 'Gordita',
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 30),

              // Web Container (Card-like look)
              Container(
                width: 400, // Constrain width for Web
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Form(
                  child: Column(
                    children: [
                      // Name
                      _buildTextField(
                        controller: _nameController,
                        label: 'Nombre',
                        hint: 'John Doe',
                        icon: IconlyBold.profile,
                        context: context,
                      ),
                      const SizedBox(height: AppDefaults.margin),

                      // Phone
                      _buildTextField(
                        controller: _phoneNumberController,
                        label: 'Teléfono',
                        hint: '+521234567890',
                        icon: IconlyBold.call,
                        context: context,
                      ),
                      const SizedBox(height: AppDefaults.margin),

                      // Email
                      _buildTextField(
                        controller: _emailController,
                        label: 'Correo',
                        hint: 'tu@email.com',
                        icon: IconlyBold.message,
                        context: context,
                      ),
                      const SizedBox(height: AppDefaults.margin),

                      // Password
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Contraseña',
                        hint: '*********',
                        icon: IconlyBold.lock,
                        isPassword: true,
                        context: context,
                      ),
                      const SizedBox(height: 20),

                      // Terms and Switch
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => const TermsAndConditionsScreen(),
                                );
                              },
                              child: Text(
                                'Acepto contrato de uso',
                                style: TextStyle(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Gordita',
                                  color: isDarkMode ? AppColors.defaultWhite : AppColors.defaultBlack,
                                ),
                              ),
                            ),
                          ),
                          Switch(
                            value: _acceptTerms,
                            onChanged: (val) => setState(() => _acceptTerms = val),
                            activeColor: Colors.black,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () {
                            if (_acceptTerms) {
                              _signUpUser();
                            } else {
                              _showErrorDialog(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                            'Obtener mi descuento',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Gordita',
                              fontWeight: FontWeight.bold,
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
      ),
    );
  }

  // Helper widget to keep code clean
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required BuildContext context,
    bool isPassword = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
        filled: true,
        prefixIcon: ColorFiltered(
          colorFilter: ColorFilter.mode(
            Theme.of(context).iconTheme.color ?? Colors.grey,
            BlendMode.srcIn,
          ),
          child: IconWithBackground(iconData: icon),
        ),
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.never,
      ),
    );
  }

  void _showErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Error"),
        content: const Text("Por favor, acepte los términos y condiciones."),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("OK"))
        ],
      ),
    );
  }
}
