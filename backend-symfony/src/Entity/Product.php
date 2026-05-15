<?php
namespace App\Entity;
use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity]
#[ORM\Table(name: 'products')]
class Product
{
    #[ORM\Id, ORM\GeneratedValue, ORM\Column] private ?int $id = null;
    #[ORM\ManyToOne(targetEntity: Category::class)]
    #[ORM\JoinColumn(nullable: false, onDelete: 'RESTRICT')] private ?Category $category = null;
    #[ORM\Column(length: 160)] private string $name = '';
    #[ORM\Column(length: 180, unique: true)] private string $slug = '';
    #[ORM\Column(type: 'text')] private string $description = '';
    #[ORM\Column(type: 'decimal', precision: 10, scale: 2)] private string $monthlyPrice = '0.00';
    #[ORM\Column] private bool $active = true;
    #[ORM\Column] private \DateTimeImmutable $createdAt;
    public function __construct() { $this->createdAt = new \DateTimeImmutable(); }
}
