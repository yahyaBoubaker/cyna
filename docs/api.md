# API CYNA

Base URL locale : `http://localhost:8000/api`

Les routes protégées attendent l'en-tête :

```http
Authorization: Bearer <token>
```

## Authentification

| Méthode | Route | Description |
| --- | --- | --- |
| POST | `/auth/register` | Crée un compte utilisateur (validation email/mot de passe, envoie un e-mail de confirmation, ne connecte pas automatiquement) |
| GET | `/auth/verify?token=...` | Confirme l'adresse e-mail à partir du lien reçu (valide 24h) |
| POST | `/auth/resend-verification` | Renvoie l'e-mail de confirmation si le compte existe et n'est pas encore vérifié |
| POST | `/auth/login` | Étape 1 de la connexion : vérifie email + mot de passe (refusé avec `403 not_verified` si l'e-mail n'est pas confirmé), puis envoie un code 2FA à 6 chiffres par e-mail et répond `2fa_required`. Ne retourne PAS de JWT |
| POST | `/auth/verify-2fa` | Étape 2 : `{email, code}`. Retourne le JWT si le code est correct (valide 10 min, usage unique, 5 tentatives max, stocké haché) |
| POST | `/auth/forgot-password` | `{email}`. Envoie un code de réinitialisation à 6 chiffres par e-mail (valide 15 min, haché en base). Réponse identique que le compte existe ou non |
| POST | `/auth/reset-password` | `{email, code, newPassword}`. Vérifie le code (5 tentatives max, usage unique) et applique le nouveau mot de passe (règles CDC). Marque aussi le compte comme vérifié |
| GET | `/auth/confirm-email?token=...` | Applique le changement d'adresse e-mail depuis le lien reçu sur la nouvelle adresse (valide 24h). L'ancien JWT devient invalide (le `sub` porte l'ancienne adresse) |
| GET | `/me` | Profil connecté |
| PATCH | `/me` | Mise à jour profil (prénom/nom) |
| POST | `/me/password` | Change le mot de passe : `{currentPassword, newPassword}`. L'ancien mot de passe est exigé, le nouveau doit respecter les règles CDC |
| POST | `/me/email` | Demande de changement d'adresse : `{newEmail, password}`. Envoie un lien de confirmation à la NOUVELLE adresse ; l'actuelle reste active tant que le lien n'est pas cliqué |

### Envoi d'e-mails

Sans configuration, les e-mails partent vers Mailpit (capture locale, http://localhost:8025).
Pour envoyer vers de vraies adresses : copier `.env.example` en `.env` à la racine et renseigner
un SMTP authentifié (ex. Gmail + mot de passe d'application, STARTTLS sur le port 587),
puis recréer le conteneur backend. Le mot de passe n'est jamais commité (`.env` est git-ignoré).

## Catalogue public

| Méthode | Route | Description |
| --- | --- | --- |
| GET | `/products` | Liste paginable et filtrable |
| GET | `/products/{id}` | Détail produit |
| GET | `/categories` | Liste des catégories |
| GET | `/categories/{id}/products` | Produits d'une catégorie |
| GET | `/search?q=...` | Recherche avancée : `mode` (contains/starts/exact), `minPrice`, `maxPrice`, `inStock=1`, `sort` (name/price_asc/price_desc/newest). Porte sur nom, description et caractéristiques techniques |
| GET | `/products?sort=...` | Catalogue triable : newest/price_asc/price_desc/stock/name. Inclut stock et caractéristiques |
| GET | `/home-texts` | Blocs de texte de l'accueil (gérés en back-office) |
| GET | `/chatbot` | Réponses actives du chatbot (mots-clés → réponse, gérées en back-office) |
| GET | `/home-carousel` | Slides actifs du carrousel d'accueil, triés par position |
| GET | `/featured-products` | Produits mis en avant ("Top produits"), triés par position |
| POST | `/contact` | Message support |

## Panier et commandes

| Méthode | Route | Description |
| --- | --- | --- |
| POST | `/cart/items` | Ajouter un produit au panier |
| PATCH | `/cart/items/{id}` | Modifier quantité/durée |
| DELETE | `/cart/items/{id}` | Supprimer un item |
| POST | `/checkout` | Créer une commande avec paiement simulé (adresse + informations de carte requises ; numéro complet et CVV jamais stockés, seuls le nom et les 4 derniers chiffres sont conservés) |
| GET | `/me/orders` | Historique commandes |
| GET | `/me/orders/{id}` | Détail commande |
| GET | `/me/orders/{id}/invoice` | Détail facture (numéro, lignes, adresse) pour affichage/impression |
| GET | `/me/subscriptions` | Abonnements actifs |
| GET | `/me/address` | Adresse de facturation enregistrée |
| PUT | `/me/address` | Créer/mettre à jour l'adresse de facturation |

## Administration

Toutes les routes admin exigent `ROLE_ADMIN`.

| Méthode | Route | Description |
| --- | --- | --- |
| GET | `/admin/dashboard` | Indicateurs ventes |
| GET/POST | `/admin/products` | Liste/création produits |
| PATCH/DELETE | `/admin/products/{id}` | Edition/suppression produit |
| GET/POST | `/admin/categories` | Liste/création catégories |
| PATCH/DELETE | `/admin/categories/{id}` | Edition/suppression catégorie |
| GET | `/admin/orders` | Liste commandes |
| GET/PATCH | `/admin/orders/{id}` | Détail/édition commande |
| GET | `/admin/users` | Liste utilisateurs |
| GET/PATCH | `/admin/users/{id}` | Détail/édition utilisateur |
| GET/PATCH | `/admin/contact-messages` | Messages support |
| GET/POST | `/admin/home-carousel` | Liste/création slides |
| PATCH/DELETE | `/admin/home-carousel/{id}` | Edition/suppression slide |

## Swagger/OpenAPI

Le projet prévoit NelmioApiDocBundle. Une fois les dépendances installées, la documentation peut être exposée sur `/api/doc`.
