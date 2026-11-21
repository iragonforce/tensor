# Tensor Configuration Repository

This repository contains reviewed, public configuration
snapshots for the Tensor Arch Linux workstation.

## Ownership

- The private `iragonforce/ops` repository is the
  authoritative infrastructure and deployment source.
- This repository is a public configuration snapshot.
- Do not deploy files from this repository automatically.
- Preserve working live configurations and existing
  uncommitted changes in `ops`.

## Security

- Never commit credentials, tokens, SSH private keys,
  personal data, runtime secrets or sensitive state.
- Review all files before public publication.
- Run Gitleaks before commits and pushes.
- Use explicit Git staging paths, not blanket `git add -A`.
- Exclude generated caches, logs and package databases.

## Workflow

1. Inspect the live configuration and its `ops` source.
2. Preserve intentional differences.
3. Copy approved files into this repository.
4. Verify the copy against the live source.
5. Scan staged content for secrets.
6. Commit only reviewed configuration snapshots.
