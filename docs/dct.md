# DCT - Dictionnaire de conception technique

## Entités principales

| Entité | Rôle |
| --- | --- |
| User | Compte client/admin avec rôles et mot de passe hashé |
| Category | Catégorie SOC, EDR, XDR |
| Product | Service SaaS vendu |
| ProductImage | Images liées aux produits |
| Cart | Panier utilisateur |
| CartItem | Ligne de panier avec durée d'abonnement |
| Order | Commande validée |
| OrderItem | Ligne de commande figée au moment de l'achat |
| Subscription | Abonnement créé après checkout |
| Address | Adresse de facturation |
| Payment | Paiement mock ou Stripe futur |
| Invoice | Facture associée |
| ContactMessage | Message support |
| HomeCarousel | Slide de page d'accueil |
| FeaturedProduct | Produit mis en avant |

## Règles métier

- Le total du panier est calculé côté backend.
- Une commande ne peut être créée que pour un utilisateur authentifié.
- Les produits inactifs ne sont pas commandables.
- Les routes admin sont protégées côté backend par `ROLE_ADMIN`.
- Les paiements ne stockent jamais de numéro de carte.

## Statuts

Commandes :

- `pending`
- `paid`
- `cancelled`
- `refunded`

Paiements :

- `mock_authorized`
- `paid`
- `failed`

Messages contact :

- `new`
- `read`
- `closed`
