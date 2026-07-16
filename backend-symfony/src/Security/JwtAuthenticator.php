<?php

namespace App\Security;

use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Security\Core\Authentication\Token\TokenInterface;
use Symfony\Component\Security\Core\Exception\AuthenticationException;
use Symfony\Component\Security\Http\Authenticator\AbstractAuthenticator;
use Symfony\Component\Security\Http\Authenticator\Passport\Badge\UserBadge;
use Symfony\Component\Security\Http\Authenticator\Passport\Passport;
use Symfony\Component\Security\Http\Authenticator\Passport\SelfValidatingPassport;
use Symfony\Component\Security\Http\EntryPoint\AuthenticationEntryPointInterface;

class JwtAuthenticator extends AbstractAuthenticator implements AuthenticationEntryPointInterface
{
    public function __construct(
        private readonly JwtTokenManager $tokens,
        private readonly EntityManagerInterface $em,
    ) {
    }

    public function supports(Request $request): ?bool
    {
        return str_starts_with($request->headers->get('Authorization', ''), 'Bearer ');
    }

    public function authenticate(Request $request): Passport
    {
        $jwt = substr($request->headers->get('Authorization', ''), 7);
        $payload = $this->tokens->decode($jwt);
        if (!$payload || empty($payload['sub'])) {
            throw new AuthenticationException('Token invalide.');
        }

        return new SelfValidatingPassport(new UserBadge($payload['sub'], function (string $email): User {
            $user = $this->em->getRepository(User::class)->findOneBy(['email' => $email]);
            if (!$user) {
                throw new AuthenticationException('Utilisateur introuvable.');
            }
            return $user;
        }));
    }

    public function onAuthenticationSuccess(Request $request, TokenInterface $token, string $firewallName): ?Response
    {
        return null;
    }

    public function onAuthenticationFailure(Request $request, AuthenticationException $exception): ?Response
    {
        return new JsonResponse(['error' => 'unauthorized', 'message' => $exception->getMessage()], Response::HTTP_UNAUTHORIZED);
    }

    /**
     * Point d'entrée appelé quand une route protégée est demandée SANS jeton du tout
     * (en-tête Authorization absent). Sans ceci, Symfony lève une exception 401 brute
     * ("No Authentication entry point configured") au lieu d'une réponse JSON propre.
     */
    public function start(Request $request, ?AuthenticationException $authException = null): Response
    {
        return new JsonResponse([
            'error' => 'unauthorized',
            'message' => 'Authentification requise : connectez-vous pour accéder à cette ressource.',
        ], Response::HTTP_UNAUTHORIZED);
    }
}
