# Stage 0 GitHub CI/CD and Remote State Runbook

This document is formatted as plain Markdown so it can be pasted into Notion or imported as a Notion page.

## Purpose

Use this runbook to:

- attach Stage 0 to its remote Terraform state
- understand where to make Stage 0 changes
- configure GitHub Actions for Stage 0
- verify that Git changes become organization changes

## Environment Values

- Stage path:
  `C:\Users\jefer\Documents\dev\cloud-foundation-fabric\fast\stages\0-org-setup`
- Automation project:
  `brnfresh-prod-iac-core-0`
- Remote state bucket:
  `brnfresh-prod-iac-core-0-iac-org-state`
- Outputs bucket:
  `brnfresh-prod-iac-core-0-iac-outputs`
- Provider file:
  `gs://brnfresh-prod-iac-core-0-iac-outputs/providers/0-org-setup-providers.tf`
- Read-only provider file:
  `gs://brnfresh-prod-iac-core-0-iac-outputs/providers/0-org-setup-ro-providers.tf`

## Rule 1: Always Run From The Stage Directory

Run Terraform only from:

```powershell
cd C:\Users\jefer\Documents\dev\cloud-foundation-fabric\fast\stages\0-org-setup
```

Do not run Terraform from `~` or another directory after copying the provider file there.

If you run from the wrong directory, Terraform compares the real remote state to the wrong local configuration and can plan massive deletions.

## Rule 2: Always Use The Generated Provider File

To attach Stage 0 to the correct backend:

```powershell
cd C:\Users\jefer\Documents\dev\cloud-foundation-fabric\fast\stages\0-org-setup
Remove-Item Env:GOOGLE_CLOUD_QUOTA_PROJECT -ErrorAction SilentlyContinue
Remove-Item Env:GOOGLE_QUOTA_PROJECT -ErrorAction SilentlyContinue
gsutil cp gs://brnfresh-prod-iac-core-0-iac-outputs/providers/0-org-setup-providers.tf .\0-org-setup-providers.tf
terraform init -reconfigure -no-color
terraform plan -no-color
```

Expected result:

- `No changes. Your infrastructure matches the configuration.`

## Where To Make Changes In Stage 0

### Defaults

Edit:

- `fast/stages/0-org-setup/datasets/classic/defaults.bernal.yaml`

Use this file for:

- prefix
- organization-level defaults
- output path
- context mappings

### Folders

Edit:

- `fast/stages/0-org-setup/datasets/classic/folders`

Examples:

- top-level folder:
  `datasets/classic/folders/teams/.config.yaml`
- nested folder:
  `datasets/classic/folders/security/dev/.config.yaml`

### Organization Policies

Edit:

- `fast/stages/0-org-setup/datasets/classic/organization/org-policies`

Use this for:

- enabling policies
- changing policy values
- tightening or loosening org guardrails

### Organization IAM, Logging, Contacts

Edit:

- `fast/stages/0-org-setup/datasets/classic/organization/.config.yaml`

### Organization Tags

Edit:

- `fast/stages/0-org-setup/datasets/classic/organization/tags`

### CI/CD Settings

Edit:

- `fast/stages/0-org-setup/datasets/classic/cicd.yaml`

## Standard Day-2 Operating Flow

1. edit Stage 0 YAML
2. run a local plan or open a pull request
3. review the diff
4. merge the change
5. let CI/CD apply it
6. verify the environment returns to `No changes`

## GitHub CI/CD Design

Recommended design:

- pull requests:
  `terraform plan`
- merges to `master`:
  `terraform apply`

Use these service accounts:

- plan:
  `iac-org-cicd-ro@brnfresh-prod-iac-core-0.iam.gserviceaccount.com`
- apply:
  `iac-org-cicd-rw@brnfresh-prod-iac-core-0.iam.gserviceaccount.com`

Central CI/CD project:

- `brnfresh-prod-iac-core-0`

This project is the shared automation hub for:

- remote Terraform state
- provider files
- outputs
- workload identity federation
- Stage 0 CI/CD service accounts

## Step-By-Step GitHub CI/CD Setup

Replace these values before running commands:

- GitHub repository:
  `jbernal62/cloud-foundation-fabric`
- GitHub owner:
  `jbernal62`
- Branch:
  `master`

### Step 1: Update The Stage 0 CI/CD Dataset File

```powershell
cd C:\Users\jefer\Documents\dev\cloud-foundation-fabric
(Get-Content .\fast\stages\0-org-setup\datasets\classic\cicd.yaml) `
  -replace 'name: myorg/0-org-setup', 'name: jbernal62/cloud-foundation-fabric' `
  | Set-Content .\fast\stages\0-org-setup\datasets\classic\cicd.yaml
```

### Step 2: Enable GitHub Workload Identity In `iac-0`

Edit:

- `fast/stages/0-org-setup/datasets/classic/projects/core/iac-0.yaml`

Add:

```yaml
workload_identity_pools:
  default:
    display_name: Default pool for CI/CD.
    providers:
      github-default:
        display_name: GitHub (jbernal62).
        attribute_condition: attribute.repository_owner=="jbernal62"
        identity_provider:
          oidc:
            template: github
```

### Step 3: Re-Apply Stage 0

```powershell
cd C:\Users\jefer\Documents\dev\cloud-foundation-fabric\fast\stages\0-org-setup
Remove-Item Env:GOOGLE_CLOUD_QUOTA_PROJECT -ErrorAction SilentlyContinue
Remove-Item Env:GOOGLE_QUOTA_PROJECT -ErrorAction SilentlyContinue
gsutil cp gs://brnfresh-prod-iac-core-0-iac-outputs/providers/0-org-setup-providers.tf .\0-org-setup-providers.tf
terraform init -reconfigure -no-color
terraform plan -no-color
terraform apply -no-color
```

### Step 4: Verify The Provider Files

```powershell
gcloud storage ls gs://brnfresh-prod-iac-core-0-iac-outputs/providers/
```

Expected:

- `0-org-setup-providers.tf`
- `0-org-setup-ro-providers.tf`

### Step 5: Create GitHub Actions Workflows

Create the workflow folder:

```powershell
cd C:\Users\jefer\Documents\dev\cloud-foundation-fabric
New-Item -ItemType Directory -Force .\.github\workflows
```

Create `.github/workflows/stage0-plan.yaml`:

```yaml
name: stage0-plan

on:
  pull_request:
    paths:
      - 'fast/stages/0-org-setup/**'

permissions:
  id-token: write
  contents: read
  pull-requests: write

jobs:
  plan:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: fast/stages/0-org-setup

    steps:
      - uses: actions/checkout@v4

      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: projects/660895060666/locations/global/workloadIdentityPools/default/providers/github-default
          service_account: iac-org-cicd-ro@brnfresh-prod-iac-core-0.iam.gserviceaccount.com

      - uses: google-github-actions/setup-gcloud@v2

      - uses: hashicorp/setup-terraform@v3

      - run: gsutil cp gs://brnfresh-prod-iac-core-0-iac-outputs/providers/0-org-setup-ro-providers.tf ./0-org-setup-providers.tf
      - run: terraform init -reconfigure -no-color
      - run: terraform plan -no-color
```

Create `.github/workflows/stage0-apply.yaml`:

```yaml
name: stage0-apply

on:
  push:
    branches:
      - master
    paths:
      - 'fast/stages/0-org-setup/**'

permissions:
  id-token: write
  contents: read

jobs:
  apply:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: fast/stages/0-org-setup

    steps:
      - uses: actions/checkout@v4

      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: projects/660895060666/locations/global/workloadIdentityPools/default/providers/github-default
          service_account: iac-org-cicd-rw@brnfresh-prod-iac-core-0.iam.gserviceaccount.com

      - uses: google-github-actions/setup-gcloud@v2

      - uses: hashicorp/setup-terraform@v3

      - run: gsutil cp gs://brnfresh-prod-iac-core-0-iac-outputs/providers/0-org-setup-providers.tf ./0-org-setup-providers.tf
      - run: terraform init -reconfigure -no-color
      - run: terraform apply -auto-approve -no-color
```

### Step 6: Commit And Push

```powershell
cd C:\Users\jefer\Documents\dev\cloud-foundation-fabric
git add .\fast\stages\0-org-setup\datasets\classic\cicd.yaml
git add .\fast\stages\0-org-setup\datasets\classic\projects\core\iac-0.yaml
git add .\.github\workflows\stage0-plan.yaml
git add .\.github\workflows\stage0-apply.yaml
git commit -m "Configure Stage 0 GitHub CI/CD"
git push origin master
```

### Step 7: Test PR Plan

```powershell
cd C:\Users\jefer\Documents\dev\cloud-foundation-fabric
git checkout -b test/stage0-plan
```

Make a harmless change under `fast/stages/0-org-setup`, then:

```powershell
git add .
git commit -m "Test Stage 0 plan pipeline"
git push origin test/stage0-plan
```

Open a pull request and verify:

- `stage0-plan` succeeds

### Step 8: Test Merge Apply

Merge into `master`.

Then verify locally:

```powershell
cd C:\Users\jefer\Documents\dev\cloud-foundation-fabric\fast\stages\0-org-setup
Remove-Item Env:GOOGLE_CLOUD_QUOTA_PROJECT -ErrorAction SilentlyContinue
Remove-Item Env:GOOGLE_QUOTA_PROJECT -ErrorAction SilentlyContinue
gsutil cp gs://brnfresh-prod-iac-core-0-iac-outputs/providers/0-org-setup-providers.tf .\0-org-setup-providers.tf
terraform init -reconfigure -no-color
terraform plan -no-color
```

Expected:

- `No changes. Your infrastructure matches the configuration.`

## Outcome

If all of the above is configured correctly:

- Stage 0 uses remote state only
- PRs show Terraform diffs
- merges can update the organization automatically
- the state bucket remains the single source of truth
