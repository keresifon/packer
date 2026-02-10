# GitHub OIDC Manual Setup

Create the OIDC identity provider and IAM role manually so GitHub Actions can authenticate to AWS without long-lived credentials.

**Do this before the pipeline runs** — the pipeline uses this role for auth.

---

## 1. Create OIDC Identity Provider

### AWS Console

1. Go to **IAM** → **Identity providers** → **Add provider**
2. **Provider type**: OpenID Connect
3. **Provider URL**: `https://token.actions.githubusercontent.com`
4. **Audience**: `sts.amazonaws.com`
5. Click **Add provider**

### AWS CLI

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

---

## 2. Create IAM Role

See `trust-policy.json` (replace ACCOUNT_ID and repository).

### Create the Role

```bash
aws iam create-role \
  --role-name packer-vpc-ssm-github-actions-role \
  --assume-role-policy-document file://trust-policy.json
```

---

## 3. Attach Terraform Policy

```bash
# Replace ROLE_NAME with your actual role (e.g. GithubActions or packer-vpc-ssm-github-actions-role)
aws iam put-role-policy \
  --role-name ROLE_NAME \
  --policy-name github-actions-terraform \
  --policy-document file://terraform-policy.json
```

**If you get `iam:ListRolePolicies` AccessDenied:** Update the policy on your OIDC role. The `terraform-policy.json` in this folder includes it. Use your role name (from the error, e.g. `GithubActions`):
```bash
cd oidc
aws iam put-role-policy --role-name GithubActions --policy-name github-actions-terraform --policy-document file://terraform-policy.json
```

---

## 4. GitHub Repository Variable

1. Get the role ARN: `aws iam get-role --role-name packer-vpc-ssm-github-actions-role --query 'Role.Arn' --output text`
2. In GitHub: **Settings** → **Secrets and variables** → **Actions** → **Variables**
3. Add `AWS_ROLE_ARN` with the role ARN
