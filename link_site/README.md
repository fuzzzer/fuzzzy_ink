# Link page for `ink.fuzzzycore.com`

Not published. Hosting is the owner's step.

## Files

- `index.html`: the page people see when they tap a Fuzzzy Ink link without the app. No scripts, no
  analytics, nothing loaded from elsewhere; the `Content-Security-Policy` in it forbids all of that.
- `.well-known/apple-app-site-association`: lets iPhones open the links in the app.
- `.well-known/assetlinks.json`: lets Android phones open the links in the app.

## Before publishing, replace

| Placeholder | Where | What |
|---|---|---|
| `REPLACE_WITH_APPLE_TEAM_ID` | `apple-app-site-association` (3×) | the Apple Developer team id that signs the app |
| `REPLACE_WITH_PRODUCTION_RELEASE_CERT_SHA256_FINGERPRINT` | `assetlinks.json` | SHA-256 of the certificate Google Play signs `com.fuzzzycore.ink` with (Play Console › App integrity › App signing), as `AB:CD:…` |
| `REPLACE_WITH_STAGING_CERT_SHA256_FINGERPRINT`, `REPLACE_WITH_DEVELOPMENT_CERT_SHA256_FINGERPRINT` | `assetlinks.json` | the same for the test builds (`.stg`, `.dev`), or delete those two entries |
| `REPLACE_WITH_APP_STORE_ID` | `index.html` | the number in the App Store address |
| `REPLACE_WITH_DESKTOP_DOWNLOAD_URL` | `index.html` | where the Mac, Windows and Linux builds are downloaded |

Drop the `.stg` / `.dev` app ids from the Apple file too if test builds should not open links.

## Hosting rules

- HTTPS on `ink.fuzzzycore.com`, valid certificate.
- `/invite`, `/accept` and `/message` all serve `index.html` (a rewrite, not a redirect).
- `/.well-known/apple-app-site-association` and `/.well-known/assetlinks.json` are served as
  `application/json`, with status 200 and no redirect. Many hosts skip dot-folders by default (Firebase
  Hosting's default `ignore` does): make sure `.well-known` is published.
- No analytics or tag manager on this host.

The part of a link after `#` is never sent to the host, so the server only ever sees `/invite`,
`/accept` or `/message`.
