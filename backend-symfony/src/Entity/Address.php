<?php
namespace App\Entity;
use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity]
#[ORM\Table(name: 'addresses')]
class Address
{
    #[ORM\Id, ORM\GeneratedValue, ORM\Column] private ?int $id = null;
    #[ORM\ManyToOne(targetEntity: User::class)]
    #[ORM\JoinColumn(nullable: false, onDelete: 'CASCADE')] private ?User $user = null;
    #[ORM\Column(length: 180)] private string $company = '';
    #[ORM\Column(length: 255)] private string $line1 = '';
    #[ORM\Column(length: 120)] private string $city = '';
    #[ORM\Column(length: 20)] private string $postalCode = '';
    #[ORM\Column(length: 80)] private string $country = 'France';
}
