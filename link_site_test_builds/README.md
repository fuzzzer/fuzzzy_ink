# Link verification for test builds

The staging (`com.fuzzzycore.ink.stg`) and development (`com.fuzzzycore.ink.dev`) builds' entries, kept apart from
the production files in `../link_site/` so a test build never verifies for `ink.fuzzzycore.com` (security review
2026-10-26). Publish these only on a separate test host, and only together with test builds that name that host.
Replace `REPLACE_WITH_APPLE_TEAM_ID`, `REPLACE_WITH_STAGING_CERT_SHA256_FINGERPRINT` and
`REPLACE_WITH_DEVELOPMENT_CERT_SHA256_FINGERPRINT` first. Not published.
