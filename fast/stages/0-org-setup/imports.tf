/**
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import {
  for_each = toset(local.organization.id != null ? var.org_policies_imports : [])
  id       = "organizations/${local.organization_id}/policies/${each.key}"
  to       = module.organization-iam[0].google_org_policy_policy.default[each.key]
}

import {
  id = "organizations/874229980578/roles/networkFirewallPoliciesAdmin"
  to = module.organization[0].google_organization_iam_custom_role.roles["network_firewall_policies_admin"]
}

import {
  id = "organizations/874229980578/roles/ngfwEnterpriseAdmin"
  to = module.organization[0].google_organization_iam_custom_role.roles["ngfw_enterprise_admin"]
}

import {
  id = "organizations/874229980578/roles/ngfwEnterpriseViewer"
  to = module.organization[0].google_organization_iam_custom_role.roles["ngfw_enterprise_viewer"]
}

import {
  id = "organizations/874229980578/roles/organizationAdminViewer"
  to = module.organization[0].google_organization_iam_custom_role.roles["organization_admin_viewer"]
}

import {
  id = "organizations/874229980578/roles/organizationIamAdmin"
  to = module.organization[0].google_organization_iam_custom_role.roles["organization_iam_admin"]
}

import {
  id = "organizations/874229980578/roles/projectIamViewer"
  to = module.organization[0].google_organization_iam_custom_role.roles["project_iam_viewer"]
}

import {
  id = "organizations/874229980578/roles/serviceProjectNetworkAdmin"
  to = module.organization[0].google_organization_iam_custom_role.roles["service_project_network_admin"]
}

import {
  id = "organizations/874229980578/roles/storageViewer"
  to = module.organization[0].google_organization_iam_custom_role.roles["storage_viewer"]
}

import {
  id = "organizations/874229980578/roles/tagViewer"
  to = module.organization[0].google_organization_iam_custom_role.roles["tag_viewer"]
}

import {
  id = "tagKeys/281477545105228"
  to = module.organization[0].google_tags_tag_key.default["context"]
}

import {
  id = "tagKeys/281480595459819"
  to = module.organization[0].google_tags_tag_key.default["environment"]
}

import {
  id = "tagValues/281481580859492"
  to = module.organization[0].google_tags_tag_value.default["context/project-factory"]
}

import {
  id = "tagValues/281482604144007"
  to = module.organization[0].google_tags_tag_value.default["environment/development"]
}

import {
  id = "tagValues/281479846761528"
  to = module.organization[0].google_tags_tag_value.default["environment/production"]
}

import {
  id = "folders/366265975316"
  to = module.factory.module.folder-1["data-platform"].google_folder.folder[0]
}

import {
  id = "folders/909622850678"
  to = module.factory.module.folder-1["networking"].google_folder.folder[0]
}

import {
  id = "folders/1085644090166"
  to = module.factory.module.folder-1["security"].google_folder.folder[0]
}

import {
  id = "folders/1047687718374"
  to = module.factory.module.folder-1["teams"].google_folder.folder[0]
}

import {
  id = "organizations/874229980578/customConstraints/custom.denyBridgePerimeters"
  to = module.organization-iam[0].google_org_policy_custom_constraint.constraint["custom.denyBridgePerimeters"]
}

import {
  id = "organizations/874229980578/policies/storage.uniformBucketLevelAccess"
  to = module.organization-iam[0].google_org_policy_policy.default["storage.uniformBucketLevelAccess"]
}

import {
  id = "organizations/874229980578/policies/iam.allowedPolicyMemberDomains"
  to = module.organization-iam[0].google_org_policy_policy.default["iam.allowedPolicyMemberDomains"]
}

import {
  id = "organizations/874229980578/policies/iam.disableServiceAccountKeyCreation"
  to = module.organization-iam[0].google_org_policy_policy.default["iam.disableServiceAccountKeyCreation"]
}

import {
  id = "organizations/874229980578/policies/compute.restrictProtocolForwardingCreationForTypes"
  to = module.organization-iam[0].google_org_policy_policy.default["compute.restrictProtocolForwardingCreationForTypes"]
}

import {
  id = "organizations/874229980578/policies/iam.disableServiceAccountKeyUpload"
  to = module.organization-iam[0].google_org_policy_policy.default["iam.disableServiceAccountKeyUpload"]
}

import {
  id = "organizations/874229980578/policies/compute.setNewProjectDefaultToZonalDNSOnly"
  to = module.organization-iam[0].google_org_policy_policy.default["compute.setNewProjectDefaultToZonalDNSOnly"]
}

import {
  id = "organizations/874229980578/policies/essentialcontacts.allowedContactDomains"
  to = module.organization-iam[0].google_org_policy_policy.default["essentialcontacts.allowedContactDomains"]
}

import {
  id = "organizations/874229980578/policies/iam.automaticIamGrantsForDefaultServiceAccounts"
  to = module.organization-iam[0].google_org_policy_policy.default["iam.automaticIamGrantsForDefaultServiceAccounts"]
}
