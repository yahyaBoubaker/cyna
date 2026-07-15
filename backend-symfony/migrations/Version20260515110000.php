<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20260515110000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Initial CYNA schema';
    }

    public function up(Schema $schema): void
    {
        // En Docker, database/ est monté en lecture seule sur /database (voir docker-compose.yml).
        // Hors Docker, on retombe sur le chemin relatif au dépôt.
        $path = is_file('/database/schema.sql') ? '/database/schema.sql' : dirname(__DIR__).'/../database/schema.sql';
        $sql = file_get_contents($path);
        foreach (array_filter(array_map('trim', explode(';', $sql))) as $statement) {
            $this->addSql($statement);
        }
    }

    public function down(Schema $schema): void
    {
        $this->addSql('SET FOREIGN_KEY_CHECKS=0');
        foreach (['featured_products','home_carousel','contact_messages','invoices','payments','subscriptions','order_items','orders','cart_items','carts','addresses','product_images','products','categories','users'] as $table) {
            $this->addSql('DROP TABLE IF EXISTS '.$table);
        }
        $this->addSql('SET FOREIGN_KEY_CHECKS=1');
    }
}
