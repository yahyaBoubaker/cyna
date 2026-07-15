<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20260713090000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Add card_name/card_last4 to payments (simulation de paiement, aucune donnée sensible stockée)';
    }

    public function up(Schema $schema): void
    {
        // Vérification via introspection du schéma plutôt qu'en "IF NOT EXISTS" SQL brut :
        // toutes les versions de MySQL ne supportent pas cette syntaxe (cf. Version20260712120000).
        $table = $schema->getTable('payments');

        if (!$table->hasColumn('card_name')) {
            $this->addSql('ALTER TABLE payments ADD COLUMN card_name VARCHAR(120) NULL');
        }
        if (!$table->hasColumn('card_last4')) {
            $this->addSql('ALTER TABLE payments ADD COLUMN card_last4 VARCHAR(4) NULL');
        }
    }

    public function down(Schema $schema): void
    {
        $table = $schema->getTable('payments');

        if ($table->hasColumn('card_last4')) {
            $this->addSql('ALTER TABLE payments DROP COLUMN card_last4');
        }
        if ($table->hasColumn('card_name')) {
            $this->addSql('ALTER TABLE payments DROP COLUMN card_name');
        }
    }
}
