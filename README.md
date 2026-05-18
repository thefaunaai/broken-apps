# Broken Apps

Small applications built to make security testing claims concrete. Each
app is narrow enough to audit, but realistic enough to exercise a real
workflow.

Some apps are deliberately vulnerable. Others, like Gatehouse, exist to
exercise a real authenticated path before any protected state is
reachable.

Related writeups live at [cyberhound.ai/in-action](https://cyberhound.ai/in-action/).

## Apps

- [dossier](dossier/). Multi-tenant B2B project workspace.
  Cross-tenant account takeover chained into admin-only report access.
- [gatehouse](gatehouse/). Minimal auth checkpoint.
  Real email verification and a visual puzzle before a protected page.

## Run Safely

These apps are test targets, not production services. Run them locally
by default. Do not expose them to the public internet without an
explicit network allowlist.

Gatehouse includes a disposable EC2 stack for temporary cloud runs. That
stack restricts HTTP ingress to one allowed source IP. Do not run these
apps as unrestricted public services.

## License

[MIT](LICENSE).
