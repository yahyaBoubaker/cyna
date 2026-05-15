<?php
namespace App\Entity;
use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity]
#[ORM\Table(name: 'home_carousel')]
class HomeCarousel
{
    #[ORM\Id, ORM\GeneratedValue, ORM\Column] private ?int $id = null;
    #[ORM\Column(length: 160)] private string $title = '';
    #[ORM\Column(type: 'text')] private string $subtitle = '';
    #[ORM\Column(length: 255)] private string $imageUrl = '';
    #[ORM\Column(length: 255, nullable: true)] private ?string $ctaUrl = null;
    #[ORM\Column] private int $position = 0;
    #[ORM\Column] private bool $active = true;
}
