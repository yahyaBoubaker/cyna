<?php

namespace App\Entity;

use Doctrine\ORM\Mapping as ORM;
use Symfony\Component\Security\Core\User\PasswordAuthenticatedUserInterface;
use Symfony\Component\Security\Core\User\UserInterface;

#[ORM\Entity]
#[ORM\Table(name: 'users')]
class User implements UserInterface, PasswordAuthenticatedUserInterface
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column]
    private ?int $id = null;

    #[ORM\Column(length: 180, unique: true)]
    private string $email = '';

    #[ORM\Column(length: 120)]
    private string $firstName = '';

    #[ORM\Column(length: 120)]
    private string $lastName = '';

    #[ORM\Column(type: 'json')]
    private array $roles = ['ROLE_USER'];

    #[ORM\Column]
    private string $password = '';

    #[ORM\Column]
    private bool $verified = false;

    #[ORM\Column(length: 64, nullable: true)]
    private ?string $verificationToken = null;

    #[ORM\Column(nullable: true)]
    private ?\DateTimeImmutable $verificationTokenExpiresAt = null;

    /** Code 2FA à 6 chiffres, stocké haché (SHA-256) — jamais en clair. */
    #[ORM\Column(length: 64, nullable: true)]
    private ?string $twoFactorCode = null;

    #[ORM\Column(nullable: true)]
    private ?\DateTimeImmutable $twoFactorExpiresAt = null;

    #[ORM\Column(options: ['default' => 0])]
    private int $twoFactorAttempts = 0;

    /**
     * Code de réinitialisation de mot de passe, haché (SHA-256).
     * Champs séparés de ceux de la 2FA : un code de réinitialisation ne doit
     * JAMAIS être accepté par /auth/verify-2fa (il donnerait un JWT sans mot de passe).
     */
    #[ORM\Column(length: 64, nullable: true)]
    private ?string $resetCode = null;

    #[ORM\Column(nullable: true)]
    private ?\DateTimeImmutable $resetExpiresAt = null;

    #[ORM\Column(options: ['default' => 0])]
    private int $resetAttempts = 0;

    /** Nouvelle adresse en attente de confirmation (changement d'e-mail). */
    #[ORM\Column(length: 180, nullable: true)]
    private ?string $pendingEmail = null;

    #[ORM\Column(length: 64, nullable: true)]
    private ?string $emailChangeToken = null;

    #[ORM\Column(nullable: true)]
    private ?\DateTimeImmutable $emailChangeExpiresAt = null;

    #[ORM\Column]
    private \DateTimeImmutable $createdAt;

    public function __construct()
    {
        $this->createdAt = new \DateTimeImmutable();
    }

    public function getId(): ?int
    {
        return $this->id;
    }

    public function getEmail(): string
    {
        return $this->email;
    }

    public function setEmail(string $email): self
    {
        $this->email = strtolower(trim($email));
        return $this;
    }

    public function getFirstName(): string
    {
        return $this->firstName;
    }

    public function setFirstName(string $firstName): self
    {
        $this->firstName = trim($firstName);
        return $this;
    }

    public function getLastName(): string
    {
        return $this->lastName;
    }

    public function setLastName(string $lastName): self
    {
        $this->lastName = trim($lastName);
        return $this;
    }

    public function getRoles(): array
    {
        return array_values(array_unique([...$this->roles, 'ROLE_USER']));
    }

    public function setRoles(array $roles): self
    {
        $this->roles = $roles;
        return $this;
    }

    public function getPassword(): string
    {
        return $this->password;
    }

    public function setPassword(string $password): self
    {
        $this->password = $password;
        return $this;
    }

    public function getUserIdentifier(): string
    {
        return $this->email;
    }

    public function eraseCredentials(): void
    {
    }

    public function isVerified(): bool
    {
        return $this->verified;
    }

    public function setVerified(bool $verified): self
    {
        $this->verified = $verified;
        return $this;
    }

    public function getVerificationToken(): ?string
    {
        return $this->verificationToken;
    }

    public function setVerificationToken(?string $token): self
    {
        $this->verificationToken = $token;
        return $this;
    }

    public function getVerificationTokenExpiresAt(): ?\DateTimeImmutable
    {
        return $this->verificationTokenExpiresAt;
    }

    public function setVerificationTokenExpiresAt(?\DateTimeImmutable $expiresAt): self
    {
        $this->verificationTokenExpiresAt = $expiresAt;
        return $this;
    }

    public function getTwoFactorCode(): ?string
    {
        return $this->twoFactorCode;
    }

    public function setTwoFactorCode(?string $hashedCode): self
    {
        $this->twoFactorCode = $hashedCode;
        return $this;
    }

    public function getTwoFactorExpiresAt(): ?\DateTimeImmutable
    {
        return $this->twoFactorExpiresAt;
    }

    public function setTwoFactorExpiresAt(?\DateTimeImmutable $expiresAt): self
    {
        $this->twoFactorExpiresAt = $expiresAt;
        return $this;
    }

    public function getTwoFactorAttempts(): int
    {
        return $this->twoFactorAttempts;
    }

    public function setTwoFactorAttempts(int $attempts): self
    {
        $this->twoFactorAttempts = $attempts;
        return $this;
    }

    public function getResetCode(): ?string
    {
        return $this->resetCode;
    }

    public function setResetCode(?string $hashedCode): self
    {
        $this->resetCode = $hashedCode;
        return $this;
    }

    public function getResetExpiresAt(): ?\DateTimeImmutable
    {
        return $this->resetExpiresAt;
    }

    public function setResetExpiresAt(?\DateTimeImmutable $expiresAt): self
    {
        $this->resetExpiresAt = $expiresAt;
        return $this;
    }

    public function getResetAttempts(): int
    {
        return $this->resetAttempts;
    }

    public function setResetAttempts(int $attempts): self
    {
        $this->resetAttempts = $attempts;
        return $this;
    }

    public function getPendingEmail(): ?string
    {
        return $this->pendingEmail;
    }

    public function setPendingEmail(?string $email): self
    {
        $this->pendingEmail = $email === null ? null : strtolower(trim($email));
        return $this;
    }

    public function getEmailChangeToken(): ?string
    {
        return $this->emailChangeToken;
    }

    public function setEmailChangeToken(?string $token): self
    {
        $this->emailChangeToken = $token;
        return $this;
    }

    public function getEmailChangeExpiresAt(): ?\DateTimeImmutable
    {
        return $this->emailChangeExpiresAt;
    }

    public function setEmailChangeExpiresAt(?\DateTimeImmutable $expiresAt): self
    {
        $this->emailChangeExpiresAt = $expiresAt;
        return $this;
    }
}
