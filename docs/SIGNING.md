# Release signing

Commits and tags on `main` are signed with an SSH key. GitHub shows the
result as **Verified** once the matching public key is registered on the
account.

## Verifying a release

Fetch the tag and check the signature against the public key committed
in this repository at `docs/signing_key.pub`:

```sh
git clone --filter=blob:none https://github.com/Everett406/servllama
cd servllama
git fetch origin 'refs/tags/v1.3.0:refs/tags/v1.3.0'

# allow git to resolve the signer identity
mkdir -p .git/allowed
cp docs/signing_key.pub .git/allowed/signing_key
git config gpg.ssh.allowedSignersFile .git/allowed/signing_key

git verify-tag v1.3.0
git verify-commit v1.3.0
```

`git verify-tag` prints the key fingerprint and the identity bound to
it. A valid signature over the tag object also transitively covers every
commit it points at.

## What is and is not signed

| Artefact | Signed |
| --- | --- |
| Commits on `main` | yes, SSH signature |
| Annotated tags | yes, SSH signature |
| GitHub Release page | no — the page itself is not a signed object; the tag it points at is |
| Android APK | no — see below |

APK signing is a separate mechanism. Android release signing uses a
keystore, not the git key, and this repository deliberately contains no
keystore. Release builds are signed at packaging time by whoever
produces the binary.

## Registering the key

The public key is at `docs/signing_key.pub`. To make GitHub display
"Verified" rather than "Unverified", add it under
**Settings → SSH and GPG keys → New SSH key**, type **Signing Key**.

## Rotating the key

The private half is required to sign; without it a compromised key
cannot be replaced retroactively. To rotate: generate a new key,
register it on the account, update `docs/signing_key.pub`, and note the
change in `CHANGELOG.md`.
