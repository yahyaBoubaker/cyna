<?php

namespace App\Controller;

use App\Entity\User;
use App\Security\JwtTokenManager;
use App\Service\MailerService;
use Doctrine\DBAL\Connection;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/api')]
class ApiController extends AbstractController
{
    public function __construct(private readonly Connection $db)
    {
    }

    #[Route('/products', methods: ['GET'])]
    public function products(Request $request): JsonResponse
    {
        $params = ['active' => 1];
        $where = ['p.active = :active'];
        if ($category = $request->query->get('category')) {
            $where[] = 'c.slug = :category';
            $params['category'] = $category;
        }
        // Tri du catalogue (cahier des charges : tri par prix, stock, nouveauté).
        // Liste blanche : jamais de valeur utilisateur directement dans un ORDER BY.
        $orderBy = match ($request->query->get('sort')) {
            'price_asc' => 'p.monthly_price ASC',
            'price_desc' => 'p.monthly_price DESC',
            'stock' => 'p.stock DESC',
            'name' => 'p.name ASC',
            default => 'p.created_at DESC', // nouveauté
        };
        $sql = 'SELECT p.*, c.name category_name, c.slug category_slug,
                (SELECT url FROM product_images pi WHERE pi.product_id = p.id ORDER BY position LIMIT 1) image_url
                FROM products p JOIN categories c ON c.id = p.category_id WHERE '.implode(' AND ', $where).' ORDER BY '.$orderBy;
        return $this->json(['items' => $this->db->fetchAllAssociative($sql, $params)]);
    }

    #[Route('/products/{id}', methods: ['GET'])]
    public function product(int $id): JsonResponse
    {
        $product = $this->db->fetchAssociative('SELECT p.*, c.name category_name, c.slug category_slug FROM products p JOIN categories c ON c.id = p.category_id WHERE p.id = ? AND p.active = 1', [$id]);
        if (!$product) {
            return $this->json(['error' => 'not_found'], 404);
        }
        $product['images'] = $this->db->fetchAllAssociative('SELECT * FROM product_images WHERE product_id = ? ORDER BY position', [$id]);
        // Suggestions de services similaires : même catégorie, produit courant exclu.
        $product['similar'] = $this->db->fetchAllAssociative(
            'SELECT p.*, c.name category_name,
             (SELECT url FROM product_images pi WHERE pi.product_id = p.id ORDER BY position LIMIT 1) image_url
             FROM products p JOIN categories c ON c.id = p.category_id
             WHERE p.active = 1 AND p.category_id = ? AND p.id != ? ORDER BY p.created_at DESC LIMIT 4',
            [$product['category_id'], $id]
        );
        return $this->json($product);
    }

    #[Route('/categories', methods: ['GET'])]
    public function categories(): JsonResponse
    {
        return $this->json(['items' => $this->db->fetchAllAssociative('SELECT * FROM categories WHERE active = 1 ORDER BY name')]);
    }

    #[Route('/categories/{id}/products', methods: ['GET'])]
    public function categoryProducts(int $id): JsonResponse
    {
        return $this->json(['items' => $this->db->fetchAllAssociative('SELECT * FROM products WHERE active = 1 AND category_id = ? ORDER BY name', [$id])]);
    }

    /**
     * Recherche avancée (cahier des charges) : texte (nom, description, caractéristiques
     * techniques), mode de correspondance, filtres prix / disponibilité, tri des résultats.
     */
    #[Route('/search', methods: ['GET'])]
    public function search(Request $request): JsonResponse
    {
        $q = trim($request->query->get('q', ''));
        $params = [];
        $where = ['p.active = 1'];

        if ($q !== '') {
            // Modes : contient (défaut), commence par, correspondance exacte.
            $pattern = match ($request->query->get('mode')) {
                'exact' => $q,
                'starts' => $q.'%',
                default => '%'.$q.'%',
            };
            $where[] = '(p.name LIKE :q OR p.description LIKE :q OR p.technical_specs LIKE :q)';
            $params['q'] = $pattern;
        }
        if (($min = $request->query->get('minPrice')) !== null && $min !== '') {
            $where[] = 'p.monthly_price >= :min';
            $params['min'] = (float) $min;
        }
        if (($max = $request->query->get('maxPrice')) !== null && $max !== '') {
            $where[] = 'p.monthly_price <= :max';
            $params['max'] = (float) $max;
        }
        if ($request->query->get('inStock') === '1') {
            $where[] = 'p.stock > 0';
        }

        // Liste blanche pour le tri : jamais de valeur utilisateur dans un ORDER BY.
        $orderBy = match ($request->query->get('sort')) {
            'price_asc' => 'p.monthly_price ASC',
            'price_desc' => 'p.monthly_price DESC',
            'newest' => 'p.created_at DESC',
            default => 'p.name ASC',
        };

        $sql = 'SELECT p.*, c.name category_name,
                (SELECT url FROM product_images pi WHERE pi.product_id = p.id ORDER BY position LIMIT 1) image_url
                FROM products p JOIN categories c ON c.id = p.category_id
                WHERE '.implode(' AND ', $where).' ORDER BY '.$orderBy.' LIMIT 100';
        return $this->json(['items' => $this->db->fetchAllAssociative($sql, $params)]);
    }

    #[Route('/home-texts', methods: ['GET'])]
    public function homeTexts(): JsonResponse
    {
        return $this->json(['items' => $this->db->fetchAllAssociative('SELECT * FROM home_texts WHERE active = 1 ORDER BY position')]);
    }

    #[Route('/chatbot', methods: ['GET'])]
    public function chatbot(): JsonResponse
    {
        return $this->json(['items' => $this->db->fetchAllAssociative('SELECT id, keywords, answer FROM chatbot_responses WHERE active = 1 ORDER BY position')]);
    }

    #[Route('/home-carousel', methods: ['GET'])]
    public function homeCarousel(): JsonResponse
    {
        return $this->json(['items' => $this->db->fetchAllAssociative('SELECT * FROM home_carousel WHERE active = 1 ORDER BY position')]);
    }

    #[Route('/featured-products', methods: ['GET'])]
    public function featuredProducts(): JsonResponse
    {
        $sql = 'SELECT p.*, c.name category_name, c.slug category_slug,
                (SELECT url FROM product_images pi WHERE pi.product_id = p.id ORDER BY position LIMIT 1) image_url
                FROM featured_products fp
                JOIN products p ON p.id = fp.product_id
                JOIN categories c ON c.id = p.category_id
                WHERE p.active = 1
                ORDER BY fp.position';
        return $this->json(['items' => $this->db->fetchAllAssociative($sql)]);
    }

    #[Route('/auth/register', methods: ['POST'])]
    public function register(Request $request, EntityManagerInterface $em, UserPasswordHasherInterface $hasher, MailerService $mailer): JsonResponse
    {
        $data = $this->payload($request);
        $errors = [];

        $firstName = trim($data['firstName'] ?? '');
        $lastName = trim($data['lastName'] ?? '');
        $email = trim($data['email'] ?? '');
        $password = (string) ($data['password'] ?? '');

        if ($firstName === '') {
            $errors['firstName'] = 'Le prénom est requis.';
        }
        if ($lastName === '') {
            $errors['lastName'] = 'Le nom est requis.';
        }
        if ($emailError = $this->validateEmail($email)) {
            $errors['email'] = $emailError;
        }
        if ($passwordError = $this->validatePassword($password)) {
            $errors['password'] = $passwordError;
        }
        if ($errors === [] && $em->getRepository(User::class)->findOneBy(['email' => strtolower($email)])) {
            $errors['email'] = 'Cet e-mail est déjà utilisé.';
        }
        if ($errors !== []) {
            return $this->json(['error' => 'validation', 'errors' => $errors], 422);
        }

        $user = (new User())
            ->setEmail($email)
            ->setFirstName($firstName)
            ->setLastName($lastName);
        $user->setPassword($hasher->hashPassword($user, $password));

        $token = bin2hex(random_bytes(32));
        $user->setVerificationToken($token);
        $user->setVerificationTokenExpiresAt(new \DateTimeImmutable('+24 hours'));

        $em->persist($user);
        $em->flush();
        $this->ensureCart($user->getId());

        $this->sendVerificationEmail($mailer, $user, $token);

        return $this->json([
            'status' => 'registered',
            'message' => 'Compte créé. Vérifiez votre boîte mail pour confirmer votre inscription avant de vous connecter.',
        ], 201);
    }

    #[Route('/auth/verify', methods: ['GET'])]
    public function verifyEmail(Request $request, EntityManagerInterface $em, JwtTokenManager $tokens): JsonResponse
    {
        $token = (string) $request->query->get('token', '');
        $user = $token !== '' ? $em->getRepository(User::class)->findOneBy(['verificationToken' => $token]) : null;

        if (!$user) {
            return $this->json(['error' => 'invalid_token', 'message' => 'Lien de confirmation invalide.'], 400);
        }
        $expiresAt = $user->getVerificationTokenExpiresAt();
        if ($expiresAt === null || $expiresAt < new \DateTimeImmutable()) {
            return $this->json(['error' => 'expired_token', 'message' => 'Ce lien de confirmation a expiré. Demandez-en un nouveau.'], 400);
        }

        $user->setVerified(true);
        $user->setVerificationToken(null);
        $user->setVerificationTokenExpiresAt(null);
        $em->flush();
        $this->ensureCart($user->getId());

        // Connexion automatique (cahier des charges) : cliquer le lien à usage unique reçu
        // par e-mail prouve la possession de l'adresse — même garantie que le code 2FA.
        return $this->json([
            'status' => 'verified',
            'message' => 'Adresse e-mail confirmée, vous êtes maintenant connecté.',
            'token' => $tokens->create($user),
            'user' => $this->userArray($user),
        ]);
    }

    #[Route('/auth/resend-verification', methods: ['POST'])]
    public function resendVerification(Request $request, EntityManagerInterface $em, MailerService $mailer): JsonResponse
    {
        $email = strtolower(trim($this->payload($request)['email'] ?? ''));
        $user = $email !== '' ? $em->getRepository(User::class)->findOneBy(['email' => $email]) : null;

        // Toujours la même réponse, que le compte existe ou non / soit déjà vérifié ou non :
        // évite de laisser deviner si une adresse e-mail est enregistrée.
        $generic = ['status' => 'sent', 'message' => "Si un compte non confirmé existe pour cet e-mail, un nouveau lien vient d'être envoyé."];

        if (!$user || $user->isVerified()) {
            return $this->json($generic);
        }

        $token = bin2hex(random_bytes(32));
        $user->setVerificationToken($token);
        $user->setVerificationTokenExpiresAt(new \DateTimeImmutable('+24 hours'));
        $em->flush();

        $this->sendVerificationEmail($mailer, $user, $token);

        return $this->json($generic);
    }

    #[Route('/auth/login', methods: ['POST'])]
    public function login(Request $request, EntityManagerInterface $em, UserPasswordHasherInterface $hasher, MailerService $mailer): JsonResponse
    {
        $data = $this->payload($request);
        $user = $em->getRepository(User::class)->findOneBy(['email' => strtolower($data['email'] ?? '')]);
        if (!$user || !$hasher->isPasswordValid($user, $data['password'] ?? '')) {
            return $this->json(['error' => 'invalid_credentials', 'message' => 'Identifiants incorrects.'], 401);
        }
        if (!$user->isVerified()) {
            return $this->json([
                'error' => 'not_verified',
                'message' => "Confirmez votre inscription via l'e-mail qui vous a été envoyé avant de vous connecter.",
            ], 403);
        }

        // Double authentification : le mot de passe seul ne suffit pas, un code à 6 chiffres
        // est envoyé sur l'adresse e-mail confirmée. Le JWT n'est délivré qu'après /auth/verify-2fa.
        $code = (string) random_int(100000, 999999);
        $user->setTwoFactorCode(hash('sha256', $code)); // jamais stocké en clair
        $user->setTwoFactorExpiresAt(new \DateTimeImmutable('+10 minutes'));
        $user->setTwoFactorAttempts(0);
        $em->flush();

        $mailer->send(
            $user->getEmail(),
            'Votre code de connexion CYNA',
            "Bonjour {$user->getFirstName()},\n\n"
            ."Votre code de connexion est : {$code}\n\n"
            ."Il expire dans 10 minutes. Si vous n'êtes pas à l'origine de cette connexion, "
            ."changez votre mot de passe immédiatement.\n\nL'équipe CYNA"
        );

        return $this->json([
            'status' => '2fa_required',
            'message' => 'Un code à 6 chiffres vient d\'être envoyé à votre adresse e-mail.',
        ]);
    }

    #[Route('/auth/verify-2fa', methods: ['POST'])]
    public function verifyTwoFactor(Request $request, EntityManagerInterface $em, JwtTokenManager $tokens): JsonResponse
    {
        $data = $this->payload($request);
        $code = trim((string) ($data['code'] ?? ''));
        $user = $em->getRepository(User::class)->findOneBy(['email' => strtolower(trim($data['email'] ?? ''))]);

        $invalid = $this->json(['error' => 'invalid_code', 'message' => 'Code invalide ou expiré. Reconnectez-vous pour recevoir un nouveau code.'], 401);

        if (!$user || $user->getTwoFactorCode() === null) {
            return $invalid;
        }
        if ($user->getTwoFactorExpiresAt() === null || $user->getTwoFactorExpiresAt() < new \DateTimeImmutable()) {
            return $invalid;
        }
        // Limite anti force-brute : un code à 6 chiffres se devine en ~500k essais sans garde-fou.
        if ($user->getTwoFactorAttempts() >= 5) {
            $user->setTwoFactorCode(null);
            $user->setTwoFactorExpiresAt(null);
            $em->flush();
            return $this->json(['error' => 'too_many_attempts', 'message' => 'Trop de tentatives. Reconnectez-vous pour recevoir un nouveau code.'], 429);
        }
        if (!preg_match('/^[0-9]{6}$/', $code) || !hash_equals($user->getTwoFactorCode(), hash('sha256', $code))) {
            $user->setTwoFactorAttempts($user->getTwoFactorAttempts() + 1);
            $em->flush();
            return $invalid;
        }

        // Code correct : usage unique.
        $user->setTwoFactorCode(null);
        $user->setTwoFactorExpiresAt(null);
        $user->setTwoFactorAttempts(0);
        $em->flush();

        $this->ensureCart($user->getId());
        return $this->json(['token' => $tokens->create($user), 'user' => $this->userArray($user)]);
    }

    #[Route('/auth/forgot-password', methods: ['POST'])]
    public function forgotPassword(Request $request, EntityManagerInterface $em, MailerService $mailer): JsonResponse
    {
        $email = strtolower(trim($this->payload($request)['email'] ?? ''));
        $user = $email !== '' ? $em->getRepository(User::class)->findOneBy(['email' => $email]) : null;

        // Toujours la même réponse, que le compte existe ou non :
        // évite de laisser deviner si une adresse e-mail est enregistrée.
        $generic = ['status' => 'sent', 'message' => "Si un compte existe pour cet e-mail, un code de réinitialisation vient d'être envoyé."];

        if (!$user) {
            return $this->json($generic);
        }

        $code = (string) random_int(100000, 999999);
        $user->setResetCode(hash('sha256', $code)); // jamais stocké en clair
        $user->setResetExpiresAt(new \DateTimeImmutable('+15 minutes'));
        $user->setResetAttempts(0);
        $em->flush();

        $mailer->send(
            $user->getEmail(),
            'Réinitialisation de votre mot de passe CYNA',
            "Bonjour {$user->getFirstName()},\n\n"
            ."Votre code de réinitialisation est : {$code}\n\n"
            ."Il expire dans 15 minutes. Si vous n'avez pas demandé cette réinitialisation, "
            ."ignorez ce message : votre mot de passe reste inchangé.\n\nL'équipe CYNA"
        );

        return $this->json($generic);
    }

    #[Route('/auth/reset-password', methods: ['POST'])]
    public function resetPassword(Request $request, EntityManagerInterface $em, UserPasswordHasherInterface $hasher): JsonResponse
    {
        $data = $this->payload($request);
        $code = trim((string) ($data['code'] ?? ''));
        $user = $em->getRepository(User::class)->findOneBy(['email' => strtolower(trim($data['email'] ?? ''))]);

        $invalid = $this->json(['error' => 'invalid_code', 'message' => 'Code invalide ou expiré. Refaites une demande de réinitialisation.'], 401);

        if (!$user || $user->getResetCode() === null) {
            return $invalid;
        }
        if ($user->getResetExpiresAt() === null || $user->getResetExpiresAt() < new \DateTimeImmutable()) {
            return $invalid;
        }
        if ($user->getResetAttempts() >= 5) {
            $user->setResetCode(null);
            $user->setResetExpiresAt(null);
            $em->flush();
            return $this->json(['error' => 'too_many_attempts', 'message' => 'Trop de tentatives. Refaites une demande de réinitialisation.'], 429);
        }
        if (!preg_match('/^[0-9]{6}$/', $code) || !hash_equals($user->getResetCode(), hash('sha256', $code))) {
            $user->setResetAttempts($user->getResetAttempts() + 1);
            $em->flush();
            return $invalid;
        }

        $newPassword = (string) ($data['newPassword'] ?? '');
        if ($passwordError = $this->validatePassword($newPassword)) {
            // Le code reste valable : l'utilisateur corrige juste son mot de passe.
            return $this->json(['error' => 'validation', 'errors' => ['newPassword' => $passwordError]], 422);
        }

        $user->setPassword($hasher->hashPassword($user, $newPassword));
        $user->setResetCode(null);
        $user->setResetExpiresAt(null);
        $user->setResetAttempts(0);
        // Réussir la réinitialisation prouve la possession de l'adresse e-mail :
        // on en profite pour marquer le compte vérifié s'il ne l'était pas encore.
        $user->setVerified(true);
        $user->setVerificationToken(null);
        $user->setVerificationTokenExpiresAt(null);
        // Un éventuel code 2FA en cours est annulé (nouveau départ propre).
        $user->setTwoFactorCode(null);
        $user->setTwoFactorExpiresAt(null);
        $user->setTwoFactorAttempts(0);
        $em->flush();

        return $this->json(['status' => 'password_reset', 'message' => 'Mot de passe réinitialisé, vous pouvez vous connecter.']);
    }

    #[Route('/contact', methods: ['POST'])]
    public function contact(Request $request): JsonResponse
    {
        $data = $this->payload($request);
        $this->db->insert('contact_messages', [
            'email' => $data['email'] ?? '',
            'subject' => $data['subject'] ?? 'Demande support',
            'message' => $data['message'] ?? '',
            'status' => 'new',
            'created_at' => date('Y-m-d H:i:s'),
        ]);
        return $this->json(['status' => 'created'], 201);
    }

    #[Route('/me', methods: ['GET'])]
    public function me(): JsonResponse
    {
        return $this->json(['user' => $this->userArray($this->getUser())]);
    }

    #[Route('/me', methods: ['PATCH'])]
    public function updateMe(Request $request, EntityManagerInterface $em): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        $data = $this->payload($request);
        if (isset($data['firstName'])) {
            $user->setFirstName($data['firstName']);
        }
        if (isset($data['lastName'])) {
            $user->setLastName($data['lastName']);
        }
        $em->flush();
        return $this->json(['user' => $this->userArray($user)]);
    }

    #[Route('/me/password', methods: ['POST'])]
    public function changePassword(Request $request, EntityManagerInterface $em, UserPasswordHasherInterface $hasher): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        $data = $this->payload($request);
        $errors = [];

        // L'ancien mot de passe est exigé : un poste laissé ouvert ne doit pas suffire à voler le compte.
        if (!$hasher->isPasswordValid($user, (string) ($data['currentPassword'] ?? ''))) {
            $errors['currentPassword'] = 'Le mot de passe actuel est incorrect.';
        }
        $newPassword = (string) ($data['newPassword'] ?? '');
        if ($passwordError = $this->validatePassword($newPassword)) {
            $errors['newPassword'] = $passwordError;
        } elseif ($hasher->isPasswordValid($user, $newPassword)) {
            $errors['newPassword'] = 'Le nouveau mot de passe doit être différent de l\'ancien.';
        }
        if ($errors !== []) {
            return $this->json(['error' => 'validation', 'errors' => $errors], 422);
        }

        $user->setPassword($hasher->hashPassword($user, $newPassword));
        $em->flush();

        return $this->json(['status' => 'password_changed', 'message' => 'Mot de passe modifié.']);
    }

    #[Route('/me/email', methods: ['POST'])]
    public function requestEmailChange(Request $request, EntityManagerInterface $em, UserPasswordHasherInterface $hasher, MailerService $mailer): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        $data = $this->payload($request);
        $errors = [];

        if (!$hasher->isPasswordValid($user, (string) ($data['password'] ?? ''))) {
            $errors['password'] = 'Le mot de passe actuel est incorrect.';
        }
        $newEmail = strtolower(trim((string) ($data['newEmail'] ?? '')));
        if ($emailError = $this->validateEmail($newEmail)) {
            $errors['newEmail'] = $emailError;
        } elseif ($newEmail === $user->getEmail()) {
            $errors['newEmail'] = 'Cette adresse est déjà celle de votre compte.';
        } elseif ($em->getRepository(User::class)->findOneBy(['email' => $newEmail])) {
            $errors['newEmail'] = 'Cet e-mail est déjà utilisé.';
        }
        if ($errors !== []) {
            return $this->json(['error' => 'validation', 'errors' => $errors], 422);
        }

        // Le lien de confirmation part vers la NOUVELLE adresse : prouve que l'utilisateur la possède.
        $token = bin2hex(random_bytes(32));
        $user->setPendingEmail($newEmail);
        $user->setEmailChangeToken($token);
        $user->setEmailChangeExpiresAt(new \DateTimeImmutable('+24 hours'));
        $em->flush();

        $frontendUrl = rtrim($_ENV['FRONTEND_URL'] ?? 'http://localhost:5173', '/');
        $link = $frontendUrl.'/confirmer-email?token='.$token;
        $mailer->send(
            $newEmail,
            'Confirmez votre nouvelle adresse e-mail CYNA',
            "Bonjour {$user->getFirstName()},\n\n"
            ."Vous avez demandé à remplacer l'adresse de votre compte CYNA par celle-ci. "
            ."Confirmez ce changement en cliquant sur le lien ci-dessous (valide 24 heures) :\n\n{$link}\n\n"
            ."Si vous n'êtes pas à l'origine de cette demande, ignorez ce message : votre adresse actuelle reste inchangée.\n\nL'équipe CYNA"
        );

        return $this->json([
            'status' => 'confirmation_sent',
            'message' => "Un lien de confirmation vient d'être envoyé à {$newEmail}. L'adresse actuelle reste active tant que le lien n'est pas cliqué.",
        ]);
    }

    #[Route('/auth/confirm-email', methods: ['GET'])]
    public function confirmEmailChange(Request $request, EntityManagerInterface $em): JsonResponse
    {
        $token = (string) $request->query->get('token', '');
        $user = $token !== '' ? $em->getRepository(User::class)->findOneBy(['emailChangeToken' => $token]) : null;

        if (!$user || $user->getPendingEmail() === null) {
            return $this->json(['error' => 'invalid_token', 'message' => 'Lien de confirmation invalide.'], 400);
        }
        if ($user->getEmailChangeExpiresAt() === null || $user->getEmailChangeExpiresAt() < new \DateTimeImmutable()) {
            return $this->json(['error' => 'expired_token', 'message' => 'Ce lien a expiré. Refaites la demande depuis votre compte.'], 400);
        }
        // Re-vérifié au clic : l'adresse a pu être prise par un autre compte entre-temps.
        if ($em->getRepository(User::class)->findOneBy(['email' => $user->getPendingEmail()])) {
            return $this->json(['error' => 'email_taken', 'message' => 'Cette adresse est désormais utilisée par un autre compte.'], 409);
        }

        $newEmail = $user->getPendingEmail();
        $user->setEmail($newEmail);
        $user->setPendingEmail(null);
        $user->setEmailChangeToken(null);
        $user->setEmailChangeExpiresAt(null);
        $em->flush();

        // Le JWT en cours porte l'ancienne adresse (sub) : il devient invalide.
        return $this->json([
            'status' => 'email_changed',
            'message' => "Adresse remplacée par {$newEmail}. Reconnectez-vous avec cette nouvelle adresse.",
        ]);
    }

    #[Route('/me/orders', methods: ['GET'])]
    public function myOrders(): JsonResponse
    {
        // Nom du 1er service, nombre d'articles et durée max : affichés dans l'historique.
        return $this->json(['items' => $this->db->fetchAllAssociative(
            'SELECT o.*,
             (SELECT oi.product_name FROM order_items oi WHERE oi.order_id = o.id LIMIT 1) first_item,
             (SELECT COUNT(*) FROM order_items oi WHERE oi.order_id = o.id) items_count,
             (SELECT MAX(oi.duration_months) FROM order_items oi WHERE oi.order_id = o.id) duration_months
             FROM orders o WHERE o.user_id = ? ORDER BY o.created_at DESC',
            [$this->userId()]
        )]);
    }

    #[Route('/me/orders/{id}', methods: ['GET'])]
    public function myOrder(int $id): JsonResponse
    {
        $order = $this->db->fetchAssociative('SELECT * FROM orders WHERE id = ? AND user_id = ?', [$id, $this->userId()]);
        if (!$order) {
            return $this->json(['error' => 'not_found'], 404);
        }
        $order['items'] = $this->db->fetchAllAssociative('SELECT * FROM order_items WHERE order_id = ?', [$id]);
        return $this->json($order);
    }

    #[Route('/me/subscriptions', methods: ['GET'])]
    public function subscriptions(): JsonResponse
    {
        return $this->json(['items' => $this->db->fetchAllAssociative('SELECT s.*, p.name product_name FROM subscriptions s JOIN products p ON p.id = s.product_id WHERE s.user_id = ? ORDER BY s.ends_at DESC', [$this->userId()])]);
    }

    #[Route('/me/address', methods: ['GET'])]
    public function myAddress(): JsonResponse
    {
        $address = $this->db->fetchAssociative('SELECT * FROM addresses WHERE user_id = ? ORDER BY id DESC LIMIT 1', [$this->userId()]);
        return $this->json(['address' => $address ?: null]);
    }

    #[Route('/me/address', methods: ['PUT'])]
    public function saveMyAddress(Request $request): JsonResponse
    {
        $data = $this->payload($request);
        $errors = [];
        $line1 = trim($data['line1'] ?? '');
        $city = trim($data['city'] ?? '');
        $postalCode = trim($data['postalCode'] ?? '');
        if ($line1 === '') {
            $errors['line1'] = "L'adresse est requise.";
        }
        if ($city === '') {
            $errors['city'] = 'La ville est requise.';
        }
        if ($postalCode === '') {
            $errors['postalCode'] = 'Le code postal est requis.';
        }
        if ($errors) {
            return $this->json(['error' => 'validation', 'errors' => $errors], 422);
        }

        $row = $this->addressRow($data, $line1, $city, $postalCode);
        $existingId = $this->db->fetchOne('SELECT id FROM addresses WHERE user_id = ? ORDER BY id DESC LIMIT 1', [$this->userId()]);
        if ($existingId) {
            $this->db->update('addresses', $row, ['id' => $existingId]);
        } else {
            $this->db->insert('addresses', $row);
        }
        return $this->json(['address' => $this->db->fetchAssociative('SELECT * FROM addresses WHERE user_id = ? ORDER BY id DESC LIMIT 1', [$this->userId()])]);
    }

    /**
     * Ligne d'adresse complète (cahier des charges : nom, prénom, 2 lignes, ville,
     * région, code postal, pays, téléphone). Partagée entre profil et checkout.
     *
     * @param array<string, mixed> $data
     * @return array<string, string|int>
     */
    private function addressRow(array $data, string $line1, string $city, string $postalCode): array
    {
        return [
            'user_id' => $this->userId(),
            'company' => trim($data['company'] ?? ''),
            'first_name' => trim($data['firstName'] ?? ''),
            'last_name' => trim($data['lastName'] ?? ''),
            'line1' => $line1,
            'line2' => trim($data['line2'] ?? ''),
            'city' => $city,
            'region' => trim($data['region'] ?? ''),
            'postal_code' => $postalCode,
            'phone' => trim($data['phone'] ?? ''),
            'country' => trim($data['country'] ?? '') ?: 'France',
        ];
    }

    #[Route('/me/payments', methods: ['GET'])]
    public function myPayments(): JsonResponse
    {
        // Uniquement nom du porteur + 4 derniers chiffres (jamais le numéro complet, non stocké).
        return $this->json(['items' => $this->db->fetchAllAssociative(
            'SELECT pa.id, pa.order_id, pa.status, pa.amount, pa.card_name, pa.card_last4, pa.created_at
             FROM payments pa JOIN orders o ON o.id = pa.order_id
             WHERE o.user_id = ? ORDER BY pa.created_at DESC',
            [$this->userId()]
        )]);
    }

    #[Route('/me/orders/{id}/invoice', methods: ['GET'])]
    public function myOrderInvoice(int $id): JsonResponse
    {
        $order = $this->db->fetchAssociative('SELECT * FROM orders WHERE id = ? AND user_id = ?', [$id, $this->userId()]);
        if (!$order) {
            return $this->json(['error' => 'not_found'], 404);
        }
        $invoice = $this->db->fetchAssociative('SELECT * FROM invoices WHERE order_id = ?', [$id]);
        if (!$invoice) {
            return $this->json(['error' => 'not_found'], 404);
        }
        $order['items'] = $this->db->fetchAllAssociative('SELECT * FROM order_items WHERE order_id = ?', [$id]);
        $address = $this->db->fetchAssociative('SELECT * FROM addresses WHERE user_id = ? ORDER BY id DESC LIMIT 1', [$this->userId()]);
        // Uniquement nom du porteur + 4 derniers chiffres : jamais le numéro complet ni le CVV (non stockés).
        $payment = $this->db->fetchAssociative('SELECT card_name, card_last4 FROM payments WHERE order_id = ?', [$id]);

        /** @var User $user */
        $user = $this->getUser();

        return $this->json([
            'invoice' => $invoice,
            'order' => $order,
            'user' => $this->userArray($user),
            'address' => $address ?: null,
            'payment' => $payment ?: null,
        ]);
    }

    #[Route('/cart/items', methods: ['POST'])]
    public function addCartItem(Request $request): JsonResponse
    {
        $data = $this->payload($request);
        $cartId = $this->ensureCart($this->userId());
        $product = $this->db->fetchAssociative('SELECT * FROM products WHERE id = ? AND active = 1', [(int) ($data['productId'] ?? 0)]);
        if (!$product) {
            return $this->json(['error' => 'product_unavailable'], 422);
        }
        $this->db->insert('cart_items', [
            'cart_id' => $cartId,
            'product_id' => $product['id'],
            'quantity' => max(1, (int) ($data['quantity'] ?? 1)),
            'duration_months' => max(1, (int) ($data['durationMonths'] ?? 12)),
        ]);
        return $this->json($this->cartPayload(), 201);
    }

    #[Route('/cart/items/{id}', methods: ['PATCH'])]
    public function updateCartItem(int $id, Request $request): JsonResponse
    {
        $data = $this->payload($request);
        $cartId = $this->ensureCart($this->userId());
        $this->db->update('cart_items', [
            'quantity' => max(1, (int) ($data['quantity'] ?? 1)),
            'duration_months' => max(1, (int) ($data['durationMonths'] ?? 12)),
        ], ['id' => $id, 'cart_id' => $cartId]);
        return $this->json($this->cartPayload());
    }

    #[Route('/cart/items/{id}', methods: ['DELETE'])]
    public function deleteCartItem(int $id): JsonResponse
    {
        $this->db->delete('cart_items', ['id' => $id, 'cart_id' => $this->ensureCart($this->userId())]);
        return $this->json($this->cartPayload());
    }

    #[Route('/checkout', methods: ['POST'])]
    public function checkout(Request $request): JsonResponse
    {
        $cart = $this->cartPayload();
        if (!$cart['items']) {
            return $this->json(['error' => 'empty_cart'], 422);
        }

        $data = $this->payload($request);

        $paymentErrors = $this->validatePayment($data['payment'] ?? []);
        if ($paymentErrors) {
            return $this->json(['error' => 'validation', 'errors' => $paymentErrors], 422);
        }
        $cardNumberDigits = preg_replace('/\D/', '', $data['payment']['cardNumber']);
        $cardName = trim($data['payment']['cardName']);
        $cardLast4 = substr($cardNumberDigits, -4);
        // Simulation de paiement : le numéro complet et le CVV ne sont jamais persistés,
        // seuls le nom du porteur et les 4 derniers chiffres sont conservés (cf. cahier des charges).

        if (!empty($data['address']['line1']) && !empty($data['address']['city']) && !empty($data['address']['postalCode'])) {
            $addressRow = $this->addressRow(
                $data['address'],
                trim($data['address']['line1']),
                trim($data['address']['city']),
                trim($data['address']['postalCode'])
            );
            $existingId = $this->db->fetchOne('SELECT id FROM addresses WHERE user_id = ? ORDER BY id DESC LIMIT 1', [$this->userId()]);
            if ($existingId) {
                $this->db->update('addresses', $addressRow, ['id' => $existingId]);
            } else {
                $this->db->insert('addresses', $addressRow);
            }
        }

        $this->db->beginTransaction();
        try {
            $this->db->insert('orders', ['user_id' => $this->userId(), 'status' => 'paid', 'total' => $cart['total'], 'created_at' => date('Y-m-d H:i:s')]);
            $orderId = (int) $this->db->lastInsertId();
            foreach ($cart['items'] as $item) {
                $lineTotal = $item['monthly_price'] * $item['quantity'] * $item['duration_months'];
                $this->db->insert('order_items', [
                    'order_id' => $orderId,
                    'product_id' => $item['product_id'],
                    'product_name' => $item['name'],
                    'quantity' => $item['quantity'],
                    'duration_months' => $item['duration_months'],
                    'unit_monthly_price' => $item['monthly_price'],
                    'line_total' => $lineTotal,
                ]);
                $this->db->insert('subscriptions', [
                    'user_id' => $this->userId(),
                    'product_id' => $item['product_id'],
                    'status' => 'active',
                    'starts_at' => date('Y-m-d H:i:s'),
                    'ends_at' => date('Y-m-d H:i:s', strtotime('+'.$item['duration_months'].' months')),
                ]);
            }
            $this->db->insert('payments', [
                'order_id' => $orderId,
                'provider' => 'mock',
                'status' => 'paid',
                'amount' => $cart['total'],
                'card_name' => $cardName,
                'card_last4' => $cardLast4,
                'created_at' => date('Y-m-d H:i:s'),
            ]);
            $this->db->insert('invoices', ['order_id' => $orderId, 'number' => 'CYNA-'.date('Y').'-'.str_pad((string) $orderId, 5, '0', STR_PAD_LEFT), 'total' => $cart['total'], 'issued_at' => date('Y-m-d H:i:s')]);
            $this->db->executeStatement('DELETE FROM cart_items WHERE cart_id = ?', [$cart['id']]);
            $this->db->commit();
            return $this->json([
                'orderId' => $orderId,
                'status' => 'paid',
                'payment' => ['method' => 'mock', 'cardName' => $cardName, 'last4' => $cardLast4],
            ]);
        } catch (\Throwable $e) {
            $this->db->rollBack();
            return $this->json(['error' => 'checkout_failed', 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * @param array<string, mixed> $payment
     * @return array<string, string>
     */
    private function validatePayment(array $payment): array
    {
        $errors = [];

        $cardName = trim((string) ($payment['cardName'] ?? ''));
        if ($cardName === '') {
            $errors['cardName'] = 'Le nom du porteur est requis.';
        }

        $cardNumberDigits = preg_replace('/\D/', '', (string) ($payment['cardNumber'] ?? ''));
        if (strlen($cardNumberDigits) !== 16) {
            $errors['cardNumber'] = 'Le numéro de carte doit contenir 16 chiffres.';
        }

        $expiry = trim((string) ($payment['cardExpiry'] ?? ''));
        if (!preg_match('/^(0[1-9]|1[0-2])\/([0-9]{2})$/', $expiry, $matches)) {
            $errors['cardExpiry'] = "Format attendu : MM/AA.";
        } else {
            $expYear = 2000 + (int) $matches[2];
            $expMonth = (int) $matches[1];
            $lastDayOfExpMonth = (int) (new \DateTimeImmutable("$expYear-$expMonth-01"))->modify('last day of this month')->format('d');
            $expiresAt = new \DateTimeImmutable(sprintf('%d-%d-%d 23:59:59', $expYear, $expMonth, $lastDayOfExpMonth));
            if ($expiresAt < new \DateTimeImmutable()) {
                $errors['cardExpiry'] = 'Cette carte est expirée.';
            }
        }

        $cvv = trim((string) ($payment['cvv'] ?? ''));
        if (!preg_match('/^[0-9]{3}$/', $cvv)) {
            $errors['cvv'] = 'Le CVV doit contenir 3 chiffres.';
        }

        return $errors;
    }

    private function payload(Request $request): array
    {
        return json_decode($request->getContent() ?: '{}', true) ?: [];
    }

    private function validateEmail(string $email): ?string
    {
        if ($email === '') {
            return "L'adresse e-mail est requise.";
        }
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            return "Le format de l'adresse e-mail est invalide.";
        }
        return null;
    }

    /**
     * Règles CDC : au moins 8 caractères, une majuscule, une minuscule, un chiffre, un caractère spécial.
     */
    private function validatePassword(string $password): ?string
    {
        if (strlen($password) < 8) {
            return 'Le mot de passe doit contenir au moins 8 caractères.';
        }
        if (!preg_match('/[A-Z]/', $password)) {
            return 'Le mot de passe doit contenir au moins une majuscule.';
        }
        if (!preg_match('/[a-z]/', $password)) {
            return 'Le mot de passe doit contenir au moins une minuscule.';
        }
        if (!preg_match('/[0-9]/', $password)) {
            return 'Le mot de passe doit contenir au moins un chiffre.';
        }
        if (!preg_match('/[^A-Za-z0-9]/', $password)) {
            return 'Le mot de passe doit contenir au moins un caractère spécial.';
        }
        return null;
    }

    private function sendVerificationEmail(MailerService $mailer, User $user, string $token): void
    {
        $frontendUrl = rtrim($_ENV['FRONTEND_URL'] ?? 'http://localhost:5173', '/');
        $link = $frontendUrl.'/verifier-email?token='.$token;
        $body = "Bonjour {$user->getFirstName()},\n\n"
            ."Merci de votre inscription sur CYNA. Confirmez votre adresse e-mail en cliquant sur le lien ci-dessous "
            ."(valide 24 heures) :\n\n{$link}\n\n"
            ."Si vous n'êtes pas à l'origine de cette inscription, ignorez ce message.\n\nL'équipe CYNA";

        // Ne bloque jamais l'inscription si l'envoi échoue (ex : Mailpit pas encore démarré) :
        // l'utilisateur pourra toujours redemander l'e-mail via /auth/resend-verification.
        $mailer->send($user->getEmail(), 'Confirmez votre inscription CYNA', $body);
    }

    private function userId(): int
    {
        /** @var User $user */
        $user = $this->getUser();
        return (int) $user->getId();
    }

    private function userArray(User $user): array
    {
        return ['id' => $user->getId(), 'email' => $user->getEmail(), 'firstName' => $user->getFirstName(), 'lastName' => $user->getLastName(), 'roles' => $user->getRoles()];
    }

    private function ensureCart(int $userId): int
    {
        $cartId = $this->db->fetchOne('SELECT id FROM carts WHERE user_id = ?', [$userId]);
        if (!$cartId) {
            $this->db->insert('carts', ['user_id' => $userId, 'updated_at' => date('Y-m-d H:i:s')]);
            $cartId = $this->db->lastInsertId();
        }
        return (int) $cartId;
    }

    private function cartPayload(): array
    {
        $cartId = $this->ensureCart($this->userId());
        $items = $this->db->fetchAllAssociative('SELECT ci.*, p.name, p.monthly_price FROM cart_items ci JOIN products p ON p.id = ci.product_id WHERE ci.cart_id = ?', [$cartId]);
        $total = array_reduce($items, fn (float $sum, array $item): float => $sum + ((float) $item['monthly_price'] * (int) $item['quantity'] * (int) $item['duration_months']), 0.0);
        return ['id' => $cartId, 'items' => $items, 'total' => round($total, 2)];
    }
}
