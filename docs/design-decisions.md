# Design decisions: AWS Secure Landing Zone

Each record: what was chosen, what else was considered, and why.

### 1. GitHub OIDC instead of access keys in CI
- **Alternatives:** IAM user access keys as GitHub secrets; self-hosted runner with an instance role.
- **Why:** keys leak and never expire; OIDC tokens are short-lived and scoped by the `sub` claim to one repo and branch. No secret to rotate.
- **Trade-off:** trust policy conditions must be exact; a loose `sub` (for example `repo:owner/*`) would let any repo deploy.

### 2. Permissions boundary on the CI role
- **Alternatives:** rely on the role policy alone; SCPs (need Organizations).
- **Why:** the boundary is a ceiling the role policy cannot exceed. It explicitly denies creating IAM users or keys and stopping CloudTrail or GuardDuty, so a compromised workflow cannot erase its tracks.
- **Trade-off:** `iam:CreateRole` is still allowed (needed for Config and flow-log roles); in production require the boundary on any role CI creates.

### 3. Remote state in S3 with DynamoDB locking and KMS
- **Alternatives:** local state; Terraform Cloud.
- **Why:** shared, versioned, encrypted, and the lock prevents two applies corrupting state. State holds sensitive values, so TLS-only bucket policy and KMS.
- **Note:** newer Terraform supports S3-native locking (`use_lockfile`); DynamoDB is still the widely understood pattern.

### 4. Private-only VPC, no NAT gateway
- **Alternatives:** public and private subnets with a NAT gateway per AZ.
- **Why:** a NAT gateway costs about $32 a month per AZ plus data. Workloads reach AWS APIs through VPC endpoints instead. S3 gateway endpoint is free; interface endpoints are optional.
- **Trade-off:** no general internet egress; workloads needing it would need a NAT or a proxy.

### 5. Multi-region CloudTrail with log file validation, KMS and CloudWatch delivery
- **Why:** attackers often act in regions you do not use. Validation creates signed digest files so you can prove logs were not tampered with. CloudWatch delivery enables metric-filter alarms (root usage).

### 6. Security Hub with FSBP, CIS 3.0 and NIST 800-53 standards
- **Why:** FSBP is AWS's own baseline, CIS is what auditors know, NIST 800-53 maps to 800-171 and CMMC. Default standards turned off so the choice is explicit in code.

### 7. AWS Config recorder plus eight managed rules
- **Why:** Config records configuration history (who changed what, when) and evaluates rules continuously. Managed rules avoid writing Lambda rules for common checks.
- **Trade-off:** Config charges per recorded item; recording all resources is fine for a lab, scope it in production.

### 8. Checkov and TFLint as pull-request gates, results as SARIF
- **Why:** shift-left: problems found in minutes on the pull request instead of in an audit. SARIF puts findings in GitHub's Security tab.
- **Skips are documented** inline and in `checkov-exceptions.md`; a silent skip is a finding, a written one is a decision.

### 9. Approval-gated apply through a GitHub environment
- **Why:** separation of duties: the plan is reviewed on the PR, and a human approves the apply. Concurrency group prevents two applies at once.

### 10. Modules per concern (network, logging, security, budget)
- **Why:** each module has one job and clear inputs/outputs, so it can be reused in another environment (`envs/prod`) without copying code.
