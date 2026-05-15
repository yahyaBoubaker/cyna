# CYNA Mobile

Application Flutter MVP pour presenter la version mobile CYNA.

## Parcours inclus

- Catalogue SOC, EDR, XDR.
- Recherche locale.
- Choix de duree d'abonnement.
- Panier.
- Checkout vers l'API Symfony quand elle est disponible.
- Connexion / inscription.
- Compte utilisateur.
- Historique de commandes.
- Mode demo avec donnees de secours si l'API n'est pas joignable.

## Lancement

### Preview sans Flutter

Si Flutter n'est pas installe, ouvrir directement :

```text
mobile-flutter/mobile-preview.html
```

Cette preview permet de presenter les parcours mobiles sans SDK Flutter.

### Application Flutter

```bash
cd mobile-flutter
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:8000/api
```

Pour un navigateur Chrome ou Windows desktop, utiliser :

```bash
flutter run -d chrome --dart-define=API_URL=http://127.0.0.1:8000/api
```

Pour un telephone physique, remplacer `127.0.0.1` par l'adresse IP locale de la machine qui lance Symfony.
