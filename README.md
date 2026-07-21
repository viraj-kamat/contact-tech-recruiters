# contact_tech_recruiters

Sensitive project files live in an encrypted vault. Git only stores ciphertext. Day-to-day work happens in a local `decrypted/` folder that is gitignored.

## Layout

| Path | Committed? | Purpose |
|------|------------|---------|
| `encrypted/vault.enc` | yes | Encrypted archive of the working tree |
| `decrypted/` | **no** (gitignored) | Plaintext working files after unlock |
| `./unlock` | yes | Decrypt vault → `decrypted/` |
| `./add` | yes | Encrypt `decrypted/` → overwrite `encrypted/vault.enc` |

## Workflow

**First time / this machine (you already have plaintext in `decrypted/`):**

```bash
./add                 # enter passkey (confirm once) → writes encrypted/vault.enc
git add encrypted add unlock README.md .gitignore
git commit -m "Store encrypted working tree"
git push
```

**Every change:**

```bash
# edit files under decrypted/
./add                 # re-encrypt (overwrites encrypted/vault.enc)
git add encrypted
git commit -m "Update vault"
git push
```

**Fresh clone:**

```bash
git clone <url>
cd contact_recruiters
./unlock              # enter passkey → creates decrypted/
cd decrypted
python send_emails.py # run tools from inside decrypted/
```

## Notes

- Passkey is never stored; you enter it each time you run `./add` or `./unlock`.
- `./add` fully replaces `encrypted/vault.enc` with a fresh encryption of everything under `decrypted/`.
- Run Python scripts from `decrypted/` so relative paths like `data/` and `app_pass.enc` resolve correctly.
