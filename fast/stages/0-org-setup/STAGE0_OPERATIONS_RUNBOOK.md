# Stage 0 Operations Runbook

This runbook documents how to operate FAST Stage 0 in this environment after bootstrap:

- where to make changes
- how to run Terraform safely against remote state
- how to configure GitHub CI/CD for Stage 0
- how to verify that Git changes become organization changes

This runbook is specific to the current environment:

- Stage path: `C:\Users\jefer\Documents\dev\cloud-foundation-fabric\fast\stages\0-org-setup`
- automation project: `brnfresh-prod-iac-core-0`
- remote state bucket: `brnfresh-prod-iac-core-0-iac-org-state`
- outputs bucket: `brnfresh-prod-iac-core-0-iac-outputs`

## Working Directory

Always run Stage 0 from:

```powershell
cd C:\Users\jefer\Documents\dev\cloud-foundation-fabric\fast\stages\0-org-setup
```

Do not run Terraform from `~` or another directory after copying the provider file there. If you do that, Terraform will compare the remote state to the wrong local configuration and plan large deletions.

## Where To Make Changes

Use these locations for day-2 changes:

- defaults and global settings:
  `fast/stages/0-org-setup/datasets/classic/defaults.bernal.yaml`
- folder hierarchy and folder IAM/tags:
  `fast/stages/0-org-setup/datasets/classic/folders`
- org policies:
  `fast/stages/0-org-setup/datasets/classic/organization/org-policies`
- org IAM, logging, contacts:
  `fast/stages/0-org-setup/datasets/classic/organization/.config.yaml`
- org tags:
  `fast/stages/0-org-setup/datasets/classic/organization/tags`
- project definitions:
  `fast/stages/0-org-setup/datasets/classic/projects`
- Stage 0 CI/CD settings:
  `fast/stages/0-org-setup/datasets/classic/cicd.yaml`

Examples:

- add a folder:
  create a new directory under `datasets/classic/folders` and add a `.config.yaml`
- change a policy:
  edit the relevant file in `datasets/classic/organization/org-policies`
- change org admins or sink settings:
  edit `datasets/classic/organization/.config.yaml`

## Remote State Rules

Stage 0 must always use the generated provider file from the outputs bucket.

Current provider file in GCS:

```powershell
gs://brnfresh-prod-iac-core-0-iac-outputs/providers/0-org-setup-providers.tf
```

Current read-only provider file in GCS:

```powershell
gs://brnfresh-prod-iac-core-0-iac-outputs/providers/0-org-setup-ro-providers.tf
```

Current state bucket:

```powershell
gs://brnfresh-prod-iac-core-0-iac-org-state
```

## Verified Remote State Workflow

Use this exact PowerShell sequence to attach Stage 0 to the remote backend:

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

Why the environment variables are cleared:

- stale quota-project overrides caused `USER_PROJECT_DENIED` errors after backend migration
- Stage 0 now works correctly without those overrides

## Standard Day-2 Workflow

1. edit the Stage 0 YAML files in Git
2. run a local plan or open a pull request
3. review the Terraform diff
4. merge the change
5. let CI/CD apply the change
6. verify the environment returns to `No changes`

Local verification command:

```powershell
cd C:\Users\jefer\Documents\dev\cloud-foundation-fabric\fast\stages\0-org-setup
Remove-Item Env:GOOGLE_CLOUD_QUOTA_PROJECT -ErrorAction SilentlyContinue
Remove-Item Env:GOOGLE_QUOTA_PROJECT -ErrorAction SilentlyContinue
gsutil cp gs://brnfresh-prod-iac-core-0-iac-outputs/providers/0-org-setup-providers.tf .\0-org-setup-providers.tf
terraform init -reconfigure -no-color
terraform plan -no-color
```

## GitHub CI/CD Design

The recommended model for Stage 0 is:

- pull requests: run `terraform plan`
- merges to `master`: run `terraform apply`

Use:

- read-only service account for PR plans:
  `iac-org-cicd-ro@brnfresh-prod-iac-core-0.iam.gserviceaccount.com`
- read-write service account for applies:
  `iac-org-cicd-rw@brnfresh-prod-iac-core-0.iam.gserviceaccount.com`

The central automation project for Stage 0 CI/CD is:

- `brnfresh-prod-iac-core-0`

That project is the shared automation hub for:

- state bucket
- outputs bucket
- Workload Identity Federation provider
- Stage 0 CI/CD service accounts

## Step-By-Step GitHub CI/CD Setup

Replace these values with your own before running the commands:

- GitHub repository: `jbernal62/cloud-foundation-fabric`
- GitHub owner: `jbernal62`
- default branch: `master`

### 1. Update the repository reference in the Stage 0 CI/CD config

Run from the repository root:

```powershell
cd C:\Users\jefer\Documents\dev\cloud-foundation-fabric
(Get-Content .\fast\stages\0-org-setup\datasets\classic\cicd.yaml) `
  -replace 'name: myorg/0-org-setup', 'name: jbernal62/cloud-foundation-fabric' `
  | Set-Content .\fast\stages\0-org-setup\datasets\classic\cicd.yaml
```

### 2. Enable GitHub Workload Identity in `iac-0`

Edit:

- `fast/stages/0-org-setup/datasets/classic/projects/core/iac-0.yaml`

Add or uncomment:

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

### 3. Apply Stage 0 again

```powershell
cd C:\Users\jefer\Documents\dev\cloud-foundation-fabric\fast\stages\0-org-setup
Remove-Item Env:GOOGLE_CLOUD_QUOTA_PROJECT -ErrorAction SilentlyContinue
Remove-Item Env:GOOGLE_QUOTA_PROJECT -ErrorAction SilentlyContinue
gsutil cp gs://brnfresh-prod-iac-core-0-iac-outputs/providers/0-org-setup-providers.tf .\0-org-setup-providers.tf
terraform init -reconfigure -no-color
terraform plan -no-color
terraform apply -no-color
```

This should create:

- the GitHub Workload Identity pool/provider
- impersonation bindings for the CI/CD service accounts

### 4. Verify generated provider files

```powershell
gcloud storage ls gs://brnfresh-prod-iac-core-0-iac-outputs/providers/
```

Expected:

- `0-org-setup-providers.tf`
- `0-org-setup-ro-providers.tf`

### 5. Create GitHub Actions workflow files

Create the workflows directory:

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

### 6. Commit and push

```powershell
cd C:\Users\jefer\Documents\dev\cloud-foundation-fabric
git add .\fast\stages\0-org-setup\datasets\classic\cicd.yaml
git add .\fast\stages\0-org-setup\datasets\classic\projects\core\iac-0.yaml
git add .\.github\workflows\stage0-plan.yaml
git add .\.github\workflows\stage0-apply.yaml
git add .\fast\stages\0-org-setup\STAGE0_OPERATIONS_RUNBOOK.md
git add .\fast\stages\0-org-setup\README.md
git commit -m "Configure Stage 0 GitHub CI/CD"
git push origin master
```

### 7. Test the PR plan flow

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

- `stage0-plan` runs successfully

### 8. Test the merge apply flow

Merge the pull request into `master`.

That should trigger:

- `stage0-apply`

Post-merge verification:

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

## What This Guarantees

If the above is followed, then:

- all Stage 0 plans and applies use remote state
- CI/CD runs from the real Stage 0 folder
- GitHub PRs show Terraform diffs before merge
- merges to `master` can update the organization automatically
- the GCS state bucket remains the single source of truth
