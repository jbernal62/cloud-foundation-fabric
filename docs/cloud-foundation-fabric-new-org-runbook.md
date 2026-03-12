# Cloud Foundation Fabric New Organization Runbook

## Purpose

This runbook explains how to prepare a brand-new Google Cloud organization and deploy Cloud Foundation Fabric FAST from this repository.

It is written as an operator guide for someone who needs to:

- understand what must exist before deployment
- prepare the organization correctly
- configure the repo for a real environment
- execute stage `0-org-setup` safely
- verify the bootstrap results
- move on to later stages with the right expectations

This document assumes you are using the FAST stages in this repository, with stage `0-org-setup` as the bootstrap entry point.

## What FAST Means in This Repo

The important FAST stages are:

- `fast/stages/0-org-setup`
  - bootstrap and organization foundation
- `fast/stages/1-vpcsc`
  - VPC Service Controls
- `fast/stages/2-networking`
  - centralized networking
- `fast/stages/2-security`
  - centralized security services
- `fast/stages/2-project-factory`
  - scalable workload or team project creation

For a new organization, stage 0 is the starting point.

## What Stage 0 Does

Stage 0 creates and manages the landing-zone control plane. In the default classic dataset, it is responsible for:

- organization IAM
- custom organization roles
- organization policies
- tag keys and tag values
- top-level folders
- child folders
- core shared projects
- stage automation service accounts
- state and outputs buckets
- centralized logging setup
- CI/CD and identity provider foundations
- output contracts consumed by later stages

In other words, stage 0 is not just a tiny bootstrap. It is the root of the landing zone.

## What You Must Prepare Before Running Anything

For a newly created organization, prepare these prerequisites first.

### 1. One Google Cloud organization

You need:

- organization id
- organization domain
- customer id

Useful command:

```bash
gcloud organizations list
```

### 2. One billing account

You need a billing account that can fund the bootstrap projects.

Useful command:

```bash
gcloud beta billing accounts list
```

Decide which billing model you are using:

- billing account owned by the same organization
- external billing account

That choice affects where billing IAM is managed.

### 3. One bootstrap admin principal

For the first stage-0 apply, you need a human principal with enough access to build the landing zone. In practice, use a Google Group if possible.

Recommended pattern:

- create a group like `gcp-org-admins@example.com`
- add the human bootstrap operators to that group
- use that group in the defaults file

### 4. A local execution environment

Minimum local tooling:

- `gcloud`
- `terraform >= 1.12.2`
- `git`
- optional but useful: `yq`

Check Terraform:

```bash
terraform version
```

This repo requires Terraform `>= 1.12.2`.

### 5. A dedicated repo configuration folder

Do not hardcode your environment directly into the shared FAST dataset. Create or use a separate config folder under:

- `fast-config/<your-environment>`

This folder should contain:

- `defaults.yaml`
- generated provider files after bootstrap
- optionally local output artifacts

Example:

- `fast-config/bernal-live`

## Recommended Design Decisions Before Bootstrap

Make these decisions before you start stage 0.

### 1. Which dataset to use

Stage 0 supports multiple dataset styles.

Main choices:

- `datasets/classic`
  - best starting point for most deployments
- `datasets/hardened`
  - stronger controls from day one

If you are starting fresh and want clarity, use `classic` first unless you already know you need the hardened controls.

### 2. Naming prefix

The project prefix is a major design decision. It will appear in the generated core project IDs.

The prefix must be:

- unique
- short
- stable

Example:

- `brnllab`

### 3. Primary region

Decide where you want:

- storage buckets
- logging resources
- BigQuery resources

Example:

- `us-central1`

### 4. Output strategy

Choose where FAST should write generated provider files and tfvars:

- local filesystem
- GCS outputs bucket
- both

For initial bootstrap, local output files are often the easiest operational model.

## Files You Need to Configure

The main environment file for stage 0 is:

- `fast-config/<env>/defaults.yaml`

You may also eventually customize parts of the dataset under:

- `fast/stages/0-org-setup/datasets/classic`

But start by changing only the environment defaults unless the landing-zone design itself must change.

## Step 1: Create or Update the Environment Defaults File

Create a file like:

- `fast-config/my-live/defaults.yaml`

At minimum, set:

- billing account
- organization id
- domain
- customer id
- project prefix
- default regions
- bootstrap admin group
- output file destinations

Minimal example:

```yaml
global:
  billing_account: 123456-123456-123456
  organization:
    domain: example.com
    id: 123456789012
    customer_id: C0123abcd

observability:
  project_id: $project_ids:log-0
  number: $project_numbers:log-0

projects:
  defaults:
    prefix: example
    locations:
      bigquery: us-central1
      logging: us-central1
      storage: us-central1
  overrides: {}

context:
  email_addresses:
    gcp-organization-admins: gcp-org-admins@example.com
  iam_principals:
    gcp-organization-admins: group:gcp-org-admins@example.com
  locations:
    primary: us-central1

output_files:
  local_path: ~/fast-config/example
  storage_bucket: $storage_buckets:iac-0/iac-outputs
  providers:
    0-org-setup:
      bucket: $storage_buckets:iac-0/iac-org-state
      service_account: $iam_principals:service_accounts/iac-0/iac-org-rw
    0-org-setup-ro:
      bucket: $storage_buckets:iac-0/iac-org-state
      service_account: $iam_principals:service_accounts/iac-0/iac-org-ro
```

## Step 2: Decide Whether You Need Dataset Changes

If the default classic landing zone is acceptable, do not edit the dataset yet.

The classic dataset already defines:

- organization config
- custom roles
- tags
- folders
- core projects

Default top-level folders:

- `Networking`
- `Security`
- `Data Platform`
- `Teams`

Default core projects:

- `billing-0`
- `iac-0`
- `log-0`

Only edit dataset YAML at this stage if you intentionally want a different landing-zone design.

## Step 3: Prepare the Stage-0 tfvars

Stage 0 needs to know:

- which dataset to use
- where your environment defaults file lives

Create this file in the stage directory when you run bootstrap:

- `fast/stages/0-org-setup/0-org-setup.auto.tfvars`

Example:

```hcl
factories_config = {
  dataset = "datasets/classic"
  paths = {
    defaults = "/home/jeff/Documents/dev/cloud-foundation-fabric/fast-config/my-live/defaults.yaml"
  }
}
```

Use absolute paths for the environment defaults file to avoid ambiguity.

## Step 4: Grant the Initial Human Bootstrap Permissions

Before the first apply, the human bootstrap principal needs enough rights to create org-level resources.

The baseline roles for the first-run operator are effectively the ones described in the stage-0 README:

- `roles/billing.admin`
- `roles/logging.admin`
- `roles/iam.organizationRoleAdmin`
- `roles/orgpolicy.policyAdmin`
- `roles/resourcemanager.folderAdmin`
- `roles/resourcemanager.organizationAdmin`
- `roles/resourcemanager.projectCreator`
- `roles/resourcemanager.tagAdmin`
- `roles/owner`

Example self-grant flow:

```bash
export FAST_PRINCIPAL="group:gcp-org-admins@example.com"
export FAST_ORG_ID=123456789012

export FAST_ROLES="\
  roles/billing.admin \
  roles/logging.admin \
  roles/iam.organizationRoleAdmin \
  roles/orgpolicy.policyAdmin \
  roles/resourcemanager.folderAdmin \
  roles/resourcemanager.organizationAdmin \
  roles/resourcemanager.projectCreator \
  roles/resourcemanager.tagAdmin \
  roles/owner"

for role in $FAST_ROLES; do
  gcloud organizations add-iam-policy-binding "$FAST_ORG_ID" \
    --member "$FAST_PRINCIPAL" \
    --role "$role" \
    --condition None
done
```

If you are using an external billing account, also ensure the bootstrap principal has the required billing access there.

## Step 5: Prepare gcloud and Authentication

Set a clean gcloud config if you want to isolate this deployment from your normal workstation state.

Example:

```bash
export CLOUDSDK_CONFIG=/tmp/gcloud-cff
mkdir -p "$CLOUDSDK_CONFIG"
```

Login:

```bash
gcloud auth login
gcloud auth application-default login
```

If you do not yet have a useful default project in a new organization, read the next step carefully.

## Step 6: Set a Temporary Default Project If Needed

For very new organizations, org policy creation may fail if `gcloud` has no usable default project for quota and API tracking.

If needed:

1. create a temporary project manually in the console
2. attach billing
3. set it as the default project
4. enable required bootstrap APIs

Example:

```bash
gcloud config set project TEMP_PROJECT_ID

gcloud services enable \
  bigquery.googleapis.com \
  cloudbilling.googleapis.com \
  cloudresourcemanager.googleapis.com \
  essentialcontacts.googleapis.com \
  iam.googleapis.com \
  logging.googleapis.com \
  orgpolicy.googleapis.com \
  serviceusage.googleapis.com
```

After stage 0 succeeds, switch the default project to the new `iac-0` project.

## Step 7: Handle Brownfield Conflicts Before Apply

If the organization is truly new, you may skip this section.

If the organization already contains resources, prepare for:

- existing org policies
- existing tag keys
- existing custom roles
- existing IAM bindings

At minimum, check org policies:

```bash
gcloud org-policies list --organization 123456789012
```

If the dataset defines policies that already exist, set `org_policies_imports` in `0-org-setup.auto.tfvars`.

Example:

```hcl
org_policies_imports = [
  "iam.allowedPolicyMemberDomains",
  "iam.automaticIamGrantsForDefaultServiceAccounts",
  "iam.managed.disableServiceAccountKeyCreation",
  "iam.managed.disableServiceAccountKeyUpload",
  "storage.uniformBucketLevelAccess"
]
```

For a truly new org, this is usually unnecessary.

## Step 8: Run the First Stage-0 Apply With User Credentials

Change into the stage root:

```bash
cd /home/jeff/Documents/dev/cloud-foundation-fabric/fast/stages/0-org-setup
```

Run:

```bash
terraform init
terraform apply
```

This first apply is expected to create at least:

- the folder hierarchy
- `billing-0`
- `iac-0`
- `log-0`
- stage automation service accounts
- state buckets
- outputs bucket
- org policies
- custom roles
- tags

## Step 9: Verify Stage 0 Created the Expected Foundation

After the first successful apply, verify the basics.

### Verify projects

```bash
gcloud projects list --filter='projectId:YOURPREFIX-*'
```

Expected:

- `YOURPREFIX-prod-billing-exp-0`
- `YOURPREFIX-prod-iac-core-0`
- `YOURPREFIX-prod-audit-logs-0`

### Verify folders

```bash
gcloud resource-manager folders list --organization=YOUR_ORG_ID
```

Expected top-level folders:

- `Networking`
- `Security`
- `Data Platform`
- `Teams`

### Verify service accounts

```bash
gcloud iam service-accounts list --project=YOURPREFIX-prod-iac-core-0
```

Expected service accounts include:

- `iac-org-rw`
- `iac-org-ro`
- `iac-vpcsc-rw`
- `iac-vpcsc-ro`
- `iac-networking-rw`
- `iac-networking-ro`
- `iac-security-rw`
- `iac-security-ro`
- `iac-pf-rw`
- `iac-pf-ro`

### Verify buckets

```bash
gcloud storage buckets list --project=YOURPREFIX-prod-iac-core-0
```

Expected buckets:

- `...-iac-org-state`
- `...-iac-stage-state`
- `...-iac-outputs`

## Step 10: Switch Stage 0 to the Generated Provider File

After the bootstrap resources exist, stage 0 should stop relying on the initial human credentials and move to the generated provider/backend configuration.

The generated provider file is expected either:

- in your configured local outputs path
- or in the outputs bucket

If local outputs are enabled:

```bash
../fast-links.sh ~/fast-config/example
```

If you are using the outputs bucket:

```bash
../fast-links.sh gs://YOURPREFIX-prod-iac-core-0-iac-outputs
```

Copy or link the generated `0-org-setup-providers.tf` into the stage directory.

This file should include:

- backend bucket
- impersonated service account

Typical target service account:

- `iac-org-rw@YOURPREFIX-prod-iac-core-0.iam.gserviceaccount.com`

## Step 11: Migrate Stage-0 State to the Remote Backend

Once the provider file exists locally in the stage root, migrate state:

```bash
terraform init -migrate-state
```

Then run:

```bash
terraform state list
```

This must return populated resources.

If it returns nothing and the live landing zone already exists, stop. That means state was not migrated correctly.

Only continue if state is populated.

## Step 12: Run the First Managed Plan

Now run:

```bash
terraform plan
```

Healthy outcomes:

- no changes
- or a very small amount of harmless drift

Dangerous outcome:

- hundreds of resources to add

If Terraform wants to add the whole landing zone again, your state is not aligned with live resources.

Do not apply in that case.

## Step 13: Switch Default gcloud Project to `iac-0`

Once stage 0 is healthy, switch your default gcloud project:

```bash
gcloud config set project YOURPREFIX-prod-iac-core-0
```

That becomes the normal administrative control-plane project for later stages.

## Step 14: Understand What Later Stages Need From Stage 0

Stage 0 produces the contract used by later stages.

Later stages depend on:

- generated provider files
- generated tfvars
- stage service accounts
- state bucket structure
- project ids and numbers
- IAM principal mappings
- tags
- logging identities

If stage 0 is not healthy, later stages will not be healthy.

## Step 15: Stage 1 Deployment

Stage 1 is:

- `fast/stages/1-vpcsc`

It is optional, but if you use it, it should come after stage 0.

Typical flow:

1. link or copy the generated provider file for stage 1
2. link or copy stage-0 generated tfvars
3. create stage-1 specific tfvars if needed
4. run `terraform init`
5. run `terraform plan`
6. run `terraform apply`

The stage-1 provider file normally points at:

- `iac-stage-state`
- prefix `1-vpcsc`
- impersonated service account `iac-vpcsc-rw`

## How to Advance the Landing Zone After Bootstrap

After stage 0 is stable, the normal progression is:

1. stage 1 if you want VPC Service Controls
2. stage 2 networking for shared VPC and connectivity
3. stage 2 security for KMS and security services
4. stage 2 project factory for workload projects
5. stage 3 environment-specific platforms

That order is not arbitrary. It follows the dependency chain created by stage 0 outputs.

## How to Add Projects the Right Way

There are two categories of projects.

### 1. Foundation projects

These belong in stage 0.

Examples:

- shared IaC control-plane projects
- central logging projects
- central billing export projects
- extra foundation infrastructure projects

To customize these, edit:

- `fast/stages/0-org-setup/datasets/classic/projects/core/*`

### 2. Workload or team projects

These usually do not belong in stage 0.

Use:

- `fast/stages/2-project-factory`

This is the recommended place for:

- app projects
- team dev/prod projects
- tenant projects
- business-unit project onboarding

Rule:

- if the project is part of the landing-zone control plane, use stage 0
- if the project is payload, use project factory

## Common Failure Modes in New Deployments

### 1. Terraform version too old

Symptom:

- errors about unsupported Terraform core version
- import block syntax failures

Fix:

- use Terraform `>= 1.12.2`

### 2. Wrong execution identity

Symptom:

- `403` on custom roles
- `403` on logging settings
- `403` on tags or org policies

Fix:

- ensure the initial human principal has enough rights for the first apply
- ensure the generated provider file uses the correct stage-0 RW service account after bootstrap

### 3. Existing org resources collide with apply

Symptom:

- `ALREADY_EXISTS` for tags
- policy conflicts
- custom role conflicts

Fix:

- import or reconcile brownfield resources before normal apply

### 4. Empty state but live resources exist

Symptom:

- `terraform state list` returns nothing
- `terraform plan` wants to create the entire landing zone again

Fix:

- recover or import state before applying anything

### 5. Outputs bucket only partially populated

Symptom:

- provider files exist
- tfvars artifacts are missing

Fix:

- inspect `output-files.tf`
- verify output bucket IAM and object creation during stage 0

## Suggested First Successful Deployment Checklist

You are in good shape when all of the following are true:

- `terraform version` is compatible
- defaults file is complete
- stage-0 tfvars points to the right defaults file
- first stage-0 apply succeeds
- folders exist
- core projects exist
- stage service accounts exist
- state and outputs buckets exist
- generated provider file exists
- state migration succeeds
- `terraform state list` is populated
- `terraform plan` is small or empty

## Exact Stage-0 Command Sequence

This is the short operator sequence for a new organization.

```bash
cd /home/jeff/Documents/dev/cloud-foundation-fabric/fast/stages/0-org-setup

export CLOUDSDK_CONFIG=/tmp/gcloud-cff
mkdir -p "$CLOUDSDK_CONFIG"

gcloud auth login
gcloud auth application-default login

# optional if you need a temporary project
gcloud config set project TEMP_PROJECT_ID

cat > 0-org-setup.auto.tfvars <<'EOF'
factories_config = {
  dataset = "datasets/classic"
  paths = {
    defaults = "/home/jeff/Documents/dev/cloud-foundation-fabric/fast-config/my-live/defaults.yaml"
  }
}
EOF

terraform init
terraform apply

# link or copy generated provider file
# then migrate state
terraform init -migrate-state
terraform state list
terraform plan
```

If `terraform state list` is empty after the migration step, stop and investigate. Do not apply again.

## Recommended Documentation to Maintain Per Environment

For each real environment, keep these artifacts:

- one environment defaults file
- one bootstrap operator runbook
- one state recovery checklist
- one document describing the intended folder and project taxonomy
- one document describing which stages are in scope

For this repo, a good structure is:

- this runbook for new-organization bootstrap
- the existing bootstrap/Terraform architecture guide
- an environment-specific operational note for each deployed org

## Final Guidance

For a new organization:

- keep the first deployment conservative
- use the stock classic dataset unless you have a strong reason not to
- get stage 0 healthy before touching later stages
- do not mix payload project creation into stage 0 unless the projects are truly foundational
- treat state migration as a required part of bootstrap, not an optional cleanup step

If you want, the next useful deliverable is a second document with:

- a copy-paste `defaults.yaml` template for a brand-new org
- a brownfield recovery guide
- a stage-by-stage promotion checklist from 0 to 3
