# TrueNAS Tunable Validation Script

This script validates all performance tunables against a TrueNAS SCALE instance by creating, verifying, and deleting each tunable one at a time.

## Prerequisites

- Python 3.13+ with `requests` library
- TrueNAS SCALE instance at 10.0.2.10 (configurable in script)
- Valid API key set as environment variable `TRUENAS_API_KEY`

## Installation

```bash
# Install required dependencies
pip3 install --break-system-packages requests

# Make script executable
chmod +x validate_tunables.py
```

## Usage

```bash
# Run the full validation (tests all 77 tunables)
python3 validate_tunables.py

# Or if executable:
./validate_tunables.py
```

## What it Tests

The script validates **77 performance tunables** in two categories:

### SYSCTL Tunables (42 total)
- **VM/Memory**: swappiness, cache pressure, dirty ratios, memory limits
- **Network**: TCP parameters, buffer sizes, congestion control, port ranges
- **Filesystem**: file handles, async I/O, inotify limits
- **Kernel**: shared memory, semaphores, ARP cache settings

### ZFS Module Parameters (35 total)
- **ARC Management**: min/max sizes, metadata limits, system reserves
- **I/O Tuning**: async/sync operation limits, aggregation settings
- **Advanced**: resilver settings, deadman timers, multihost parameters

## Process for Each Tunable

1. **Create** the tunable via TrueNAS API
2. **Wait** for full application (3s for SYSCTL, 15s for ZFS)
3. **Verify** the tunable was created successfully
4. **Delete** the tunable to clean up
5. **Record** results (valid/invalid with reasons)

## Output

- Real-time progress with color-coded status messages
- Final summary with success/failure counts
- Detailed results saved to `tunable_validation_results.json`
- Exit code 0 if all pass, 1 if any failures

## Sample Output

```
🔧 TrueNAS Tunable Validation Script
📡 Testing against: 10.0.2.10
🔑 API Key: ****abcd
================================================================================
📊 Total tunables to test: 77
   - SYSCTL tunables: 42
   - ZFS tunables: 35

[ 1/77] Testing: vm.swappiness
         Type: SYSCTL, Value: 1
✅ Created with ID: 7166
⏳ Waiting 3 seconds for SYSCTL tunable to apply...
✅ Verified: Tunable exists and is active
🗑️  Deleted successfully

...

================================================================================
📈 VALIDATION RESULTS
================================================================================
✅ Valid tunables: 75/77
❌ Invalid tunables: 2/77

✅ VALID TUNABLES (75):
   • vm.swappiness (SYSCTL)
   • vm.vfs_cache_pressure (SYSCTL)
   ...

❌ INVALID TUNABLES (2):
   • some.invalid.param (SYSCTL): Create failed: HTTP 400: Invalid parameter
   ...

📁 Results saved to: tunable_validation_results.json
```

## Results File Format

```json
{
  "total_tested": 77,
  "valid_count": 75,
  "invalid_count": 2,
  "valid_tunables": [
    {"name": "vm.swappiness", "type": "SYSCTL", "value": "1"},
    ...
  ],
  "invalid_tunables": [
    {"name": "some.param", "type": "SYSCTL", "value": "123", "reason": "Create failed: ..."},
    ...
  ]
}
```

## Performance Notes

- **Total Runtime**: ~20-30 minutes for all 77 tunables
  - SYSCTL tunables: ~3-5 seconds each
  - ZFS tunables: ~15-20 seconds each (longer due to module reload time)

- **Resource Impact**: Minimal - only one tunable exists at a time
- **Safety**: All tunables are immediately deleted after validation

## Troubleshooting

- **Connection errors**: Verify TrueNAS API endpoint and network connectivity
- **Authentication errors**: Check TRUENAS_API_KEY environment variable
- **Permission errors**: Ensure API key has admin privileges for tunable management
- **Timeout errors**: TrueNAS may be under load - script includes appropriate wait times