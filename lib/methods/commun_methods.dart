import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class CommunMethods {
  Future<bool> checkConnectivity(BuildContext context) async {
    var connectionResults = await Connectivity().checkConnectivity();

    // Vérifier si la liste contient uniquement 'none'
    if (connectionResults.contains(ConnectivityResult.none) &&
        connectionResults.length == 1) {
      if (context.mounted) {
        displaySnackBar(
          "Votre connexion Internet n'est pas disponible.",
          context,
        );
      }
      return false;
    }
    return true; // Une connexion est détectée
  }

  void displaySnackBar(String messageText, BuildContext context) {
    var snackBar = SnackBar(content: Text(messageText));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
