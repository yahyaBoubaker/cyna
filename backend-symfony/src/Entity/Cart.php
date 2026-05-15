<?php
namespace App\Entity;
use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity]
#[ORM\Table(name: 'carts')]
class Cart
{
    #[ORM\Id, ORM\GeneratedValue, ORM\Column] private ?int $id = null;
    #[ORM\OneToOne(targetEntity: User::class)]
    #[ORM\JoinColumn(nullable: false, onDelete: 'CASCADE')] private ?User $user = null;
    #[ORM\Column] private \DateTimeImmutable $updatedAt;
    public function __construct() { $this->updatedAt = new \DateTimeImmutable(); }
}
