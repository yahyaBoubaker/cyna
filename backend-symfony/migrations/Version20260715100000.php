<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20260715100000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Add 2FA fields (code haché + expiration + tentatives) and email change fields (pending_email + token) to users';
    }

    public function up(Schema $schema): void
    {
        // Vérification via introspection du schéma plutôt qu'en "IF NOT EXISTS" SQL brut :
        // toutes les versions de MySQL ne supportent pas cette syntaxe (cf. Version20260712120000).
        $table = $schema->getTable('users');

        if (!$table->hasColumn('two_factor_code')) {
            $this->addSql('ALTER TABLE users ADD COLUMN two_factor_code VARCHAR(64) NULL');
        }
        if (!$table->hasColumn('two_factor_expires_at')) {
            $this->addSql('ALTER TABLE users ADD COLUMN two_factor_expires_at DATETIME NULL');
        }
        if (!$table->hasColumn('two_factor_attempts')) {
            $this->addSql('ALTER TABLE users ADD COLUMN two_factor_attempts INT NOT NULL DEFAULT 0');
        }
        if (!$table->hasColumn('pending_email')) {
            $this->addSql('ALTER TABLE users ADD COLUMN pending_email VARCHAR(180) NULL');
        }
        if (!$table->hasColumn('email_change_token')) {
            $this->addSql('ALTER TABLE users ADD COLUMN email_change_token VARCHAR(64) NULL');
        }
        if (!$table->hasColumn('email_change_expires_at')) {
            $this->addSql('ALTER TABLE users ADD COLUMN email_change_expires_at DATETIME NULL');
        }
    }

    public function down(Schema $schema): void
    {
        $table = $schema->getTable('users');

        foreach (['email_change_expires_at', 'email_change_token', 'pending_email', 'two_factor_attempts', 'two_factor_expires_at', 'two_factor_code'] as $column) {
            if ($table->hasColumn($column)) {
                $this->addSql('ALTER TABLE users DROP COLUMN '.$column);
            }
        }
    }
}
