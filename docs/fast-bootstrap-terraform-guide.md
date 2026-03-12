# FAST Bootstrap and Stage 1 Terraform Guide

## What This Document Covers

This guide explains the initial FAST bootstrap flow from the Terraform point of view:

- what stage `0-org-setup` actually creates
- how the bootstrap is structured in Terraform
- how later stages, especially stage `1-vpcsc`, depend on it
- how provider files, state buckets, and generated tfvars are supposed to work
- how to customize the initial landing zone
- how to add custom projects correctly

This is written for operators working directly in the console and in the FAST repo.

## Stage Numbering Clarification

FAST stage numbering is:

- Stage 0: `0-org-setup`
- Stage 1: `1-vpcsc`
- Stage 2: shared services stages such as networking, security, and project factory
- Stage 3: workload or environment-specific stages

So if you say "stage 01" in FAST terms, there are two relevant pieces:

- the initial bootstrap is stage 0
- the first stage after bootstrap is stage 1, VPC Service Controls

From the Terraform perspective, stage 0 is the foundation. Stage 1 is optional and consumes outputs from stage 0.

## Bootstrap Architecture in Terraform

Stage 0 is a Terraform root module located at:

- `fast/stages/0-org-setup`

Its job is to translate YAML configuration into organization-level, folder-level, and project-level GCP resources. It does this mainly through the `project-factory` module plus the `organization` module.

The high-level Terraform model is:

1. Load defaults and factory paths.
2. Build interpolation context from static values and generated values.
3. Create organization-level resources.
4. Create folder hierarchy and core projects.
5. Create stage automation resources such as service accounts and buckets.
6. Export provider files and tfvars for later stages.

The important Terraform files in stage 0 are:

- `main.tf`
  - loads defaults, context, and stage-wide preconditions
- `factory.tf`
  - invokes `modules/project-factory` for folders, projects, service accounts, buckets, budgets
- `organization.tf`
  - invokes the organization module for org IAM, org policies, tags, contacts, logging
- `billing.tf`
  - configures billing-account-level IAM when needed
- `cicd-workflows.tf`
  - configures workload identity or CI/CD-related resources
- `identity-providers-defs.tf`
  - identity provider definitions and supporting locals
- `output-files.tf`
  - generates provider files and tfvars artifacts for downstream stages
- `outputs.tf`
  - exposes runtime outputs from the stage

## What Stage 0 Actually Creates

Stage 0 is not a "small bootstrap". It is the landing-zone foundation. In the default classic FAST design it creates or manages:

- organization IAM
- organization policies
- organization custom roles
- tag keys and tag values
- top-level folders
- child folders
- core shared projects
- service accounts for future stages
- GCS buckets for state and outputs
- log buckets
- logging sinks
- CI/CD trust and impersonation resources
- context outputs used by later stages

In the classic dataset, the expected top-level folders are:

- `Networking`
- `Security`
- `Data Platform`
- `Teams`

The classic core projects are:

- `billing-0`
- `iac-0`
- `log-0`

Those are not application projects. They are foundation projects.

## Input Model: How FAST Drives Terraform

Stage 0 is driven by a mix of Terraform code and YAML data.

### 1. Terraform root module

The Terraform root in `fast/stages/0-org-setup` defines:

- lifecycle
- provider usage
- module wiring
- output contracts
- import behavior for brownfield org policies

### 2. Defaults YAML

The defaults file defines global identity and project conventions:

- organization id and domain
- billing account
- project prefix
- default regions
- named IAM principals
- output file destinations

For your environment this lives at:

- `fast-config/bernal-live/defaults.yaml`

### 3. Dataset YAML

The selected dataset defines the landing-zone shape.

In classic FAST, the dataset lives under:

- `fast/stages/0-org-setup/datasets/classic`

That dataset provides:

- organization config
- custom roles
- org policies
- tags
- folder tree
- core projects
- observability definitions
- CI/CD workflow inputs

### 4. Context interpolation

FAST uses symbolic references like:

- `$project_ids:log-0`
- `$iam_principals:gcp-organization-admins`
- `$storage_buckets:iac-0/iac-org-state`
- `$tag_values:environment/development`

These references make the YAML portable. Terraform resolves them after the upstream resources exist or are derived in locals.

## How the Bootstrap Flow Is Supposed to Work

The intended lifecycle is two-phase.

### Phase 1: user-credential bootstrap

Initially, the org automation service accounts and state buckets do not exist yet. So the first apply must run with a user principal that has enough org-level and billing permissions.

Typical first-run flow:

1. Authenticate as an org admin.
2. Point stage 0 at your chosen defaults file and dataset.
3. Run `terraform init`.
4. Run `terraform apply`.
5. Let stage 0 create:
   - `iac-0`
   - `log-0`
   - `billing-0`
   - stage service accounts
   - state and outputs buckets

### Phase 2: service-account-driven steady state

After the first apply, stage 0 generates provider files and tfvars output artifacts through `output-files.tf`.

Those generated provider files point Terraform at:

- the GCS backend bucket
- the correct impersonated service account

After that, the normal steady-state flow is:

1. copy or link the generated provider file into the stage directory
2. migrate local state to the remote backend
3. rerun `terraform init -migrate-state`
4. run `terraform plan` and `terraform apply` using impersonation

That is the intended FAST operating model.

## Provider Files, State Buckets, and Outputs

Stage 0 generates downstream execution artifacts in `output-files.tf`.

It can write them to:

- a local filesystem path
- a GCS outputs bucket
- or both

The generated artifacts are:

- provider files
- stage tfvars JSON files
- version files

For stage 0 specifically, the provider files typically include:

- backend bucket
- optional prefix
- impersonated service account

In your Bernal config, the important buckets are:

- `brnllab-prod-iac-core-0-iac-org-state`
- `brnllab-prod-iac-core-0-iac-stage-state`
- `brnllab-prod-iac-core-0-iac-outputs`

The intended responsibility split is:

- `iac-org-state`
  - state for stage 0
- `iac-stage-state`
  - state for later stages
- `iac-outputs`
  - generated provider/tfvars/version artifacts

## How Stage 1 Uses the Bootstrap

Stage 1 lives in:

- `fast/stages/1-vpcsc`

Stage 1 does not bootstrap the org. It assumes stage 0 has already done the following:

- created the automation service accounts
- created the stage state bucket
- exported the provider file
- exported stage-0-derived tfvars
- established the core projects and logging identities

From Terraform's point of view, stage 1 consumes the contract emitted by stage 0. That contract usually includes:

- project numbers
- project ids
- storage bucket names
- logging sink identities
- IAM principals

That is why stage 0 is the real bootstrap stage and stage 1 is a consumer stage.

## How to Configure Stage 0 for a Real Environment

There are three main layers you customize.

### Layer 1: environment defaults

Edit:

- `fast-config/<environment>/defaults.yaml`

This is where you set:

- organization id
- billing account
- prefix
- primary locations
- admin groups
- output path/bucket preferences

This file controls naming conventions and stage contracts across the whole bootstrap.

### Layer 2: dataset selection

Use `factories_config` in a stage tfvars file to select which dataset to use.

Example:

```hcl
factories_config = {
  dataset = "datasets/classic"
  paths = {
    defaults = "/absolute/path/to/fast-config/bernal-live/defaults.yaml"
  }
}
```

Use this when you want to:

- keep the stock classic dataset
- override only defaults
- gradually evolve a custom landing zone

### Layer 3: dataset contents

Edit the YAML under the dataset when you want to change what the bootstrap actually provisions.

The key places are:

- `datasets/classic/organization/.config.yaml`
- `datasets/classic/organization/custom-roles/*`
- `datasets/classic/organization/org-policies/*`
- `datasets/classic/organization/tags/*`
- `datasets/classic/folders/**/.config.yaml`
- `datasets/classic/projects/core/*.yaml`

Use this layer when you need to change:

- org IAM model
- preventive controls
- folder hierarchy
- core project shape
- logging behavior
- stage automation resources

## Customizing Core Bootstrap Projects

There are two different project customization problems:

1. customizing bootstrap or foundation projects
2. adding your own business or workload projects

Do not treat them as the same thing.

### Foundation projects belong in stage 0

The projects in:

- `datasets/classic/projects/core`

are foundation projects. You customize these in stage 0 if you need to change:

- which APIs are enabled in `iac-0`
- state or outputs bucket behavior
- log bucket behavior in `log-0`
- billing export shape in `billing-0`
- stage automation service accounts

Examples of valid stage-0 customizations:

- add more organization automation service accounts
- change the log bucket retention
- add more managed folders under `iac-stage-state`
- add more IAM for CI/CD service accounts
- add extra services to `iac-0`

### Custom workload or team projects usually do not belong in stage 0

If you want app, tenant, team, or environment projects, the usual FAST pattern is:

- keep stage 0 limited to foundation
- create workload projects in `2-project-factory`

That separation is important because:

- stage 0 is org bootstrap and control plane
- stage 2 project factory is the scalable project creation layer

## How to Add Custom Projects Correctly

There are two supported patterns.

### Pattern A: add more foundational projects in stage 0

Use this only for projects that are part of the landing-zone control plane.

Examples:

- extra audit project
- dedicated org automation project
- central DNS or identity project
- special shared service project tightly coupled to org bootstrap

To do this:

1. add a YAML file under the dataset project tree, usually near `projects/core`
2. define:
   - project name
   - services
   - IAM
   - optional service accounts
   - optional buckets
   - optional log buckets or automation resources
3. reference the project using context keys where needed

Minimal example:

```yaml
name: prod-shared-dns-0
services:
  - dns.googleapis.com
iam_by_principals:
  $iam_principals:service_accounts/iac-0/iac-networking-rw:
    - roles/owner
```

This approach is acceptable when the project is part of the platform foundation.

### Pattern B: add custom workload or team projects in stage 2 project factory

This is the preferred pattern for most custom projects.

Use stage:

- `fast/stages/2-project-factory`

This stage is explicitly built for:

- folder hierarchies for teams or BUs
- many projects
- shared defaults and overrides
- automation resources per project
- optional VPC-SC, KMS, and Shared VPC integration

This is the better option when you want:

- app projects
- dev/prod projects per team
- application service accounts and buckets
- repeatable onboarding of new teams

## Recommended Decision Rule

Use stage 0 if the project is part of the landing-zone control plane.

Use stage 2 project factory if the project is part of the landing-zone payload.

That one rule prevents most design mistakes.

## Example: Adding a Custom Bootstrap Project

Example file:

- `fast/stages/0-org-setup/datasets/classic/projects/core/dns-0.yaml`

Example:

```yaml
name: prod-shared-dns-0
services:
  - dns.googleapis.com
  - logging.googleapis.com
iam_by_principals:
  $iam_principals:service_accounts/iac-0/iac-networking-rw:
    - roles/owner
  $iam_principals:service_accounts/iac-0/iac-networking-ro:
    - roles/viewer
```

If this project should be referenced elsewhere, it becomes available through generated context such as:

- `$project_ids:dns-0`

after the factory processes it.

## Example: Adding Custom Team Projects in Project Factory

If you want application projects, use stage 2.

Typical approach:

1. keep `Teams` folder from stage 0
2. use `2-project-factory` to create `team-a`, `team-b`, and their env folders/projects
3. define project YAML files under the project-factory data tree

Illustrative project YAML:

```yaml
parent: $folder_ids:teams/team-a/dev
billing_account: 012345-67890A-BCDEF0
services:
  - compute.googleapis.com
  - secretmanager.googleapis.com
labels:
  team: team-a
  env: dev
service_accounts:
  app: {}
buckets:
  data: {}
automation:
  project: $project_ids:iac-0
  service_accounts:
    rw: {}
    ro: {}
```

This is the scalable pattern for custom projects.

## Bootstrap State Management and Why It Matters

Stage 0 is safe only when the backend state actually tracks the live resources.

The expected steady-state console workflow is:

```bash
cd fast/stages/0-org-setup

terraform init -reconfigure
terraform state list
terraform plan
```

Interpretation:

- if `state list` is populated and plan is mostly empty, bootstrap is healthy
- if `state list` is empty and plan wants to add hundreds of resources, the landing zone may exist live but the backend state is missing

That second case is dangerous because an `apply` can collide with already-existing resources.

## Brownfield Considerations

For existing organizations, stage 0 supports brownfield onboarding, but it is not zero-effort.

Typical bootstrap issues are:

- existing org policies
- existing organization IAM
- existing folders and projects
- existing tags
- missing state migration

The current code already supports org policy imports through:

- `org_policies_imports`

But that only solves one part of brownfield onboarding. If resources already exist and state is missing, the real recovery path is:

1. recover the original state if possible
2. otherwise import live resources into the correct backend
3. only then trust the normal `plan/apply` cycle

## Recommended Terraform Execution Flow

For a fresh bootstrap:

```bash
cd fast/stages/0-org-setup

export CLOUDSDK_CONFIG=/tmp/gcloud-cff
export GOOGLE_APPLICATION_CREDENTIALS=/tmp/gcloud-cff/application_default_credentials.json

terraform init
terraform apply
```

After the first successful bootstrap, switch to the generated provider file and remote backend model:

```bash
terraform init -migrate-state
terraform plan
terraform apply
```

For later stages, use the provider and tfvars outputs generated by stage 0.

## Practical Recommendations

- Keep stage 0 focused on org bootstrap and foundation projects.
- Do not put app onboarding logic into stage 0 unless the project is truly foundational.
- Use one environment-specific defaults file per tenant or landing zone.
- Treat generated provider files and tfvars as part of the runtime contract between stages.
- Verify state health before every apply on stage 0.
- Prefer stage 2 project factory for custom projects.

## Suggested Repo Documentation Structure

If you want to extend this further, the clean structure would be:

- one guide for bootstrap operations
- one guide for project customization patterns
- one guide for brownfield imports and state recovery
- one guide per environment config, such as `bernal-live`

This file is the operator-level overview. The next logical document would be a dedicated "custom projects cookbook" with ready-to-use YAML patterns.
