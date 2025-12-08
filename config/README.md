# Configuration Files

This directory contains configuration files for the Packer build pipeline.

## regions.yml

Configuration file for target AWS regions where AMIs will be copied after successful build.

### Structure

```yaml
target_regions:
  - us-west-2      # US West (Oregon)
  - eu-west-1      # EU (Ireland)

region_settings:
  us-west-2:
    enabled: true
    description: "US West (Oregon)"
  eu-west-1:
    enabled: true
    description: "EU (Ireland)"
  ap-southeast-1:
    enabled: false
    description: "Asia Pacific (Singapore)"
```

### Usage

**Option 1: Use `target_regions` list (Simple)**
- List regions directly in the `target_regions` array
- All listed regions will be used for copying

**Option 2: Use `region_settings` (Advanced)**
- Define regions with `enabled: true/false` flags
- Only regions with `enabled: true` will be copied
- Useful for temporarily disabling regions without removing them

### Priority

1. **Workflow Input** (Manual Trigger): If `target_regions` input is provided, it overrides the config file
2. **Config File**: Reads from `config/regions.yml` (required)

**Note**: The config file is required. If `config/regions.yml` is missing or empty, the copy job will be skipped. There are no default regions.

### Examples

**Add a new region:**
```yaml
target_regions:
  - us-west-2
  - eu-west-1
  - ap-southeast-1  # Add this
```

**Enable/disable regions:**
```yaml
region_settings:
  us-west-2:
    enabled: true   # Will be copied
  ap-southeast-1:
    enabled: false  # Will NOT be copied
```

### Supported AWS Regions

Common regions you might want to use:
- `us-east-1` - US East (N. Virginia)
- `us-east-2` - US East (Ohio)
- `us-west-1` - US West (N. California)
- `us-west-2` - US West (Oregon)
- `eu-west-1` - EU (Ireland)
- `eu-west-2` - EU (London)
- `eu-central-1` - EU (Frankfurt)
- `ap-southeast-1` - Asia Pacific (Singapore)
- `ap-southeast-2` - Asia Pacific (Sydney)
- `ap-northeast-1` - Asia Pacific (Tokyo)
- `ap-south-1` - Asia Pacific (Mumbai)
- `sa-east-1` - South America (São Paulo)
- `ca-central-1` - Canada (Central)

