# ziggy-fodder

A small repo for scripts and utils used by OpenZiggy.

## cve-alert-zitified.py

Posts a daily Mattermost summary of network-exploitable, no-privileges-required CVEs from the NVD over an OpenZiti
overlay.

Originally written as an AWS Lambda that pulled its Ziti identity from AWS Secrets Manager and ran on a 15-minute
CloudWatch schedule. **Rewritten in May 2026 to run as a GitHub Actions workflow** (`.github/workflows/cve-alert.yml`)
on a daily cron, with the Ziti identity supplied via the `ZITI_MATTERMOST_IDENTITY` repo/org secret and the zitified
Mattermost webhook URL via `ZHOOK_URL_ZIGGY_FODDER`. The 2026 rewrite also moves the script from the retired NVD v1.0
API to NVD v2.0 and switches the Mattermost payload to the richer `attachments[]` format.

The pre-rewrite Lambda version is preserved at the
[AWS-lambda release tag](https://github.com/openziti-test-kitchen/ziggy-fodder/releases/tag/AWS-lambda).

### Running locally

```bash
./scripts/run-cve-alert.sh "$(cat ./my-identity.json)" 'https://zitified.mattermost/hooks/xxxx'
```
