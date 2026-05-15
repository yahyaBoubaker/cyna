<?php
namespace App\Entity;
use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity]
#[ORM\Table(name: 'categories')]
class Category
{
    #[ORM\Id, ORM\GeneratedValue, ORM\Column] private ?int $id = null;
    #[ORM\Column(length: 120)] private string $name = '';
    #[ORM\Column(length: 140, unique: true)] private string $slug = '';
    #[ORM\Column(type: 'text', nullable: true)] private ?string $description = null;
    #[ORM\Column] private bool $active = true;
}
