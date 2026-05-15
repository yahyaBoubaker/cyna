<?php
namespace App\Entity;
use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity]
#[ORM\Table(name: 'invoices')]
class Invoice
{
    #[ORM\Id, ORM\GeneratedValue, ORM\Column] private ?int $id = null;
    #[ORM\OneToOne(targetEntity: Order::class)]
    #[ORM\JoinColumn(nullable: false, onDelete: 'CASCADE')] private ?Order $orderRef = null;
    #[ORM\Column(length: 60, unique: true)] private string $number = '';
    #[ORM\Column(type: 'decimal', precision: 10, scale: 2)] private string $total = '0.00';
    #[ORM\Column] private \DateTimeImmutable $issuedAt;
}
