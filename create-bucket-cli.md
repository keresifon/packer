# Create Bucket via HCP CLI

If you prefer to create the bucket manually before building:

## Install HCP CLI

```bash
# Windows (PowerShell)
winget install HashiCorp.HCP

# Or download from: https://github.com/hashicorp/hcp-cli/releases
```

## Authenticate

```bash
hcp auth login
```

## Create the Bucket

```bash
hcp packer buckets create ubuntu-golden-image \
  --description "Ubuntu Golden Image for AWS" \
  --labels os=ubuntu,managed-by=packer
```

## Verify

```bash
hcp packer buckets list
```

You should see `ubuntu-golden-image` in the list.

