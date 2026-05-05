# ziggy-fodder

A small repo for scripts and utils used by OpenZiggy.

## cve-alert-zitified.py

Posts a daily Mattermost summary of network-exploitable, no-privileges-required CVEs from the NVD over an OpenZiti
overlay.

Originally written as an AWS Lambda that pulled its Ziti identity from AWS Secrets Manager and ran on a 15-minute
CloudWatch schedule. **Rewritten in May 2026 to run as a pair of GitHub Actions workflows**:

- `.github/workflows/cve-alert-daily.yml` -- 10:00 UTC every day, "blocks" format, 24-hour window.
- `.github/workflows/cve-alert-weekly.yml` -- 10:00 UTC Monday, markdown table, 7-day window, tighter floor.

Both call the same `cve-alert-zitified.py` script via `scripts/run-cve-alert.sh`, with behavior driven by `CVE_*` env
vars (see Tuning below). The Ziti identity is supplied via the `ZITI_MATTERMOST_IDENTITY` repo/org secret and the
zitified Mattermost webhook URL via `ZHOOK_URL_ZIGGY_FODDER`. The 2026 rewrite also moves the script from the retired
NVD v1.0 API to NVD v2.0 and ships the digest as a single dense markdown message rather than a fan-out of attachment
cards.

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
with 27 at `>= 9.0` would post all 27. Everything is sent as a single Mattermost message body in markdown (no
attachments, no chunking) so the post is dense and scannable.

Note: if your Mattermost server has a low `MaxPostSize` (default 4000 chars, often raised to 16383+ on self-hosted),
larger digests may be truncated. Tighten `CVE_TARGET_COUNT` or shrink `CVE_DESC_MAX_CHARS` if that becomes an issue.

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
| `CVE_DESC_MAX_CHARS` | `240` | Truncates each CVE's description in `blocks` format. The `table` format uses its own hard cap of 140 chars per row to keep cells single-line. |
| `CVE_WINDOW_DAYS` | `1` | Size of the lookback window in days. Daily uses `1`; weekly uses `7`. |
| `CVE_OUTPUT_FORMAT` | `blocks` | `blocks` (default) renders one CVE per markdown chunk with icon + bold link + description. `table` renders a single markdown table that copies cleanly into Excel/Sheets and is easier to scan for non-engineering readers. |
| `CVE_HEADER_PREFIX` | unset | Free-form text prepended above the standard summary header. The weekly workflow sources this from the `ZIGGY_FODDER_HEADER_PREFIX` GitHub secret so the recipient/wording (e.g. `@mark.jaffe here's the weekly CVE report!`) can be changed without a code edit. The secret value is masked in workflow logs but passes through to Mattermost intact. |
| `NVD_API_KEY` | unset | Optional NVD API key (free, registers in 2 minutes at <https://nvd.nist.gov/developers/request-an-api-key>). With a key NVD raises the rate limit from 5 to 50 req / 30s and gives requests higher priority. |
| `DRY_RUN` | unset | If set to `1`/`true`, skips the openziti import and the HTTP POST and prints the JSON payload(s) to stdout instead. Lets you iterate locally without a Ziti identity or webhook. |

Example -- tighten to "criticals only, top 10":

```bash
CVE_ALWAYS_MIN_SCORE=9.5 CVE_TARGET_COUNT=10 \
    ./scripts/run-cve-alert.sh "$(cat ./my-identity.json)" "$MM_WEBHOOK_URL"
```

### Dry run (no Ziti identity, no webhook needed)

To iterate on selection logic and rendering without posting anywhere, set `DRY_RUN=1` and skip the Ziti identity:

```bash
DRY_RUN=1 python3 cve-alert-zitified.py
```

The script skips the `openziti` import entirely and prints the Mattermost JSON payload it would have sent.

To preview how the message will actually render in Mattermost, switch to markdown output and paste the result into any
Mattermost channel:

```bash
DRY_RUN=1 DRY_RUN_FORMAT=markdown python3 cve-alert-zitified.py
```

(The colored sidebar on each attachment is a webhook feature and won't appear in pasted markdown, but everything else
matches.)
