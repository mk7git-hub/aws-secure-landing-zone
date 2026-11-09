# Checkov exceptions

Each skip is a decision, not a silence. Reviewed when the repo moves past lab use.

| Check | Where | Why |
| --- | --- | --- |
| CKV_AWS_62/63/286-290/355, CKV2_AWS_40 | CI permissions boundary | A boundary is a ceiling. `Allow *` grants nothing alone; the explicit `Deny` list is the control. |
| CKV_AWS_109/111/356 | KMS key policies | Standard AWS root statement that delegates to IAM; service statements are scoped by condition. |
| CKV_AWS_252 | CloudTrail | Alerting uses metric filters and EventBridge instead of per-log-file SNS. |
| CKV_AWS_394 | AZ data source | Only the first two zones are used, so new zones do not change the result. |
| CKV2_AWS_3 | GuardDuty | Single account; org-wide delegation is on the roadmap. |
| CKV_AWS_144 | Audit bucket | Cross-region replication doubles cost for a lab. |
| CKV_AWS_18 | Audit bucket | Access logging on the log bucket would recurse. |
| CKV2_AWS_62 | Audit bucket | Event notifications not needed. |
| CKV_AWS_28, CKV_AWS_119 | Lock table | PITR on; the table only holds lock IDs and uses the state CMK. |
| CKV_GHA_7 | destroy workflow | Typed confirmation input is intentional. |
