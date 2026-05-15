<?php

namespace App\DataFixtures;

use Doctrine\Bundle\FixturesBundle\Fixture;
use Doctrine\Persistence\ObjectManager;
use Doctrine\DBAL\Connection;

class AppFixtures extends Fixture
{
    public function __construct(private readonly Connection $db)
    {
    }

    public function load(ObjectManager $manager): void
    {
        $sql = file_get_contents(dirname(__DIR__, 2).'/../database/fixtures.sql');
        foreach (array_filter(array_map('trim', explode(';', $sql))) as $statement) {
            $this->db->executeStatement($statement);
        }
    }
}
