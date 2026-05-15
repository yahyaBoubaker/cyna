<?php
namespace App\Entity;
use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity]
#[ORM\Table(name: 'product_images')]
class ProductImage
{
    #[ORM\Id, ORM\GeneratedValue, ORM\Column] private ?int $id = null;
    #[ORM\ManyToOne(targetEntity: Product::class)]
    #[ORM\JoinColumn(nullable: false, onDelete: 'CASCADE')] private ?Product $product = null;
    #[ORM\Column(length: 255)] private string $url = '';
    #[ORM\Column(length: 180, nullable: true)] private ?string $alt = null;
    #[ORM\Column] private int $position = 0;
}
