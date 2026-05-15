# Installation

## Prérequis

- Docker et Docker Compose.
- Optionnel hors Docker : PHP 8.2+, Composer, Symfony CLI, Node.js 22+, Flutter 3+.

## Lancer toute la plateforme

```bash
docker compose up --build
```

## Backend Symfony

```bash
cd backend-symfony
composer install
php bin/console doctrine:database:create --if-not-exists
php bin/console doctrine:migrations:migrate
php bin/console doctrine:fixtures:load
symfony server:start --port=8000
```

Si la commande `symfony` n'est pas installée, lancer le backend avec le serveur PHP intégré :

```bash
cd backend-symfony
php -S 127.0.0.1:8000 -t public public/index.php
```

## Frontend client

```bash
cd frontend-react
npm install
npm run dev
```

## Back-office

```bash
cd backoffice-react
npm install
npm run dev -- --port 5174
```

## Mobile Flutter

```bash
cd mobile-flutter
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:8000/api
```

Sur un appareil physique, remplacer `10.0.2.2` par l'adresse IP locale de la machine qui héberge Symfony.

## MySQL

Configuration Docker :

- Host : `localhost`
- Port : `3306`
- Database : `cyna`
- User : `cyna`
- Password : `cyna`
- Root password : `root`

phpMyAdmin est disponible sur http://localhost:8080.
