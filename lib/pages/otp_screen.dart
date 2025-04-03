import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class OTPScreen extends StatefulWidget {
  const OTPScreen({super.key});

  @override
  _OTPScreenState createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _onOTPChanged(int index, String value) {
    if (value.length == 1) {
      if (index < 5) {
        FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
      } else {
        FocusScope.of(context).unfocus();
      }
    } else if (value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
    }
  }

  Future<void> _verifyOTP() async {
    String otp = _otpControllers.map((controller) => controller.text).join();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un code OTP complet')),
      );
      return;
    }

    try {
      // Récupérer les arguments passés depuis SignUpScreen
      final Map<String, dynamic>? arguments =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (arguments == null ||
          arguments['verificationId'] == null ||
          arguments['email'] == null ||
          arguments['password'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: Données manquantes')),
        );
        return;
      }

      final String verificationId = arguments['verificationId'];
      final String email = arguments['email'];
      final String password = arguments['password'];
      final String phoneNumber = arguments['phoneNumber'];
      final String nom = arguments['nom'];
      final String prenom = arguments['prenom'];
      final String dateNaissance = arguments['dateNaissance'];
      final String? genre = arguments['genre'];

      // Étape 1 : Créer l'utilisateur avec email/mot de passe
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      User? user = userCredential.user;

      if (user != null) {
        try {
          // Étape 2 : Créer le credential avec l'OTP
          PhoneAuthCredential credential = PhoneAuthProvider.credential(
            verificationId: verificationId,
            smsCode: otp,
          );

          // Étape 3 : Lier le credential du téléphone à l'utilisateur
          await user.linkWithCredential(credential);

          // Étape 4 : Enregistrer les données dans la base de données
          DatabaseReference usersRef = FirebaseDatabase.instance
              .ref()
              .child('users')
              .child(user.uid);

          Map<String, dynamic> userDataMap = {
            'nom': nom,
            'prenom': prenom,
            'email': email,
            'phone': phoneNumber,
            'dateNaissance': dateNaissance,
            'genre': genre,
            'id': user.uid,
            'blockStatus': 'no',
            'phoneVerified': true,
          };

          await usersRef.set(userDataMap);

          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        } on FirebaseAuthException catch (e) {
          // Si la liaison échoue (OTP incorrect), supprimer l'utilisateur
          await user.delete();
          String errorMessage;
          switch (e.code) {
            case 'invalid-verification-code':
              errorMessage = 'Code OTP incorrect';
              break;
            case 'session-expired':
              errorMessage =
                  'La session a expiré. Veuillez demander un nouveau code';
              break;
            default:
              errorMessage = 'Une erreur est survenue : ${e.code}';
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage)));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur inattendue : ${e.toString()}')),
      );
    }
  }

  void _resendOTP() async {
    final Map<String, dynamic>? arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (arguments == null || arguments['phoneNumber'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Numéro de téléphone manquant pour renvoi'),
        ),
      );
      return;
    }

    final String phoneNumber = arguments['phoneNumber'];

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {},
        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Échec du renvoi : ${e.message}')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/otp',
              arguments: {
                'verificationId': verificationId,
                'phoneNumber': arguments['phoneNumber'],
                'nom': arguments['nom'],
                'prenom': arguments['prenom'],
                'email': arguments['email'],
                'password': arguments['password'],
                'dateNaissance': arguments['dateNaissance'],
                'genre': arguments['genre'],
              },
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Code OTP renvoyé'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du renvoi : ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pushReplacementNamed(context, '/signup'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Text(
                'Vérification OTP',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Entrez le code de 6 chiffres envoyé à votre numéro de téléphone',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Container(
                    width: 50,
                    height: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(1),
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: colorScheme.onSurface.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        errorBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                      ),
                      onChanged: (value) => _onOTPChanged(index, value),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 3,
                ),
                onPressed: _verifyOTP,
                child: const Text(
                  'Vérifier',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _resendOTP,
                child: Text(
                  'Renvoyer le code',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
