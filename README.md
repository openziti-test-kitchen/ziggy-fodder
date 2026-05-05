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

### Filtering

NVD's `cvssV3Metrics` query filter is AND-only, so the script issues two queries per run (one for `AV:N`, one for
`PR:N`) and unions the results by CVE id. The workflow log prints the breakdown each run, e.g.:

```
AV:N only: 114, PR:N only: 10, BOTH: 126, UNION: 250
```

A representative 24-hour sample (2026-05-05) showed 250 CVEs in the union, of which 126 had both `AV:N` and `PR:N`.
Severity distribution that day, cumulative by floor:

| Floor | Count |
|------:|------:|
| `>= 10.0` | 1 |
| `>= 9.8`  | 20 |
| `>= 9.0`  | 27 |
| `>= 8.8`  | 47 |
| `>= 8.0`  | 58 |
| `>= 7.0`  | 132 |

### Selection policy

Posting one attachment per CVE doesn't scale to 250/day, so the script picks what to post using two knobs:

- `CVE_ALWAYS_MIN_SCORE` (default `9.0`) -- every CVE at or above this score is always included.
- `CVE_TARGET_COUNT` (default `20`) -- target post count. If the always-included set is smaller than this, the next
  highest-scoring CVEs below the floor pad it up. If the always-included set is already larger, it's posted in full
  (criticals are never dropped).

For example, with the defaults: a day with 5 CVEs at `>= 9.0` would post those 5 plus the 15 highest below 9.0; a day
with 27 at `>= 9.0` would post all 27. Each Mattermost message carries up to 10 attachments, so larger posts are split
into chunks with a `(part N/M)` suffix.

### Running locally

You need an enrolled Ziti identity with policy granting access to the zitified Mattermost service. Save the identity
JSON to a file, then:

```bash
./scripts/run-cve-alert.sh "$(cat ./my-identity.json)" 'https://zitified.mattermost/hooks/xxxx'
```

To avoid spamming the production channel while iterating, point `MM_WEBHOOK_URL` at a throwaway incoming-webhook in a
personal/test channel on the same Mattermost server -- the same identity will work for any webhook the policy permits.

### Tuning

Both knobs read from the environment, so they're easy to override locally or per-workflow-run without code changes:

| Variable | Default | Effect |
|----------|---------|--------|
| `CVE_ALWAYS_MIN_SCORE` | `9.0` | Every CVE at or above this CVSS base score is always included. |
| `CVE_TARGET_COUNT` | `20` | Target post count. The selection is padded up to this with the next-highest-scoring CVEs below the floor. If the always-included set already exceeds the target, it's posted in full. |

Example -- tighten to "criticals only, top 10":

```bash
CVE_ALWAYS_MIN_SCORE=9.5 CVE_TARGET_COUNT=10 \
    ./scripts/run-cve-alert.sh "$(cat ./my-identity.json)" "$MM_WEBHOOK_URL"
```
