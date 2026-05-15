# API CYNA

Base URL locale : `http://localhost:8000/api`

Les routes protégées attendent l'en-tête :

```http
Authorization: Bearer <token>
```

## Authentification

| Méthode | Route | Description |
| --- | --- | --- |
| POST | `/auth/register` | Crée un compte utilisateur |
| POST | `/auth/login` | Connecte et retourne un JWT |
| GET | `/me` | Profil connecté |
| PATCH | `/me` | Mise à jour profil |

## Catalogue public

| Méthode | Route | Description |
| --- | --- | --- |
| GET | `/products` | Liste paginable et filtrable |
| GET | `/products/{id}` | Détail produit |
| GET | `/categories` | Liste des catégories |
| GET | `/categories/{id}/products` | Produits d'une catégorie |
| GET | `/search?q=...` | Recherche produits |
| POST | `/contact` | Message support |

## Panier et commandes

| Méthode | Route | Description |
| --- | --- | --- |
| POST | `/cart/items` | Ajouter un produit au panier |
| PATCH | `/cart/items/{id}` | Modifier quantité/durée |
| DELETE | `/cart/items/{id}` | Supprimer un item |
| POST | `/checkout` | Créer une commande avec paiement mock |
| GET | `/me/orders` | Historique commandes |
| GET | `/me/orders/{id}` | Détail commande |
| GET | `/me/subscriptions` | Abonnements actifs |

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
