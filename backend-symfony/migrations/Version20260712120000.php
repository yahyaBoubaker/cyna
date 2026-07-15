<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20260712120000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Add email verification fields to users (verified, verification_token, verification_token_expires_at)';
    }

    public function up(Schema $schema): void
    {
        // "IF NOT EXISTS" sur ADD/DROP COLUMN n'est pas supporté par toutes les versions de MySQL,
        // on vérifie donc via l'introspection du schéma plutôt qu'en SQL brut.
        $table = $schema->getTable('users');

        if (!$table->hasColumn('verified')) {
            $this->addSql('ALTER TABLE users ADD COLUMN verified TINYINT(1) NOT NULL DEFAULT 0');
        }
        if (!$table->hasColumn('verification_token')) {
            $this->addSql('ALTER TABLE users ADD COLUMN verification_token VARCHAR(64) NULL');
        }
        if (!$table->hasColumn('verification_token_expires_at')) {
            $this->addSql('ALTER TABLE users ADD COLUMN verification_token_expires_at DATETIME NULL');
        }
        // Comptes déjà présents avant cette migration : considérés vérifiés pour ne pas les bloquer à la connexion.
        $this->addSql('UPDATE users SET verified = 1 WHERE verified = 0');
    }

    public function down(Schema $schema): void
    {
        $table = $schema->getTable('users');

        if ($table->hasColumn('verification_token_expires_at')) {
            $this->addSql('ALTER TABLE users DROP COLUMN verification_token_expires_at');
        }
        if ($table->hasColumn('verification_token')) {
            $this->addSql('ALTER TABLE users DROP COLUMN verification_token');
        }
        if ($table->hasColumn('verified')) {
            $this->addSql('ALTER TABLE users DROP COLUMN verified');
        }
    }
}
