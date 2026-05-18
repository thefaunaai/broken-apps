# Gatehouse

A small auth checkpoint target. It keeps the path intentionally plain:
email code, visual puzzle, protected page. Node only, around 250 lines.

## Auth Path

Email address, real email-code verification, server-verified puzzle
slider, protected page. The slider uses NASA's public-domain Blue
Marble image as its local source image.

## Requirements

- Docker (with `docker compose`)
- `make`
- `curl`

No Node or package install is required on your host.

## Run It

```sh
make up        # build and start the app
make reset     # wipe state, start fresh
make down      # stop and remove
```

Docker assigns an available host port and `make up` prints the URL. Use
`HOST_PORT=3101 make up` only when you need a fixed host port.

## Email Delivery

Without a local `.env`, Gatehouse prints verification codes to the
container logs.

For a real email run, put SMTP settings in `gatehouse/.env`. Keep this
file local; it contains SMTP credentials.

```dotenv
SMTP_URL=smtps://sender%40example.com:URL_ENCODED_PASSWORD@smtp.example.com:465
MAIL_FROM="Gatehouse <sender@example.com>"
ALLOWED_EMAIL=recipient@example.com
```

Initialize `.env` from `env.example`. Replace only the sender and
URL-encoded SMTP password. When `SMTP_URL` is set, `MAIL_FROM` and
`ALLOWED_EMAIL` are required so Gatehouse only sends to the allowed inbox.

```sh
make up
```

Use the Gatehouse URL and `ALLOWED_EMAIL` as the test recipient. The
verification code must come from that account's real inbox.

For SMTP debugging, watch the container logs:

```sh
docker compose logs -f gatehouse
```

When `SMTP_URL` is set, the app logs `GATEHOUSE_EMAIL_SEND_START` before
handing the message to SMTP and `GATEHOUSE_EMAIL_SEND_ACCEPTED` after
the SMTP server accepts it. It does not print verification codes in that
mode.

## EC2 Run

Use `infra/` when the run needs a public URL instead of a local Docker
port. The stack creates one disposable EC2 instance, serves HTTP only to
one allowed source IP, uses SSM instead of SSH, and manages SMTP config
in Secrets Manager from local Terraform settings.

Terraform state is local, gitignored, and disposable.
