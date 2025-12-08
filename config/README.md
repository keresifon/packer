# Configuration Files

This directory contains configuration files for the Packer build pipeline.

## build-config.yml

Main configuration file for the Packer build pipeline, including build settings, instance configuration, CIS settings, tags, and AMI distribution regions.

### AMI Distribution Configuration

Target regions for AMI distribution are configured in the `distribution` section of `build-config.yml`.

### Structure

```yaml
distribution:
  target_regions:
    - us-west-2      # US West (Oregon)
    - eu-west-1      # EU (Ireland)
    - ap-southeast-1 # Asia Pacific (Singapore)
```

### Usage

List regions directly in the `distribution.target_regions` array. All listed regions will be used for copying.

### Priority

1. **Workflow Input** (Manual Trigger): If `target_regions` input is provided, it overrides the config file
2. **Config File**: Reads from `config/build-config.yml` → `distribution.target_regions` (required)

**Note**: The config file is required. If `config/build-config.yml` is missing or the `distribution.target_regions` section is empty, the copy job will be skipped. There are no default regions.

### Examples

**Add a new region:**
```yaml
distribution:
  target_regions:
    - us-west-2
    - eu-west-1
    - ap-southeast-1  # Add this
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

