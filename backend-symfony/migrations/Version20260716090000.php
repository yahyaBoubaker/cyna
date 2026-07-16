<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Couverture des exigences du cahier des charges relevées dans la grille d'évaluation :
 * stock + caractéristiques techniques produits, images de catégories, adresse de facturation
 * complète, blocs de texte d'accueil éditables en back-office, réponses du chatbot.
 * Des données de démonstration sont semées pour les bases déjà existantes
 * (les fixtures SQL ne s'exécutent qu'à la première création du conteneur MySQL).
 */
final class Version20260716090000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Products stock/specs, categories image, addresses full fields, home_texts & chatbot_responses tables (+ seed démo)';
    }

    public function up(Schema $schema): void
    {
        // Vérification par introspection : "IF NOT EXISTS" sur ADD COLUMN n'est pas
        // supporté par toutes les versions de MySQL (cf. Version20260712120000).
        $products = $schema->getTable('products');
        if (!$products->hasColumn('stock')) {
            $this->addSql('ALTER TABLE products ADD COLUMN stock INT NOT NULL DEFAULT 25');
        }
        if (!$products->hasColumn('technical_specs')) {
            $this->addSql('ALTER TABLE products ADD COLUMN technical_specs TEXT NULL');
        }

        $categories = $schema->getTable('categories');
        if (!$categories->hasColumn('image_url')) {
            $this->addSql('ALTER TABLE categories ADD COLUMN image_url VARCHAR(500) NULL');
        }

        $addresses = $schema->getTable('addresses');
        foreach (['first_name' => 'VARCHAR(120)', 'last_name' => 'VARCHAR(120)', 'line2' => 'VARCHAR(255)', 'region' => 'VARCHAR(120)', 'phone' => 'VARCHAR(30)'] as $column => $type) {
            if (!$addresses->hasColumn($column)) {
                $this->addSql("ALTER TABLE addresses ADD COLUMN {$column} {$type} NULL");
            }
        }

        if (!$schema->hasTable('home_texts')) {
            $this->addSql('CREATE TABLE home_texts (
                id INT AUTO_INCREMENT PRIMARY KEY,
                title VARCHAR(180) NOT NULL,
                content TEXT NOT NULL,
                position INT NOT NULL DEFAULT 0,
                active TINYINT(1) NOT NULL DEFAULT 1
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci');
        }

        if (!$schema->hasTable('chatbot_responses')) {
            $this->addSql('CREATE TABLE chatbot_responses (
                id INT AUTO_INCREMENT PRIMARY KEY,
                keywords VARCHAR(255) NOT NULL,
                answer TEXT NOT NULL,
                position INT NOT NULL DEFAULT 0,
                active TINYINT(1) NOT NULL DEFAULT 1
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci');
        }

        // Index pour tenir l'exigence de performance de la recherche (< 100 ms).
        if (!$products->hasIndex('idx_products_name')) {
            $this->addSql('CREATE INDEX idx_products_name ON products (name)');
        }
        if (!$products->hasIndex('idx_products_price')) {
            $this->addSql('CREATE INDEX idx_products_price ON products (monthly_price)');
        }

        // --- Seed démo (bases existantes) ---
        $this->addSql("UPDATE products SET technical_specs = 'Supervision 24/7 · SLA 15 min · Analystes N1-N3 · Rapports mensuels · Conformité ISO 27001 · Intégration SIEM' WHERE slug = 'cyna-soc' AND technical_specs IS NULL");
        $this->addSql("UPDATE products SET technical_specs = 'Agents Windows/macOS/Linux · Détection comportementale · Isolation machine en 1 clic · Console cloud · Déploiement < 1 jour' WHERE slug = 'cyna-edr' AND technical_specs IS NULL");
        $this->addSql("UPDATE products SET technical_specs = 'Corrélation endpoint/cloud/identité/réseau · 300+ connecteurs · Data lake 12 mois · Playbooks automatisés · API REST' WHERE slug = 'cyna-xdr' AND technical_specs IS NULL");

        $this->addSql("UPDATE categories SET image_url = 'https://images.unsplash.com/photo-1550751827-4bd374c3f58b?auto=format&fit=crop&w=900&q=80' WHERE slug LIKE '%soc%' AND image_url IS NULL");
        $this->addSql("UPDATE categories SET image_url = 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=900&q=80' WHERE slug LIKE '%edr%' AND image_url IS NULL");
        $this->addSql("UPDATE categories SET image_url = 'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?auto=format&fit=crop&w=900&q=80' WHERE slug LIKE '%xdr%' AND image_url IS NULL");

        $this->addSql("INSERT INTO home_texts (title, content, position, active)
            SELECT * FROM (SELECT 'Pourquoi CYNA ?' t, 'Des services de cybersécurité managés, opérés par des experts, facturés à l''abonnement : vous protégez votre entreprise sans construire votre propre SOC.' c, 1 p, 1 a) tmp
            WHERE NOT EXISTS (SELECT 1 FROM home_texts)");
        $this->addSql("INSERT INTO home_texts (title, content, position, active)
            SELECT * FROM (SELECT 'Une protection mesurable' t, 'Tableaux de bord, rapports mensuels et indicateurs clairs : vous savez à tout moment ce qui est détecté, bloqué et résolu.' c, 2 p, 1 a) tmp
            WHERE NOT EXISTS (SELECT 1 FROM home_texts WHERE position = 2)");

        $this->addSql("INSERT INTO chatbot_responses (keywords, answer, position, active)
            SELECT * FROM (SELECT 'prix,tarif,coût,cout,combien' k, 'Nos services sont facturés au mois : SOC managé à partir de 499 €/mois, EDR à 19,90 €/poste/mois, XDR à 899 €/mois. Le détail est sur chaque fiche produit.' a, 1 p, 1 ac) tmp
            WHERE NOT EXISTS (SELECT 1 FROM chatbot_responses)");
        $this->addSql("INSERT INTO chatbot_responses (keywords, answer, position, active)
            SELECT * FROM (SELECT 'essai,test,démo,demo,gratuit' k, 'Un essai gratuit de 30 jours est possible sur nos offres EDR et XDR. Cliquez sur « Demander un essai » depuis la fiche produit ou laissez-nous un message via le formulaire.' a, 2 p, 1 ac) tmp
            WHERE NOT EXISTS (SELECT 1 FROM chatbot_responses WHERE position = 2)");
        $this->addSql("INSERT INTO chatbot_responses (keywords, answer, position, active)
            SELECT * FROM (SELECT 'facture,paiement,carte,abonnement,résilier,resilier' k, 'Vos factures sont téléchargeables depuis « Mes commandes ». Les abonnements (1, 12 ou 24 mois) et moyens de paiement se gèrent depuis votre espace « Mon compte ».' a, 3 p, 1 ac) tmp
            WHERE NOT EXISTS (SELECT 1 FROM chatbot_responses WHERE position = 3)");
        $this->addSql("INSERT INTO chatbot_responses (keywords, answer, position, active)
            SELECT * FROM (SELECT 'contact,humain,conseiller,rappel,aide' k, 'Laissez-nous un message via le formulaire de cette page : un conseiller vous répond sous 24 h ouvrées.' a, 4 p, 1 ac) tmp
            WHERE NOT EXISTS (SELECT 1 FROM chatbot_responses WHERE position = 4)");
    }

    public function down(Schema $schema): void
    {
        $this->addSql('DROP INDEX idx_products_name ON products');
        $this->addSql('DROP INDEX idx_products_price ON products');
        $this->addSql('DROP TABLE IF EXISTS chatbot_responses');
        $this->addSql('DROP TABLE IF EXISTS home_texts');

        $addresses = $schema->getTable('addresses');
        foreach (['phone', 'region', 'line2', 'last_name', 'first_name'] as $column) {
            if ($addresses->hasColumn($column)) {
                $this->addSql('ALTER TABLE addresses DROP COLUMN '.$column);
            }
        }
        $categories = $schema->getTable('categories');
        if ($categories->hasColumn('image_url')) {
            $this->addSql('ALTER TABLE categories DROP COLUMN image_url');
        }
        $products = $schema->getTable('products');
        foreach (['technical_specs', 'stock'] as $column) {
            if ($products->hasColumn($column)) {
                $this->addSql('ALTER TABLE products DROP COLUMN '.$column);
            }
        }
    }
}
