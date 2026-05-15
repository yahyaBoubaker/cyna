<?php
namespace App\Entity;
use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity]
#[ORM\Table(name: 'order_items')]
class OrderItem
{
    #[ORM\Id, ORM\GeneratedValue, ORM\Column] private ?int $id = null;
    #[ORM\ManyToOne(targetEntity: Order::class)]
    #[ORM\JoinColumn(nullable: false, onDelete: 'CASCADE')] private ?Order $orderRef = null;
    #[ORM\ManyToOne(targetEntity: Product::class)]
    #[ORM\JoinColumn(nullable: false, onDelete: 'RESTRICT')] private ?Product $product = null;
    #[ORM\Column(length: 160)] private string $productName = '';
    #[ORM\Column] private int $quantity = 1;
    #[ORM\Column] private int $durationMonths = 12;
    #[ORM\Column(type: 'decimal', precision: 10, scale: 2)] private string $unitMonthlyPrice = '0.00';
    #[ORM\Column(type: 'decimal', precision: 10, scale: 2)] private string $lineTotal = '0.00';
}
