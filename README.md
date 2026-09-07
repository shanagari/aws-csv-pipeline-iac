# CSV Ingestion Pipeline — CloudFormation (IaC)

This turns the manually-built pipeline into a single deployable/destroyable
CloudFormation stack.

## What gets created

- 3 S3 buckets: input, output, and a scripts bucket (holds the Glue job code)
- 2 IAM roles: `LambdaGlueTriggerRole-CFN`, `GlueETLRole-CFN`
- 1 Glue Database, 1 Crawler, 1 Python Shell ETL Job
- 1 Glue Workflow with two triggers (on-demand → crawler, conditional →
  job on crawler success) — identical logic to the manual setup
- 1 Lambda function that starts the workflow when a `.csv` lands under
  `raw/` in the input bucket
- A small helper Lambda (backing a CloudFormation custom resource) that
  wires the S3 → Lambda event notification, since that link can't be
  expressed directly without a circular dependency in the template
- Optional: an SNS topic + EventBridge rules for Glue job/crawler failure
  alerts, only created if you pass a notification email

## Prerequisites

- AWS CLI configured (or run from CloudShell, where it already is)
- Permissions to create IAM roles, Lambda functions, Glue resources, S3
  buckets, SNS topics, and EventBridge rules

## Files

- `pipeline.yaml` — the CloudFormation template
- `scripts/transform.py` — the Glue Python Shell ETL script (uploaded to
  the scripts bucket by `deploy.sh`, not embedded in the template)
- `deploy.sh` — deploys the stack, then uploads the ETL script
- `destroy.sh` — empties the buckets, then deletes the stack

## Deploy

```bash
chmod +x deploy.sh destroy.sh
./deploy.sh you@example.com   # email is optional; omit to skip alerts
```

This will:
1. Create/update the CloudFormation stack (`csv-pipeline-stack`).
2. Upload `scripts/transform.py` to the scripts bucket.
3. Print the input bucket name and the exact S3 paths to upload your CSVs to.

After that, upload your two data files:
```bash
aws s3 cp movies.csv  s3://<input-bucket>/raw/movies/movies.csv
aws s3 cp ratings.csv s3://<input-bucket>/raw/ratings/ratings.csv
```
Either upload triggers Lambda → Glue Workflow (crawler → ETL job)
automatically. Check `s3://<output-bucket>/transformed/` for the result.

If you provided a notification email, confirm the SNS subscription email
that AWS sends you, or you won't receive failure alerts.

## Destroy

```bash
./destroy.sh
```

This empties all three S3 buckets (CloudFormation refuses to delete
non-empty buckets) and then deletes the full stack — Lambda functions,
IAM roles, Glue resources, SNS topic, EventBridge rules, all removed
in one step.

## Deploying via GitHub Actions (CI/CD)

Instead of running `deploy.sh` yourself, you can let GitHub Actions deploy
the stack automatically on every push — using a dedicated IAM user scoped
to just this pipeline, not your main account credentials.

### 1. Create a dedicated IAM user

1. **IAM console → Users → Create user**.
2. Name: `csv-pipeline-ci-deployer`.
3. Do **not** attach any AWS managed policies yet — you'll attach a
   scoped custom policy instead.
4. After the user is created, open it → **Permissions → Add permissions
   → Create inline policy → JSON tab** → paste the contents of
   `iam/deploy-user-policy.json` (in this folder) → save.
5. Go to **Security credentials** tab → **Create access key** → choose
   **Third-party service** (or "Command Line Interface") as the use
   case → **Create**.
6. Copy the **Access key ID** and **Secret access key** immediately —
   the secret is only shown once.

This user can only manage the exact resources this stack creates
(`aws-bootcamp-*` buckets, the `-CFN` IAM roles, `-v2` Lambda functions,
and this specific CloudFormation stack) — it cannot touch your other
AWS resources, including your original manually-built pipeline.

### 2. Push this folder to a GitHub repo

```bash
git init
git add .
git commit -m "CSV pipeline IaC"
git branch -M main
git remote add origin https://github.com/<you>/<repo>.git
git push -u origin main
```

### 3. Add GitHub Secrets

In your repo: **Settings → Secrets and variables → Actions → New
repository secret**. Add:

| Secret name             | Value                                  |
|--------------------------|-----------------------------------------|
| `AWS_ACCESS_KEY_ID`      | from step 1                            |
| `AWS_SECRET_ACCESS_KEY`  | from step 1                            |
| `AWS_REGION`             | e.g. `ap-southeast-2`                  |

Note: you do **not** need a separate "git token" for this — GitHub
Actions automatically provides its own token for checking out your
repo. The credentials above are purely for authenticating *to AWS*,
which is the actual missing piece.

### 4. Deploy

- **Automatic**: push a change to `pipeline.yaml` or
  `scripts/transform.py` on `main` — `.github/workflows/deploy.yml`
  runs automatically.
- **Manual**: go to **Actions tab → Deploy CSV Pipeline → Run workflow**,
  optionally filling in a notification email.

Check the **Actions** tab for logs — the final step prints the stack
outputs (bucket names, workflow name) same as running `deploy.sh` locally.

### 5. Destroy

Go to **Actions tab → Destroy CSV Pipeline → Run workflow**, and type
`destroy` into the confirmation input. This is a manual-only, confirmation-gated
workflow — it will not run on push, and won't run without typing the exact
word `destroy`, to prevent an accidental teardown.

## Notes / things worth knowing

- **Bucket names must be globally unique.** The defaults in `pipeline.yaml`
  (`aws-bootcamp-input-v2`, etc.) may already be taken by someone else on
  AWS. If `deploy.sh` fails with a bucket-name-already-exists error, edit
  the `Default` values in `pipeline.yaml` (or pass
  `--parameter-overrides InputBucketName=... OutputBucketName=... ScriptsBucketName=...`
  in `deploy.sh`) to something unique.
- **This is separate from your manually-built resources** (`aws-bootcamp-input`,
  `Glue-role-af74499e`, etc. without the `-v2` suffix) — nothing here touches
  those. You can run both side by side, or manually delete the old console-built
  resources once you've confirmed this stack works.
- **Re-running `deploy.sh`** is safe — `aws cloudformation deploy` diffs
  against the existing stack and only updates what changed.
- **The Glue Job script isn't embedded in the template.** Glue Jobs require
  `ScriptLocation` to point to an S3 object, so `deploy.sh` uploads
  `scripts/transform.py` after the stack (and its scripts bucket) exists. If
  you edit the script, just re-run `deploy.sh` — it re-uploads on every run.
