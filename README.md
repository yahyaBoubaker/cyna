# CYNA - Plateforme e-commerce SaaS cybersécurité

CYNA est une première version fonctionnelle d'une plateforme e-commerce SaaS pour vendre des services de cybersécurité aux entreprises : SOC, EDR et XDR.

## Architecture

```text
CYNA
├── backend-symfony/
├── frontend-react/
├── backoffice-react/
├── mobile-flutter/
├── database/
├── docs/
└── docker-compose.yml
```

Le backend Symfony est la source de vérité. Le site client React, le back-office React et l'application Flutter consomment la même API REST JSON.

## Démarrage rapide

```bash
docker compose up --build
```

Services par défaut :

- API Symfony : http://localhost:8000
- Frontend client : http://localhost:5173
- Back-office : http://localhost:5174
- phpMyAdmin : http://localhost:8080
- MySQL : localhost:3306

## Comptes de démonstration

- Admin : `admin@cyna.local` / `Admin123!`
- Utilisateur : `user@cyna.local` / `User123!`

## Documentation

- [Installation](docs/installation.md)
- [Architecture](docs/architecture.md)
- [API](docs/api.md)
- [Dictionnaire de conception technique](docs/dct.md)

## Fonctionnalités incluses

- API produits, catégories, recherche, contact.
- Authentification JWT avec rôles `ROLE_USER` et `ROLE_ADMIN`.
- Panier utilisateur, checkout mock et historique de commandes.
- CRUD admin produits, catégories, commandes, utilisateurs, messages et carousel.
- Frontend client responsive avec panier local pour visiteurs.
- Back-office avec tableaux, recherche, pagination simple et dashboard.
- Application Flutter mobile simple connectée à l'API.
- Fixtures et SQL de démonstration.

## Mocks assumés

- Paiement Stripe remplacé par un paiement mock côté backend.
- Envoi d'e-mails non implémenté.
- Stockage sécurisé mobile préparé via `flutter_secure_storage`, dépendance à installer avec Flutter.
