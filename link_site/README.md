# Link page for `ink.fuzzzycore.com`

Published on Firebase Hosting (project `fuzzy-core-website`, site `fuzzzy-ink`) with `firebase.json`
here: from this folder, `firebase deploy --only hosting`. The domain's DNS is on Cloudflare: its records
for `ink` stay "DNS only" (grey cloud) so Firebase holds the certificate and serves the link files
untouched.


## Files

- `index.html`: the page people see when they tap a Fuzzzy Ink link without the app. No scripts, no
  analytics, nothing loaded from elsewhere; the `Content-Security-Policy` in it forbids all of that.
- `.well-known/apple-app-site-association`: lets iPhones open the links in the app.
- `.well-known/assetlinks.json`: lets Android phones open the links in the app.

Both name the **production app only** (`com.fuzzzycore.ink`). A test build (`.stg`, `.dev`) signed with a weaker
key must never be able to take over production links (security review 2026-10-26). The test builds' entries live
in `../link_site_test_builds/.well-known/`; publish those only on a separate test host, never on
`ink.fuzzzycore.com`. Until a test host exists, test builds open links by pasting them into Open.

## Still to replace

The Apple team id (`7W88HRQFXP`) and the Play app signing key's SHA-256 (in `assetlinks.json`) are in (owner 2026-10-27). Left:

| Placeholder | Where | What |
|---|---|---|
| `REPLACE_WITH_APP_STORE_ID` | `index.html` | the number in the App Store address |
| `REPLACE_WITH_DESKTOP_DOWNLOAD_URL` | `index.html` | where the Mac, Windows and Linux builds are downloaded |

The download buttons are `hidden` until the two `index.html` values exist.


## Hosting rules

- HTTPS on `ink.fuzzzycore.com`, valid certificate.
- `/invite`, `/accept` and `/message` all serve `index.html` (a rewrite, not a redirect).
- `/.well-known/apple-app-site-association` and `/.well-known/assetlinks.json` are served as
  `application/json`, with status 200 and no redirect. Many hosts skip dot-folders by default (Firebase
  Hosting's default `ignore` does): make sure `.well-known` is published.
- No analytics or tag manager on this host.

The part of a link after `#` is never sent to the host, so the server only ever sees `/invite`,
`/accept` or `/message`.
