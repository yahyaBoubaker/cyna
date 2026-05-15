<?php
namespace App\Entity;
use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity]
#[ORM\Table(name: 'subscriptions')]
class Subscription
{
    #[ORM\Id, ORM\GeneratedValue, ORM\Column] private ?int $id = null;
    #[ORM\ManyToOne(targetEntity: User::class)]
    #[ORM\JoinColumn(nullable: false, onDelete: 'CASCADE')] private ?User $user = null;
    #[ORM\ManyToOne(targetEntity: Product::class)]
    #[ORM\JoinColumn(nullable: false, onDelete: 'RESTRICT')] private ?Product $product = null;
    #[ORM\Column(length: 40)] private string $status = 'active';
    #[ORM\Column] private \DateTimeImmutable $startsAt;
    #[ORM\Column] private \DateTimeImmutable $endsAt;
}
