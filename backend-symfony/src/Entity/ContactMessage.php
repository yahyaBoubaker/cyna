<?php
namespace App\Entity;
use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity]
#[ORM\Table(name: 'contact_messages')]
class ContactMessage
{
    #[ORM\Id, ORM\GeneratedValue, ORM\Column] private ?int $id = null;
    #[ORM\Column(length: 180)] private string $email = '';
    #[ORM\Column(length: 180)] private string $subject = '';
    #[ORM\Column(type: 'text')] private string $message = '';
    #[ORM\Column(length: 40)] private string $status = 'new';
    #[ORM\Column] private \DateTimeImmutable $createdAt;
    public function __construct() { $this->createdAt = new \DateTimeImmutable(); }
}
