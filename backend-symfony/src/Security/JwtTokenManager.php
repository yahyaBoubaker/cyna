<?php

namespace App\Security;

use App\Entity\User;

class JwtTokenManager
{
    public function __construct(private readonly string $secret)
    {
    }

    public function create(User $user): string
    {
        $payload = [
            'sub' => $user->getEmail(),
            'uid' => $user->getId(),
            'roles' => $user->getRoles(),
            'iat' => time(),
            'exp' => time() + 3600,
        ];

        $header = $this->base64UrlEncode(json_encode(['typ' => 'JWT', 'alg' => 'HS256']));
        $body = $this->base64UrlEncode(json_encode($payload));
        $signature = $this->base64UrlEncode(hash_hmac('sha256', "$header.$body", $this->secret, true));

        return "$header.$body.$signature";
    }

    public function decode(string $token): ?array
    {
        $parts = explode('.', $token);
        if (count($parts) !== 3) {
            return null;
        }

        [$header, $body, $signature] = $parts;
        $expected = $this->base64UrlEncode(hash_hmac('sha256', "$header.$body", $this->secret, true));
        if (!hash_equals($expected, $signature)) {
            return null;
        }

        $payload = json_decode($this->base64UrlDecode($body), true);
        if (!is_array($payload) || ($payload['exp'] ?? 0) < time()) {
            return null;
        }

        return $payload;
    }

    private function base64UrlEncode(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }

    private function base64UrlDecode(string $value): string
    {
        return base64_decode(strtr($value, '-_', '+/'));
    }
}
