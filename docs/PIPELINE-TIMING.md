# Pipeline Timing Breakdown

## End-to-End Pipeline Duration

**Total Estimated Time: 25-45 minutes** (depending on AWS service speeds and network conditions)

## Detailed Breakdown by Job

### Job 1: Validate (Template Validation)
**Duration: ~1-2 minutes**

| Step | Estimated Time |
|------|----------------|
| Checkout code | ~10 seconds |
| Setup Packer | ~5 seconds |
| Configure AWS Credentials (OIDC) | ~2 seconds |
| Install Ansible | ~30 seconds |
| Initialize Packer plugins | ~10 seconds |
| Validate Packer template | ~5 seconds |
| **Total** | **~1-2 minutes** |

**Notes:**
- Fastest job in the pipeline
- Only validates syntax, doesn't build anything
- Runs in parallel with no dependencies

---

### Job 2: Build (AMI Creation)
**Duration: ~12-20 minutes** (depends on package updates and AMI size)

| Step | Estimated Time |
|------|----------------|
| Checkout code | ~10 seconds |
| Setup Packer | ~5 seconds |
| Configure AWS Credentials | ~2 seconds |
| Install Ansible | ~30 seconds |
| Initialize Packer plugins | ~10 seconds |
| **Packer Build Process:** | |
| - Launch EC2 instance | ~30 seconds |
| - Wait for SSH availability | ~1-2 minutes |
| - System package updates | ~3-5 minutes |
| - Install common packages | ~1-2 minutes |
| - Install AWS CLI v2 | ~1 minute |
| - Configure SSH | ~30 seconds |
| - Install Ansible on instance | ~1 minute |
| - CIS Hardening (Ansible playbook) | ~2-4 minutes |
| - CIS Compliance Check | ~1-2 minutes |
| - Cleanup temporary files | ~30 seconds |
| - Create AMI snapshot | ~2-5 minutes |
| - Register AMI | ~30 seconds |
| Extract AMI ID | ~5 seconds |
| Upload build logs | ~10 seconds |
| **Total** | **~12-20 minutes** |

**Variable Factors:**
- Package update speed (depends on Ubuntu mirrors)
- AMI size (larger AMIs = longer snapshot time)
- Network speed (package downloads)
- AWS service response times

---

### Job 3: Validate-AMI (Post-Build Validation)
**Duration: ~8-15 minutes** (depends on AMI availability and SSH readiness)

| Step | Estimated Time |
|------|----------------|
| Checkout code | ~10 seconds |
| Configure AWS Credentials | ~2 seconds |
| Install Ansible | ~30 seconds |
| Install AWS CLI | ~30 seconds |
| Wait for AMI to be available | ~0-2 minutes (if AMI still initializing) |
| Create security group | ~5 seconds |
| Launch test instance | ~30 seconds |
| Wait for instance running | ~30 seconds |
| Get instance IP address | ~10 seconds |
| Wait for SSH to be available | ~2-5 minutes |
| Setup SSH key for Ansible | ~10 seconds |
| Run validation playbook | ~2-4 minutes |
| Cleanup - Terminate instance | ~1-2 minutes |
| Cleanup - Delete security group | ~5 seconds |
| **Total** | **~8-15 minutes** |

**Variable Factors:**
- AMI availability (may need to wait if snapshot still completing)
- Instance boot time
- SSH readiness (depends on cloud-init)
- Validation test execution time

---

### Job 4: Copy-AMI (Multi-Region Distribution)
**Duration: ~5-20 minutes** (depends on number of regions and AMI size)

| Step | Estimated Time |
|------|----------------|
| Checkout code | ~10 seconds |
| Configure AWS Credentials | ~2 seconds |
| Install AWS CLI and jq | ~30 seconds |
| Parse target regions | ~5 seconds |
| Copy AMI to target regions (parallel) | ~1-2 minutes (initiation) |
| Wait for copied AMIs to be available | ~5-15 minutes per region (parallel, so max time) |
| Store AMI IDs in Parameter Store | ~10 seconds per region |
| **Total** | **~5-20 minutes** |

**Variable Factors:**
- Number of target regions (default: 2 regions)
- AMI size (larger AMIs = longer copy time)
- Network speed between regions
- AWS service response times

**Copy Time by AMI Size:**
- Small AMI (~10GB): ~5-8 minutes per region
- Medium AMI (~20GB): ~8-12 minutes per region
- Large AMI (~50GB): ~12-20 minutes per region

---

## Pipeline Flow (Sequential)

```
┌─────────────────────────────────────────┐
│ Job 1: Validate                        │
│ Duration: ~1-2 minutes                 │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ Job 2: Build                           │
│ Duration: ~12-20 minutes                │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ Job 3: Validate-AMI                     │
│ Duration: ~8-15 minutes                 │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ Job 4: Copy-AMI                        │
│ Duration: ~5-20 minutes                 │
└─────────────────────────────────────────┘
```

**Total Sequential Time: ~26-57 minutes**

## Optimizations & Parallel Execution

### Current Parallelization

1. **Copy-AMI Job**: Copies to multiple regions in parallel
   - All regions start copying simultaneously
   - Wait time = longest region (not sum of all regions)

2. **GitHub Actions**: Jobs run sequentially (by design)
   - Each job waits for previous job to complete
   - No parallel job execution

### Potential Optimizations

1. **Skip Validation**: If you trust the build, skip `validate-ami` job
   - Saves: ~8-15 minutes
   - New total: ~18-42 minutes

2. **Reduce Target Regions**: Copy to fewer regions
   - Saves: ~5-10 minutes per region removed
   - Example: 1 region instead of 2 = ~5-10 minutes saved

3. **Conditional Copy**: Only copy on specific conditions
   - Saves: ~5-20 minutes when skipped
   - Use case: Copy only on releases/tags

## Real-World Scenarios

### Scenario 1: Fast Build (Best Case)
- Fast package updates
- Small AMI (~10GB)
- 2 target regions
- **Total: ~25-30 minutes**

### Scenario 2: Typical Build (Average Case)
- Normal package updates
- Medium AMI (~20GB)
- 2 target regions
- **Total: ~35-40 minutes**

### Scenario 3: Slow Build (Worst Case)
- Slow package updates
- Large AMI (~50GB)
- Multiple target regions (3+)
- **Total: ~45-60 minutes**

## Monitoring Pipeline Duration

### GitHub Actions UI
- View job durations in Actions tab
- Each job shows individual step times
- Total workflow time displayed at top

### Key Metrics to Monitor
- **Build Job**: Usually longest (~12-20 min)
- **Copy-AMI Job**: Can be long if many regions (~5-20 min)
- **Validate-AMI Job**: Moderate (~8-15 min)
- **Validate Job**: Fastest (~1-2 min)

## Factors Affecting Duration

### AWS Service Factors
- EC2 instance launch speed
- EBS snapshot creation speed
- AMI copy speed (depends on data transfer)
- Network latency between regions

### Build Factors
- Package update speed (Ubuntu mirrors)
- Number of packages installed
- CIS hardening complexity
- Ansible playbook execution time

### External Factors
- GitHub Actions runner availability
- Network connectivity
- AWS service health
- Concurrent AWS API rate limits

## Recommendations

1. **Monitor First Few Builds**: Track actual times to establish baseline
2. **Set Realistic Expectations**: Plan for ~30-40 minutes average
3. **Optimize Based on Needs**: Remove unnecessary steps if speed is critical
4. **Use Notifications**: Set up alerts for build completion
5. **Consider Scheduled Builds**: Build during off-peak hours if possible

## Cost vs. Time Trade-offs

| Option | Time Saved | Cost Impact |
|--------|------------|-------------|
| Skip validation | ~8-15 min | No cost savings |
| Reduce regions | ~5-10 min/region | Lower data transfer costs |
| Build smaller AMI | ~2-5 min | Lower storage costs |
| Skip Parameter Store | ~10 sec | No cost savings |

