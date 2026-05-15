<?php
namespace App\Entity;
use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity]
#[ORM\Table(name: 'payments')]
class Payment
{
    #[ORM\Id, ORM\GeneratedValue, ORM\Column] private ?int $id = null;
    #[ORM\OneToOne(targetEntity: Order::class)]
    #[ORM\JoinColumn(nullable: false, onDelete: 'CASCADE')] private ?Order $orderRef = null;
    #[ORM\Column(length: 40)] private string $provider = 'mock';
    #[ORM\Column(length: 80)] private string $status = 'mock_authorized';
    #[ORM\Column(type: 'decimal', precision: 10, scale: 2)] private string $amount = '0.00';
    #[ORM\Column] private \DateTimeImmutable $createdAt;
    public function __construct() { $this->createdAt = new \DateTimeImmutable(); }
}
