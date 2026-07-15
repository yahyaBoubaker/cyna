<?php

namespace App\Service;

/**
 * Envoi d'e-mails minimaliste par SMTP brut (sans dépendance Composer supplémentaire).
 *
 * Deux modes selon la configuration (variables d'environnement) :
 *  - Sans identifiants (MAILER_SMTP_USER vide) : SMTP simple vers Mailpit en local,
 *    qui capture les e-mails sans jamais les envoyer réellement (http://localhost:8025).
 *  - Avec identifiants : STARTTLS + AUTH LOGIN, permet d'envoyer vers de vraies adresses
 *    via un fournisseur comme Gmail (smtp.gmail.com:587 + mot de passe d'application).
 *
 * Le mot de passe ne doit JAMAIS être commité : il vient du fichier .env à la racine
 * du projet (git-ignoré), lu par docker-compose. Voir .env.example.
 */
class MailerService
{
    private string $host;
    private int $port;
    private string $username;
    private string $password;
    private string $encryption; // 'starttls' ou 'none'
    private string $fromEmail;
    private string $fromName;

    public function __construct()
    {
        $this->host = $_ENV['MAILER_SMTP_HOST'] ?? 'mailpit';
        $this->port = (int) ($_ENV['MAILER_SMTP_PORT'] ?? 1025);
        $this->username = $_ENV['MAILER_SMTP_USER'] ?? '';
        $this->password = $_ENV['MAILER_SMTP_PASSWORD'] ?? '';
        $this->encryption = strtolower($_ENV['MAILER_SMTP_ENCRYPTION'] ?? ($this->username !== '' ? 'starttls' : 'none'));
        // Gmail réécrit de toute façon l'expéditeur avec l'adresse du compte authentifié.
        $this->fromEmail = $_ENV['MAILER_FROM'] ?? ($this->username !== '' ? $this->username : 'no-reply@cyna.local');
        $this->fromName = 'CYNA';
    }

    /**
     * Envoie un e-mail texte brut. Retourne false en cas d'échec (ne lève pas d'exception),
     * pour ne jamais bloquer un parcours utilisateur à cause d'un souci de messagerie.
     */
    public function send(string $toEmail, string $subject, string $body): bool
    {
        $socket = @stream_socket_client("tcp://{$this->host}:{$this->port}", $errno, $errstr, 10);
        if (!$socket) {
            return false;
        }
        stream_set_timeout($socket, 10);

        try {
            $this->expect($socket, 220);
            $this->command($socket, 'EHLO cyna.local', 250);

            if ($this->encryption === 'starttls') {
                $this->command($socket, 'STARTTLS', 220);
                if (!stream_socket_enable_crypto($socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
                    throw new \RuntimeException('Échec de la négociation TLS.');
                }
                // Après STARTTLS, la session SMTP repart de zéro : EHLO obligatoire.
                $this->command($socket, 'EHLO cyna.local', 250);
            }

            if ($this->username !== '') {
                $this->command($socket, 'AUTH LOGIN', 334);
                $this->command($socket, base64_encode($this->username), 334);
                $this->command($socket, base64_encode($this->password), 235);
            }

            $this->command($socket, 'MAIL FROM:<'.$this->fromEmail.'>', 250);
            $this->command($socket, 'RCPT TO:<'.$toEmail.'>', 250);
            $this->command($socket, 'DATA', 354);

            $headers = [
                'From: '.$this->encodeHeader($this->fromName).' <'.$this->fromEmail.'>',
                'To: <'.$toEmail.'>',
                'Subject: '.$this->encodeHeader($subject),
                'MIME-Version: 1.0',
                'Content-Type: text/plain; charset=UTF-8',
                'Content-Transfer-Encoding: 8bit',
                'Date: '.date('r'),
            ];
            // Un point seul en début de ligne termine DATA (RFC 5321) : on l'échappe ("dot-stuffing").
            $safeBody = preg_replace('/^\./m', '..', str_replace("\n", "\r\n", $body));
            $message = implode("\r\n", $headers)."\r\n\r\n".$safeBody."\r\n.\r\n";
            fwrite($socket, $message);
            $this->expect($socket, 250);
            $this->command($socket, 'QUIT', 221);

            return true;
        } catch (\Throwable) {
            return false;
        } finally {
            fclose($socket);
        }
    }

    /**
     * Encode un en-tête contenant des caractères non-ASCII (RFC 2047), ex. "Confirmez votre adresse".
     */
    private function encodeHeader(string $value): string
    {
        return preg_match('/[^\x20-\x7E]/', $value) ? '=?UTF-8?B?'.base64_encode($value).'?=' : $value;
    }

    /**
     * @param resource $socket
     */
    private function command($socket, string $line, int $expectedCode): void
    {
        fwrite($socket, $line."\r\n");
        $this->expect($socket, $expectedCode);
    }

    /**
     * @param resource $socket
     */
    private function expect($socket, int $expectedCode): void
    {
        $response = '';
        while ($line = fgets($socket, 515)) {
            $response .= $line;
            // La ligne finale d'une réponse SMTP multi-lignes a un espace (et non un tiret) en 4e caractère.
            if (isset($line[3]) && $line[3] === ' ') {
                break;
            }
        }
        if ($response === '' || (int) substr($response, 0, 3) !== $expectedCode) {
            throw new \RuntimeException('Réponse SMTP inattendue : '.$response);
        }
    }
}
