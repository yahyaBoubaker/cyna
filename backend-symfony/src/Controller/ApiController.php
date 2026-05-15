<?php

namespace App\Controller;

use App\Entity\User;
use App\Security\JwtTokenManager;
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
        $sql = 'SELECT p.*, c.name category_name, c.slug category_slug,
                (SELECT url FROM product_images pi WHERE pi.product_id = p.id ORDER BY position LIMIT 1) image_url
                FROM products p JOIN categories c ON c.id = p.category_id WHERE '.implode(' AND ', $where).' ORDER BY p.created_at DESC';
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

    #[Route('/search', methods: ['GET'])]
    public function search(Request $request): JsonResponse
    {
        $q = '%'.trim($request->query->get('q', '')).'%';
        return $this->json(['items' => $this->db->fetchAllAssociative('SELECT * FROM products WHERE active = 1 AND (name LIKE ? OR description LIKE ?) ORDER BY name', [$q, $q])]);
    }

    #[Route('/auth/register', methods: ['POST'])]
    public function register(Request $request, EntityManagerInterface $em, UserPasswordHasherInterface $hasher, JwtTokenManager $tokens): JsonResponse
    {
        $data = $this->payload($request);
        if (empty($data['email']) || empty($data['password'])) {
            return $this->json(['error' => 'validation', 'message' => 'Email et mot de passe requis.'], 422);
        }
        if ($em->getRepository(User::class)->findOneBy(['email' => strtolower($data['email'])])) {
            return $this->json(['error' => 'validation', 'message' => 'Email déjà utilisé.'], 422);
        }
        $user = (new User())
            ->setEmail($data['email'])
            ->setFirstName($data['firstName'] ?? '')
            ->setLastName($data['lastName'] ?? '');
        $user->setPassword($hasher->hashPassword($user, $data['password']));
        $em->persist($user);
        $em->flush();
        $this->ensureCart($user->getId());

        return $this->json(['token' => $tokens->create($user), 'user' => $this->userArray($user)], 201);
    }

    #[Route('/auth/login', methods: ['POST'])]
    public function login(Request $request, EntityManagerInterface $em, UserPasswordHasherInterface $hasher, JwtTokenManager $tokens): JsonResponse
    {
        $data = $this->payload($request);
        $user = $em->getRepository(User::class)->findOneBy(['email' => strtolower($data['email'] ?? '')]);
        if (!$user || !$hasher->isPasswordValid($user, $data['password'] ?? '')) {
            return $this->json(['error' => 'invalid_credentials'], 401);
        }
        $this->ensureCart($user->getId());
        return $this->json(['token' => $tokens->create($user), 'user' => $this->userArray($user)]);
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

    #[Route('/me/orders', methods: ['GET'])]
    public function myOrders(): JsonResponse
    {
        return $this->json(['items' => $this->db->fetchAllAssociative('SELECT * FROM orders WHERE user_id = ? ORDER BY created_at DESC', [$this->userId()])]);
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
    public function checkout(): JsonResponse
    {
        $cart = $this->cartPayload();
        if (!$cart['items']) {
            return $this->json(['error' => 'empty_cart'], 422);
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
            $this->db->insert('payments', ['order_id' => $orderId, 'provider' => 'mock', 'status' => 'paid', 'amount' => $cart['total'], 'created_at' => date('Y-m-d H:i:s')]);
            $this->db->insert('invoices', ['order_id' => $orderId, 'number' => 'CYNA-'.date('Y').'-'.str_pad((string) $orderId, 5, '0', STR_PAD_LEFT), 'total' => $cart['total'], 'issued_at' => date('Y-m-d H:i:s')]);
            $this->db->executeStatement('DELETE FROM cart_items WHERE cart_id = ?', [$cart['id']]);
            $this->db->commit();
            return $this->json(['orderId' => $orderId, 'status' => 'paid', 'payment' => 'mock']);
        } catch (\Throwable $e) {
            $this->db->rollBack();
            return $this->json(['error' => 'checkout_failed', 'message' => $e->getMessage()], 500);
        }
    }

    private function payload(Request $request): array
    {
        return json_decode($request->getContent() ?: '{}', true) ?: [];
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
