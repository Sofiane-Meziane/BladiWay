import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CarRegistrationScreen extends StatefulWidget {
  const CarRegistrationScreen({super.key});

  @override
  CarRegistrationScreenState createState() => CarRegistrationScreenState();
}

class CarRegistrationScreenState extends State<CarRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _plateController = TextEditingController();
  final _vinController = TextEditingController();

  String? _selectedYear;
  String? _selectedColor;

  final List<String> _colors = [
    'Rouge',
    'Bleu',
    'Noir',
    'Blanc',
    'Gris',
    'Vert',
    'Jaune',
    'Orange',
    'Violet',
    'Rose',
    'Marron',
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _validatePlate(String? value) {
    if (value!.isEmpty) return 'Veuillez entrer le numéro de plaque';
    return null;
  }

  String? _validateColor(String? value) {
    if (value == null) return 'Veuillez sélectionner la couleur de la voiture';
    return null;
  }

  String? _validateYear(String? value) {
    if (value == null) return 'Veuillez sélectionner l\'année de fabrication';
    return null;
  }

  Future<void> startCarRegistration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez être connecté pour continuer'),
        ),
      );
      return;
    }

    String make = _makeController.text;
    String model = _modelController.text;
    String plate = _plateController.text;
    String vin = _vinController.text;
    String id_proprietaire = user.uid;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (BuildContext context) => const AlertDialog(
            title: Text('Enregistrement en cours'),
            content: CircularProgressIndicator(),
          ),
    );

    await Future.delayed(const Duration(seconds: 2));

    await saveCarRegistration(
      make,
      model,
      _selectedYear!,
      _selectedColor!,
      plate,
      vin,
      id_proprietaire,
    );

    // Vérifier si toutes les informations sont saisies après l'enregistrement
    await _checkAndUpdateValidationStatus(user);

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voiture enregistrée avec succès!')),
    );
  }

  List<String> _generateYears() {
    int currentYear = DateTime.now().year;
    List<String> years = [];
    for (int i = currentYear; i >= 1950; i--) {
      years.add(i.toString());
    }
    return years;
  }

  Future<void> saveCarRegistration(
    String make,
    String model,
    String year,
    String color,
    String plate,
    String vin,
    String id,
  ) async {
    try {
      await _firestore.collection('cars').add({
        'make': make,
        'model': model,
        'year': year,
        'color': color,
        'plate': plate,
        'vin': vin,
        'id_proprietaire': id,
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      print('Erreur lors de l\'enregistrement de la voiture: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'enregistrement de la voiture'),
        ),
      );
    }
  }

  /// Vérifie si toutes les informations (permis + voiture) sont saisies
  Future<void> _checkAndUpdateValidationStatus(User user) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      bool hasLicense =
          userDoc['recto_permis'] != null && userDoc['verso_permis'] != null;
      QuerySnapshot carsSnapshot =
          await _firestore
              .collection('cars')
              .where('id_proprietaire', isEqualTo: user.uid)
              .limit(1)
              .get();
      bool hasCar = carsSnapshot.docs.isNotEmpty;

      // Ne met pas à jour isValidated ici, car cela nécessite la validation admin
      if (hasLicense && hasCar) {
        print(
          'Toutes les informations sont saisies, en attente de validation admin.',
        );
      }
    } catch (e) {
      print('Erreur lors de la vérification du statut : $e');
    }
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _plateController.dispose();
    _vinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ajouter une voiture',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _makeController,
                  decoration: InputDecoration(
                    labelText: 'Marque de la voiture',
                    prefixIcon: Icon(Icons.directions_car, color: primaryColor),
                    border: const OutlineInputBorder(),
                  ),
                  validator:
                      (value) =>
                          value!.isEmpty ? 'Veuillez entrer la marque' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _modelController,
                  decoration: InputDecoration(
                    labelText: 'Modèle de la voiture',
                    prefixIcon: Icon(Icons.drive_eta, color: primaryColor),
                    border: const OutlineInputBorder(),
                  ),
                  validator:
                      (value) =>
                          value!.isEmpty ? 'Veuillez entrer le modèle' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedYear,
                  decoration: InputDecoration(
                    labelText: 'Année de fabrication',
                    prefixIcon: Icon(Icons.calendar_today, color: primaryColor),
                    border: const OutlineInputBorder(),
                  ),
                  items:
                      _generateYears().map((year) {
                        return DropdownMenuItem<String>(
                          value: year,
                          child: Text(year),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedYear = value;
                    });
                  },
                  validator: _validateYear,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedColor,
                  decoration: InputDecoration(
                    labelText: 'Couleur',
                    prefixIcon: Icon(Icons.color_lens, color: primaryColor),
                    border: const OutlineInputBorder(),
                  ),
                  items:
                      _colors.map((color) {
                        return DropdownMenuItem<String>(
                          value: color,
                          child: Text(color),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedColor = value;
                    });
                  },
                  validator: _validateColor,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _plateController,
                  decoration: InputDecoration(
                    labelText: 'Numéro de plaque',
                    prefixIcon: Icon(Icons.location_on, color: primaryColor),
                    border: const OutlineInputBorder(),
                  ),
                  validator: _validatePlate,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _vinController,
                  decoration: InputDecoration(
                    labelText: 'Numéro de série (VIN)',
                    prefixIcon: Icon(Icons.vpn_key, color: primaryColor),
                    border: const OutlineInputBorder(),
                  ),
                  validator:
                      (value) =>
                          value!.isEmpty ? 'Veuillez entrer le VIN' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: startCarRegistration,
                  child: const Text(
                    "Enregistrer la voiture",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Retour',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
