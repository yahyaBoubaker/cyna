<?php

namespace App\Controller;

use Doctrine\DBAL\Connection;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/api/admin')]
class AdminController extends AbstractController
{
    public function __construct(private readonly Connection $db)
    {
    }

    #[Route('/dashboard', methods: ['GET'])]
    public function dashboard(): JsonResponse
    {
        return $this->json([
            'revenue' => (float) ($this->db->fetchOne('SELECT COALESCE(SUM(total),0) FROM orders WHERE status = "paid"') ?: 0),
            'orders' => (int) $this->db->fetchOne('SELECT COUNT(*) FROM orders'),
            'averageCart' => (float) ($this->db->fetchOne('SELECT COALESCE(AVG(total),0) FROM orders WHERE status = "paid"') ?: 0),
            'sales7Days' => $this->db->fetchAllAssociative('SELECT DATE(created_at) day, SUM(total) total FROM orders WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY) GROUP BY DATE(created_at) ORDER BY day'),
            'salesByCategory' => $this->db->fetchAllAssociative('SELECT c.name category, SUM(oi.line_total) total FROM order_items oi JOIN products p ON p.id = oi.product_id JOIN categories c ON c.id = p.category_id GROUP BY c.id, c.name'),
        ]);
    }

    #[Route('/products', methods: ['GET'])]
    public function products(): JsonResponse
    {
        return $this->json(['items' => $this->db->fetchAllAssociative('SELECT p.*, c.name category_name FROM products p JOIN categories c ON c.id = p.category_id ORDER BY p.id DESC')]);
    }

    #[Route('/products', methods: ['POST'])]
    public function createProduct(Request $request): JsonResponse
    {
        $data = $this->payload($request);
        $this->db->insert('products', [
            'category_id' => $data['categoryId'],
            'name' => $data['name'],
            'slug' => $data['slug'] ?? $this->slug($data['name']),
            'description' => $data['description'] ?? '',
            'monthly_price' => $data['monthlyPrice'] ?? 0,
            'active' => (int) ($data['active'] ?? true),
            'created_at' => date('Y-m-d H:i:s'),
        ]);
        return $this->json(['id' => $this->db->lastInsertId()], 201);
    }

    #[Route('/products/{id}', methods: ['PATCH'])]
    public function updateProduct(int $id, Request $request): JsonResponse
    {
        $data = $this->payload($request);
        $fields = $this->map($data, ['categoryId' => 'category_id', 'name' => 'name', 'slug' => 'slug', 'description' => 'description', 'monthlyPrice' => 'monthly_price', 'active' => 'active']);
        if ($fields) {
            $this->db->update('products', $fields, ['id' => $id]);
        }
        return $this->json(['status' => 'updated']);
    }

    #[Route('/products/{id}', methods: ['DELETE'])]
    public function deleteProduct(int $id): JsonResponse
    {
        $this->db->update('products', ['active' => 0], ['id' => $id]);
        return $this->json(['status' => 'disabled']);
    }

    #[Route('/categories', methods: ['GET'])]
    public function categories(): JsonResponse
    {
        return $this->json(['items' => $this->db->fetchAllAssociative('SELECT * FROM categories ORDER BY name')]);
    }

    #[Route('/categories', methods: ['POST'])]
    public function createCategory(Request $request): JsonResponse
    {
        $data = $this->payload($request);
        $this->db->insert('categories', ['name' => $data['name'], 'slug' => $data['slug'] ?? $this->slug($data['name']), 'description' => $data['description'] ?? '', 'active' => 1]);
        return $this->json(['id' => $this->db->lastInsertId()], 201);
    }

    #[Route('/categories/{id}', methods: ['PATCH'])]
    public function updateCategory(int $id, Request $request): JsonResponse
    {
        $fields = $this->map($this->payload($request), ['name' => 'name', 'slug' => 'slug', 'description' => 'description', 'active' => 'active']);
        if ($fields) {
            $this->db->update('categories', $fields, ['id' => $id]);
        }
        return $this->json(['status' => 'updated']);
    }

    #[Route('/categories/{id}', methods: ['DELETE'])]
    public function deleteCategory(int $id): JsonResponse
    {
        $this->db->update('categories', ['active' => 0], ['id' => $id]);
        return $this->json(['status' => 'disabled']);
    }

    #[Route('/orders', methods: ['GET'])]
    public function orders(): JsonResponse
    {
        return $this->json(['items' => $this->db->fetchAllAssociative('SELECT o.*, u.email FROM orders o JOIN users u ON u.id = o.user_id ORDER BY o.created_at DESC')]);
    }

    #[Route('/orders/{id}', methods: ['GET'])]
    public function order(int $id): JsonResponse
    {
        $order = $this->db->fetchAssociative('SELECT * FROM orders WHERE id = ?', [$id]);
        $order['items'] = $this->db->fetchAllAssociative('SELECT * FROM order_items WHERE order_id = ?', [$id]);
        return $this->json($order);
    }

    #[Route('/orders/{id}', methods: ['PATCH'])]
    public function updateOrder(int $id, Request $request): JsonResponse
    {
        $data = $this->payload($request);
        $this->db->update('orders', ['status' => $data['status'] ?? 'pending'], ['id' => $id]);
        return $this->json(['status' => 'updated']);
    }

    #[Route('/users', methods: ['GET'])]
    public function users(): JsonResponse
    {
        return $this->json(['items' => $this->db->fetchAllAssociative('SELECT id, email, first_name, last_name, roles, created_at FROM users ORDER BY id DESC')]);
    }

    #[Route('/users/{id}', methods: ['GET', 'PATCH'])]
    public function user(int $id, Request $request): JsonResponse
    {
        if ($request->isMethod('PATCH')) {
            $this->db->update('users', $this->map($this->payload($request), ['firstName' => 'first_name', 'lastName' => 'last_name', 'roles' => 'roles']), ['id' => $id]);
        }
        return $this->json($this->db->fetchAssociative('SELECT id, email, first_name, last_name, roles, created_at FROM users WHERE id = ?', [$id]));
    }

    #[Route('/contact-messages', methods: ['GET'])]
    public function contactMessages(): JsonResponse
    {
        return $this->json(['items' => $this->db->fetchAllAssociative('SELECT * FROM contact_messages ORDER BY created_at DESC')]);
    }

    #[Route('/contact-messages/{id}', methods: ['PATCH'])]
    public function updateContactMessage(int $id, Request $request): JsonResponse
    {
        $data = $this->payload($request);
        $this->db->update('contact_messages', ['status' => $data['status'] ?? 'read'], ['id' => $id]);
        return $this->json(['status' => 'updated']);
    }

    #[Route('/home-carousel', methods: ['GET'])]
    public function homeCarousel(): JsonResponse
    {
        return $this->json(['items' => $this->db->fetchAllAssociative('SELECT * FROM home_carousel ORDER BY position')]);
    }

    #[Route('/home-carousel', methods: ['POST'])]
    public function createHomeCarousel(Request $request): JsonResponse
    {
        $data = $this->payload($request);
        $this->db->insert('home_carousel', ['title' => $data['title'], 'subtitle' => $data['subtitle'] ?? '', 'image_url' => $data['imageUrl'] ?? '', 'cta_url' => $data['ctaUrl'] ?? null, 'position' => $data['position'] ?? 0, 'active' => 1]);
        return $this->json(['id' => $this->db->lastInsertId()], 201);
    }

    #[Route('/home-carousel/{id}', methods: ['PATCH'])]
    public function updateHomeCarousel(int $id, Request $request): JsonResponse
    {
        $fields = $this->map($this->payload($request), ['title' => 'title', 'subtitle' => 'subtitle', 'imageUrl' => 'image_url', 'ctaUrl' => 'cta_url', 'position' => 'position', 'active' => 'active']);
        if ($fields) {
            $this->db->update('home_carousel', $fields, ['id' => $id]);
        }
        return $this->json(['status' => 'updated']);
    }

    #[Route('/home-carousel/{id}', methods: ['DELETE'])]
    public function deleteHomeCarousel(int $id): JsonResponse
    {
        $this->db->delete('home_carousel', ['id' => $id]);
        return $this->json(['status' => 'deleted']);
    }

    private function payload(Request $request): array
    {
        return json_decode($request->getContent() ?: '{}', true) ?: [];
    }

    private function map(array $data, array $mapping): array
    {
        $out = [];
        foreach ($mapping as $from => $to) {
            if (array_key_exists($from, $data)) {
                $out[$to] = is_bool($data[$from]) ? (int) $data[$from] : (is_array($data[$from]) ? json_encode($data[$from]) : $data[$from]);
            }
        }
        return $out;
    }

    private function slug(string $value): string
    {
        return strtolower(trim(preg_replace('/[^a-z0-9]+/i', '-', $value), '-'));
    }
}
