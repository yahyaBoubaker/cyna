<?php
namespace App\Entity;
use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity]
#[ORM\Table(name: 'cart_items')]
class CartItem
{
    #[ORM\Id, ORM\GeneratedValue, ORM\Column] private ?int $id = null;
    #[ORM\ManyToOne(targetEntity: Cart::class)]
    #[ORM\JoinColumn(nullable: false, onDelete: 'CASCADE')] private ?Cart $cart = null;
    #[ORM\ManyToOne(targetEntity: Product::class)]
    #[ORM\JoinColumn(nullable: false, onDelete: 'RESTRICT')] private ?Product $product = null;
    #[ORM\Column] private int $quantity = 1;
    #[ORM\Column] private int $durationMonths = 12;
}
