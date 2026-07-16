<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20260715120000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Add password reset fields to users (reset_code haché + expiration + tentatives, séparés de la 2FA)';
    }

    public function up(Schema $schema): void
    {
        // Vérification via introspection du schéma plutôt qu'en "IF NOT EXISTS" SQL brut :
        // toutes les versions de MySQL ne supportent pas cette syntaxe (cf. Version20260712120000).
        $table = $schema->getTable('users');

        if (!$table->hasColumn('reset_code')) {
            $this->addSql('ALTER TABLE users ADD COLUMN reset_code VARCHAR(64) NULL');
        }
        if (!$table->hasColumn('reset_expires_at')) {
            $this->addSql('ALTER TABLE users ADD COLUMN reset_expires_at DATETIME NULL');
        }
        if (!$table->hasColumn('reset_attempts')) {
            $this->addSql('ALTER TABLE users ADD COLUMN reset_attempts INT NOT NULL DEFAULT 0');
        }
    }

    public function down(Schema $schema): void
    {
        $table = $schema->getTable('users');

        foreach (['reset_attempts', 'reset_expires_at', 'reset_code'] as $column) {
            if ($table->hasColumn($column)) {
                $this->addSql('ALTER TABLE users DROP COLUMN '.$column);
            }
        }
    }
}
