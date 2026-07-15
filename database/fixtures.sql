INSERT IGNORE INTO users (id, email, first_name, last_name, roles, password, verified, created_at) VALUES
(1, 'admin@cyna.local', 'Admin', 'CYNA', JSON_ARRAY('ROLE_ADMIN','ROLE_USER'), '$2y$10$g6D8EeNDmVZ9YN/EX/e9QebynZUo9G2i3TgjW2HaqfjPkcVYEN8bu', 1, NOW()),
(2, 'user@cyna.local', 'Camille', 'Martin', JSON_ARRAY('ROLE_USER'), '$2y$10$GpZT6OK2jiZvwm9ekIq.5OBzLmqcOBsrF2ybFTTb8ilvFrUiFqo86', 1, NOW());

INSERT IGNORE INTO categories (id, name, slug, description, active) VALUES
(1, 'SOC', 'soc', 'Supervision de securite 24/7 et detection des incidents.', 1),
(2, 'EDR', 'edr', 'Protection des postes et serveurs avec reponse automatisee.', 1),
(3, 'XDR', 'xdr', 'Correlation avancee des signaux de securite sur tout le SI.', 1);

INSERT IGNORE INTO products (id, category_id, name, slug, description, monthly_price, active, created_at) VALUES
(1, 1, 'Cyna SOC', 'cyna-soc', 'Service SOC managé avec supervision, alerting, rapports mensuels et accompagnement analyste.', 499.00, 1, NOW()),
(2, 2, 'Cyna EDR', 'cyna-edr', 'Protection endpoint avec detection comportementale, isolation machine et tableaux de bord.', 19.90, 1, NOW()),
(3, 3, 'Cyna XDR', 'cyna-xdr', 'Plateforme XDR pour correler endpoint, cloud, identite et reseau dans une vue unifiee.', 899.00, 1, NOW());

INSERT IGNORE INTO product_images (id, product_id, url, alt, position) VALUES
(1, 1, 'https://images.unsplash.com/photo-1550751827-4bd374c3f58b?auto=format&fit=crop&w=1200&q=80', 'Centre operationnel de cybersecurite', 1),
(2, 2, 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=1200&q=80', 'Protection endpoint', 1),
(3, 3, 'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?auto=format&fit=crop&w=1200&q=80', 'Plateforme XDR', 1),
(4, 1, 'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=1200&q=80', 'Tableau de bord alertes SOC', 2),
(5, 1, 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?auto=format&fit=crop&w=1200&q=80', 'Rapport de supervision SOC', 3),
(6, 2, 'https://images.unsplash.com/photo-1563986768609-322da13575f3?auto=format&fit=crop&w=1200&q=80', 'Interface de gestion des menaces EDR', 2),
(7, 3, 'https://images.unsplash.com/photo-1504384308090-c894fdcc538d?auto=format&fit=crop&w=1200&q=80', 'Correlation multi-source XDR', 2);

INSERT IGNORE INTO carts (id, user_id, updated_at) VALUES (1, 1, NOW()), (2, 2, NOW());

INSERT IGNORE INTO home_carousel (id, title, subtitle, image_url, cta_url, position, active) VALUES
(1, 'CYNA Cybersecurity SaaS', 'Des services SOC, EDR et XDR pour proteger les entreprises sans complexite inutile.', 'https://images.unsplash.com/photo-1563986768609-322da13575f3?auto=format&fit=crop&w=1600&q=80', '/catalogue', 1, 1),
(2, 'SOC managé 24/7', 'Une equipe d''analystes qui surveille votre infrastructure en continu et reagit aux incidents.', 'https://images.unsplash.com/photo-1550751827-4bd374c3f58b?auto=format&fit=crop&w=1600&q=80', '/categorie/1', 2, 1),
(3, 'EDR nouvelle generation', 'Detection comportementale et isolation automatique des postes compromis.', 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=1600&q=80', '/categorie/2', 3, 1);

INSERT IGNORE INTO featured_products (id, product_id, position) VALUES (1, 1, 1), (2, 2, 2), (3, 3, 3);
