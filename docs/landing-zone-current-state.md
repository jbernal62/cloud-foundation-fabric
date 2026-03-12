# Bernal Landing Zone Current State

## Executive Summary

This document compares the intended stage `0-org-setup` landing zone in this repo with the current live GCP environment for `bernal.live`.

The main finding is:

- The landing zone is live in GCP and matches the expected Bernal stage-0 shape in several key areas.
- The configured stage-0 backend bucket `brnllab-prod-iac-core-0-iac-org-state` is currently empty from OpenTofu's perspective.
- Running the current plan with a supported engine produced `Plan: 306 to add, 0 to change, 0 to destroy`.

Interpretation:

- Stage 0 appears to have been implemented live.
- Stage 0 is not currently represented in the configured remote backend state.
- The outputs pipeline is only partially present: generated provider files and a version file exist, but generated `tfvars/` artifacts are missing from the outputs bucket.

## Verification Method and Evidence Sources

### Defined in code

- FAST target config: `fast-config/bernal-live/defaults.yaml`
- Stage implementation: `fast/stages/0-org-setup`
- Dataset shape: `fast/stages/0-org-setup/datasets/classic`
- Provider backend template already generated in repo: `fast-config/bernal-live/providers/0-org-setup-providers.tf`

### Verified live

- Fresh `gcloud` login performed with `CLOUDSDK_CONFIG=/tmp/gcloud-cff`
- Active account used for verification: `yeferson@bernal.live`
- Active project used for verification: `brnllab-prod-iac-core-0`
- ADC login completed successfully
- Service account impersonation succeeded for:
  - `iac-org-rw@brnllab-prod-iac-core-0.iam.gserviceaccount.com`
  - `iac-org-ro@brnllab-prod-iac-core-0.iam.gserviceaccount.com`
- OpenTofu `init -reconfigure` succeeded against the configured GCS backend
- OpenTofu `state list` returned no resources
- OpenTofu `plan` succeeded and produced `306 to add, 0 to change, 0 to destroy`

### Notes / drift

- Local `terraform` is `1.5.7`, which is too old for this repo version (`>= 1.12.2` required).
- Verification plan execution used local `OpenTofu v1.11.5`, which is compatible with this repo's `.tofu` constraints.
- This means the configuration is valid and plannable, but not with the currently installed Terraform binary.

## Current GCP Organization Context

### Defined in code

| Item | Value |
| --- | --- |
| Organization domain | `bernal.live` |
| Organization ID | `874229980578` |
| Customer ID | `C044gz3of` |
| Prefix | `brnllab` |
| Primary region | `us-central1` |
| Billing account | `01822A-82C726-7D1D60` |

### Verified live

- Organization-scoped resources were successfully queried under `organizations/874229980578`
- Organization tag keys exist for:
  - `context`
  - `environment`
  - `org-policies`

### Notes / drift

- The code and the live organization identifiers are aligned based on successful live lookups.

## Stage-0 Status

### Defined in code

- Stage-0 backend bucket: `brnllab-prod-iac-core-0-iac-org-state`
- Stage-0 outputs bucket: `brnllab-prod-iac-core-0-iac-outputs`
- Stage-0 implementation is expected to manage:
  - organization IAM
  - org policies
  - custom roles
  - tag keys and tag values
  - top-level landing-zone folders
  - core projects
  - automation service accounts
  - state and output buckets
  - logging buckets in `log-0`

### Verified live

- `OpenTofu init -reconfigure` against the GCS backend succeeded
- `tofu state list` returned no resources
- `tofu plan` result:
  - `306 to add`
  - `0 to change`
  - `0 to destroy`
- Live resources clearly exist despite the empty backend state:
  - folders exist
  - core projects exist
  - state/output buckets exist
  - stage service accounts exist
  - log buckets exist
  - org policies exist
  - tag keys and values exist

### Notes / drift

- The live environment looks implemented.
- The configured remote backend is effectively empty.
- The practical result is that the current stage-0 plan behaves like a fresh deployment plan instead of a managed in-place plan.
- Most likely explanations:
  - state was never migrated into `brnllab-prod-iac-core-0-iac-org-state`
  - state was deleted or moved
  - deployment happened through another backend or workspace path

## Folder Hierarchy

### Defined in code

Top-level folders expected by the classic dataset:

- `Networking`
- `Security`
- `Data Platform`
- `Teams`

Expected child folders:

- `Networking/Development`
- `Networking/Production`
- `Security/Development`
- `Security/Production`
- `Data Platform/Development`
- `Data Platform/Production`

### Verified live

Top-level folders:

| Folder | ID |
| --- | --- |
| Networking | `229456340432` |
| Security | `599967350938` |
| Data Platform | `563031405216` |
| Teams | `1056834612646` |

Child folders:

| Parent | Child | ID |
| --- | --- | --- |
| Networking | Development | `20127630788` |
| Networking | Production | `89717422555` |
| Security | Development | `200305988853` |
| Security | Production | `289820302957` |
| Data Platform | Development | `782948186045` |
| Data Platform | Production | `778957597909` |

### Notes / drift

- The live folder hierarchy matches the code-defined classic layout and the hard-coded parent references in the dataset.
- Folder creation timestamps indicate these were created on March 6, 2026.

## Core Projects and Their Purpose

### Defined in code

Expected core projects:

| Project key | Expected project ID | Purpose |
| --- | --- | --- |
| `billing-0` | `brnllab-prod-billing-exp-0` | Billing export project |
| `iac-0` | `brnllab-prod-iac-core-0` | IaC core, service accounts, state and output buckets |
| `log-0` | `brnllab-prod-audit-logs-0` | Centralized logging and log buckets |

### Verified live

| Project ID | Project number |
| --- | --- |
| `brnllab-prod-billing-exp-0` | `781996178634` |
| `brnllab-prod-iac-core-0` | `637871936179` |
| `brnllab-prod-audit-logs-0` | `1013855101249` |

### Notes / drift

- All expected core projects exist live.
- The project IDs match the naming pattern implied by the Bernal defaults and classic dataset.

## IAM and Service Account Model

### Defined in code

The stage-0 project `iac-0` is expected to host service accounts for:

- org setup
- org setup CI/CD
- VPC-SC
- networking
- security
- project factory
- data platform dev

Each area has read-write and read-only service accounts.

### Verified live

Verified in project `brnllab-prod-iac-core-0`:

- `iac-org-rw`
- `iac-org-ro`
- `iac-org-cicd-rw`
- `iac-org-cicd-ro`
- `iac-vpcsc-rw`
- `iac-vpcsc-ro`
- `iac-networking-rw`
- `iac-networking-ro`
- `iac-security-rw`
- `iac-security-ro`
- `iac-pf-rw`
- `iac-pf-ro`
- `iac-dp-dev-rw`
- `iac-dp-dev-ro`

Impersonation was verified live for:

- `iac-org-rw`
- `iac-org-ro`

### Notes / drift

- The service account inventory strongly supports that stage 0 was executed successfully at least once.
- The IAM/service-account layer exists live even though backend state is empty.

## Logging, State, and Output Buckets

### Defined in code

Expected GCS buckets in `iac-0`:

- `brnllab-prod-iac-core-0-iac-org-state`
- `brnllab-prod-iac-core-0-iac-stage-state`
- `brnllab-prod-iac-core-0-iac-outputs`

Expected custom log buckets in `log-0`:

- `audit-logs`
- `iam`
- `vpc-sc`

### Verified live

GCS buckets in `brnllab-prod-iac-core-0`:

- `brnllab-prod-iac-core-0-iac-org-state`
- `brnllab-prod-iac-core-0-iac-stage-state`
- `brnllab-prod-iac-core-0-iac-outputs`

Outputs bucket contents:

- `providers/0-org-setup-providers.tf`
- `providers/0-org-setup-ro-providers.tf`
- `versions/0-org-setup-version.txt`

Observed missing outputs artifacts:

- no `tfvars/` objects were present in the outputs bucket

Log buckets in `brnllab-prod-audit-logs-0`:

| Bucket | Retention days | Notes |
| --- | --- | --- |
| `_Default` | `30` | default platform bucket |
| `_Required` | `400` | required audit bucket |
| `audit-logs` | `30` | custom stage-0 bucket |
| `iam` | `30` | custom stage-0 bucket |
| `vpc-sc` | `31` | custom stage-0 bucket, analytics enabled |

### Notes / drift

- The buckets expected from stage 0 exist live.
- The backend state bucket is empty from OpenTofu's perspective.
- The outputs bucket is only partially populated.

## Org Policies, Tags, and Custom Roles

### Defined in code

The classic stage-0 dataset defines:

- organization org policies
- organization custom roles
- organization tag keys:
  - `context`
  - `environment`
  - `org-policies`

Expected live tag values used by the folder layout:

- `context/project-factory`
- `environment/development`
- `environment/production`

### Verified live

Tag keys found:

- `context`
- `environment`
- `org-policies`

Tag values found:

- `environment/development`
- `environment/production`
- `context/project-factory`

Organization policies found live include:

- `iam.allowedPolicyMemberDomains`
- `iam.disableServiceAccountKeyCreation`
- `iam.disableServiceAccountKeyUpload`
- `iam.automaticIamGrantsForDefaultServiceAccounts`
- `storage.uniformBucketLevelAccess`
- `essentialcontacts.allowedContactDomains`
- `compute.restrictProtocolForwardingCreationForTypes`
- `compute.setNewProjectDefaultToZonalDNSOnly`

### Notes / drift

- The live org policies align with the classic stage-0 policy set.
- Tag keys and values align with the expected Bernal landing-zone taxonomy.
- Custom roles were not exhaustively enumerated in this pass, but their downstream effects are visible in the IAM and resource layout.

## Gaps, Drift, and Follow-up Actions

### Confirmed gaps

- Stage-0 backend state is empty.
- Outputs bucket lacks generated `tfvars/` artifacts.
- The installed `terraform` binary is too old for this repo version.

### What this means

- The landing zone is live.
- The current stage-0 backend does not represent that live landing zone.
- A direct apply from the current backend would attempt to create resources that already exist.

### Recommended follow-up actions

1. Identify the original state source for stage 0.
2. Check whether state exists under a different bucket, prefix, workspace, or historical backend.
3. If no prior state is recoverable, decide between:
   - importing live resources into the configured backend
   - rebuilding stage-0 state from scratch with controlled imports
4. Recreate or restore missing outputs bucket `tfvars/` artifacts if downstream stages depend on them.
5. Upgrade local Terraform to `>= 1.12.2` if you need native Terraform execution instead of OpenTofu for future runs.

### Final assessment

- `Stage 0 implemented live:` Yes
- `Stage 0 represented in configured backend state:` No
- `Current plan aligned with live environment:` No
- `Reason:` backend state is empty, so the plan wants to create the landing zone again
