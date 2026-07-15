# DCT - Dictionnaire de conception technique

## Entités principales

| Entité | Rôle |
| --- | --- |
| User | Compte client/admin avec rôles, mot de passe hashé et statut de vérification e-mail (`verified`, `verificationToken`, `verificationTokenExpiresAt`) |
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
- Un compte doit être vérifié par e-mail (lien valide 24h) avant de pouvoir se connecter ; l'inscription seule ne délivre pas de session.
- L'e-mail de confirmation est envoyé via `MailerService` (SMTP brut) vers Mailpit en local (`http://localhost:8025`), sans dépendance Composer supplémentaire.

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
