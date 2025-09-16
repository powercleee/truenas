#!/usr/bin/env python3
"""
TrueNAS SCALE Tunable Validation Script
Tests all performance tunables by creating, verifying, and deleting them via API
Specifically designed to test one tunable at a time with proper wait times
"""

import requests
import json
import time
import sys
import os
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass

@dataclass
class Tunable:
    name: str
    type: str
    value: str
    description: str

class TrueNASAPI:
    def __init__(self, host: str, api_key: str):
        self.host = host
        self.base_url = f"http://{host}/api/v2.0"
        self.headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        self.session = requests.Session()
        self.session.headers.update(self.headers)

    def monitor_jobs(self, timeout_seconds: int = 30, debug: bool = False) -> bool:
        """Monitor running jobs until completion or timeout"""
        start_time = time.time()
        check_count = 0

        if debug:
            print(f"    🔍 Starting job monitoring (timeout: {timeout_seconds}s)")

        while time.time() - start_time < timeout_seconds:
            check_count += 1
            try:
                response = self.session.get(f"{self.base_url}/core/get_jobs", timeout=10)
                if debug:
                    print(f"    🔍 Job check #{check_count} - Status: {response.status_code}")

                if response.status_code == 200:
                    jobs = response.json()
                    if debug:
                        print(f"    🔍 Found {len(jobs)} total jobs")

                    # If no jobs are running, we're done
                    if not jobs or len(jobs) == 0:
                        if debug:
                            print(f"    🔍 No jobs found - monitoring complete")
                        return True

                    # Check if any jobs are still running
                    running_jobs = [job for job in jobs if job.get('state') in ['RUNNING', 'WAITING']]
                    if debug:
                        job_states = [job.get('state', 'UNKNOWN') for job in jobs]
                        print(f"    🔍 Job states: {job_states}")
                        print(f"    🔍 Running/waiting jobs: {len(running_jobs)}")

                    if not running_jobs:
                        if debug:
                            print(f"    🔍 No running jobs - monitoring complete")
                        return True

                    # Brief wait before checking again
                    time.sleep(0.5)
                else:
                    if debug:
                        print(f"    🔍 Job check failed with status {response.status_code} - falling back")
                    # If we can't check jobs, fall back to brief wait
                    time.sleep(2)
                    return True

            except Exception as e:
                if debug:
                    print(f"    🔍 Job monitoring exception: {e} - falling back")
                # If job monitoring fails, fall back to brief wait
                time.sleep(2)
                return True

        if debug:
            print(f"    🔍 Job monitoring timeout after {timeout_seconds}s")
        return False  # Timeout reached

    def create_tunable(self, tunable: Tunable) -> Tuple[bool, Optional[int], str]:
        """Create a tunable and return (success, tunable_id, message)"""
        data = {
            "var": tunable.name,
            "value": tunable.value,
            "type": tunable.type,
            "comment": tunable.description[:255],  # TrueNAS has comment length limits
            "enabled": True
        }

        try:
            response = self.session.post(
                f"{self.base_url}/tunable",
                json=data,
                timeout=60
            )

            if response.status_code == 200:
                result = response.json()
                creation_id = result.get("id") if isinstance(result, dict) else result

                # Monitor jobs to ensure creation completes
                print(f"⏳ Monitoring job completion for {tunable.type} tunable...")
                job_completed = self.monitor_jobs(timeout_seconds=30 if tunable.type == "ZFS" else 15, debug=True)
                if not job_completed:
                    print(f"⚠️  Job monitoring timeout, proceeding with verification...")

                # Find the actual tunable ID by searching for the tunable name
                verify_response = self.session.get(f"{self.base_url}/tunable", timeout=30)
                if verify_response.status_code == 200:
                    tunables = verify_response.json()
                    for t in tunables:
                        if t.get("var") == tunable.name:
                            actual_id = t.get("id")
                            return True, actual_id, f"Created successfully (actual ID: {actual_id})"

                # If we can't find it by name, return the creation ID as fallback
                return True, creation_id, f"Created successfully (creation ID: {creation_id})"
            else:
                try:
                    error_detail = response.json() if response.text else {}
                    error_text = error_detail.get('detail', response.text) if error_detail else response.text
                except:
                    error_text = response.text if response.text else "Unknown error"
                return False, None, f"HTTP {response.status_code}: {error_text}"

        except requests.RequestException as e:
            return False, None, f"Request error: {str(e)}"
        except Exception as e:
            return False, None, f"Unexpected error: {str(e)}"

    def get_tunable(self, tunable_id: int, tunable_name: str = None) -> Tuple[bool, str]:
        """Check if tunable exists and return (exists, message)"""
        try:
            # Method 1: Search through all tunables (most reliable)
            response = self.session.get(f"{self.base_url}/tunable", timeout=30)
            if response.status_code == 200:
                tunables = response.json()

                # First try to find by ID
                for tunable in tunables:
                    if tunable.get("id") == tunable_id:
                        enabled = tunable.get("enabled", False)
                        status = "active" if enabled else "disabled"
                        var_name = tunable.get("var", "unknown")
                        return True, f"Tunable '{var_name}' (ID: {tunable_id}) is {status}"

                # If ID search fails and we have a name, try searching by name
                if tunable_name:
                    for tunable in tunables:
                        if tunable.get("var") == tunable_name:
                            enabled = tunable.get("enabled", False)
                            status = "active" if enabled else "disabled"
                            found_id = tunable.get("id")
                            return True, f"Tunable '{tunable_name}' found with ID {found_id} and is {status}"

                return False, f"Tunable ID {tunable_id} not found in system (searched {len(tunables)} tunables)"
            else:
                return False, f"Cannot verify tunable: HTTP {response.status_code}"

        except Exception as e:
            return False, f"Error checking tunable: {str(e)}"

    def delete_tunable(self, tunable_id: int) -> Tuple[bool, str]:
        """Delete tunable and return (success, message)"""
        try:
            # Method 1: Standard REST DELETE
            response = self.session.delete(
                f"{self.base_url}/tunable/id/{tunable_id}",
                timeout=30
            )

            if response.status_code in [200, 204]:
                # Monitor any jobs that might be spawned
                self.monitor_jobs(timeout_seconds=10, debug=False)

                # Verify deletion by checking if tunable still exists
                verify_response = self.session.get(f"{self.base_url}/tunable", timeout=30)
                if verify_response.status_code == 200:
                    tunables = verify_response.json()
                    if not any(t.get("id") == tunable_id for t in tunables):
                        return True, "Deleted successfully"

            # Method 2: Try disabling the tunable instead of deleting
            disable_data = {"enabled": False}
            response = self.session.put(
                f"{self.base_url}/tunable/id/{tunable_id}",
                json=disable_data,
                timeout=30
            )

            if response.status_code == 200:
                self.monitor_jobs(timeout_seconds=10, debug=False)
                return True, "Disabled successfully"

            return False, f"Failed to delete tunable {tunable_id} (HTTP {response.status_code})"

        except Exception as e:
            return False, f"Delete error: {str(e)}"

def get_performance_tunables() -> List[Tunable]:
    """Return all performance tunables to test"""
    sysctl_tunables = [
        Tunable("vm.swappiness", "SYSCTL", "1", "Minimizes swap usage with 192GB RAM available"),
        Tunable("vm.vfs_cache_pressure", "SYSCTL", "50", "Balanced inode/dentry cache retention"),
        Tunable("vm.dirty_ratio", "SYSCTL", "10", "Percentage of system memory for dirty pages"),
        Tunable("vm.dirty_background_ratio", "SYSCTL", "5", "Start background writeback at 5% dirty memory"),
        Tunable("vm.dirty_expire_centisecs", "SYSCTL", "3000", "Dirty pages older than 30 seconds get written"),
        Tunable("vm.min_free_kbytes", "SYSCTL", "1048576", "Reserve 1GB minimum free memory"),
        Tunable("kernel.shmmax", "SYSCTL", "103079215104", "~96GB for shared memory segments"),
        Tunable("kernel.shmall", "SYSCTL", "25165824", "Total shared memory pages"),
        Tunable("kernel.sem", "SYSCTL", "250 32000 100 512", "Semaphore parameters for container IPC"),
        Tunable("net.core.rmem_max", "SYSCTL", "134217728", "128MB max receive buffer"),
        Tunable("net.core.wmem_max", "SYSCTL", "134217728", "128MB max send buffer"),
        Tunable("net.core.rmem_default", "SYSCTL", "33554432", "32MB default receive buffer"),
        Tunable("net.core.wmem_default", "SYSCTL", "33554432", "32MB default send buffer"),
        Tunable("net.core.netdev_max_backlog", "SYSCTL", "30000", "Increased packet backlog for 10GbE"),
        Tunable("net.core.somaxconn", "SYSCTL", "8192", "Maximum socket connection queue"),
        Tunable("net.ipv4.tcp_rmem", "SYSCTL", "4096 87380 134217728", "TCP receive buffer settings"),
        Tunable("net.ipv4.tcp_wmem", "SYSCTL", "4096 65536 134217728", "TCP send buffer settings"),
        Tunable("net.ipv4.tcp_congestion_control", "SYSCTL", "bbr", "Google's BBR congestion control"),
        Tunable("net.ipv4.tcp_mtu_probing", "SYSCTL", "1", "Enable MTU probing for jumbo frames"),
        Tunable("net.ipv4.tcp_timestamps", "SYSCTL", "1", "Required for window scaling and PAWS"),
        Tunable("net.ipv4.tcp_sack", "SYSCTL", "1", "Selective acknowledgments"),
        Tunable("net.ipv4.tcp_window_scaling", "SYSCTL", "1", "Enable RFC1323 window scaling"),
        Tunable("net.ipv4.tcp_no_metrics_save", "SYSCTL", "1", "Don't cache TCP metrics"),
        Tunable("net.ipv4.tcp_moderate_rcvbuf", "SYSCTL", "1", "Auto-tune receive buffers"),
        Tunable("net.ipv4.ip_local_port_range", "SYSCTL", "32768 65000", "Expanded ephemeral port range"),
        Tunable("net.ipv4.tcp_fin_timeout", "SYSCTL", "30", "Reduce TIME_WAIT duration"),
        Tunable("net.ipv4.tcp_keepalive_time", "SYSCTL", "600", "Start keepalive after 10 minutes"),
        Tunable("net.ipv4.tcp_keepalive_intvl", "SYSCTL", "30", "Keepalive probe interval"),
        Tunable("net.ipv4.tcp_keepalive_probes", "SYSCTL", "5", "Number of keepalive probes"),
        Tunable("net.ipv4.tcp_tw_reuse", "SYSCTL", "1", "Reuse TIME_WAIT sockets"),
        Tunable("net.ipv4.conf.all.rp_filter", "SYSCTL", "1", "Reverse path filtering for security"),
        Tunable("net.ipv4.conf.default.rp_filter", "SYSCTL", "1", "Default reverse path filtering"),
        Tunable("net.ipv4.neigh.default.gc_thresh1", "SYSCTL", "2048", "ARP cache minimum size"),
        Tunable("net.ipv4.neigh.default.gc_thresh2", "SYSCTL", "4096", "ARP cache soft maximum"),
        Tunable("net.ipv4.neigh.default.gc_thresh3", "SYSCTL", "8192", "ARP cache hard maximum"),
        Tunable("fs.file-max", "SYSCTL", "2097152", "Maximum file handles"),
        Tunable("fs.aio-max-nr", "SYSCTL", "1048576", "Maximum async I/O operations"),
        Tunable("fs.inotify.max_user_watches", "SYSCTL", "524288", "Inotify watches for containers"),
        Tunable("fs.inotify.max_user_instances", "SYSCTL", "8192", "Inotify instances for containers"),
        Tunable("net.core.netdev_budget", "SYSCTL", "600", "Packet processing budget per CPU"),
        Tunable("net.core.netdev_budget_usecs", "SYSCTL", "8000", "Maximum time for packet processing"),
        Tunable("net.ipv4.tcp_adv_win_scale", "SYSCTL", "2", "TCP receive buffer space for application"),
    ]

    zfs_tunables = [
        Tunable("zfs_arc_max", "ZFS", "164987617689", "~153GB (80% of RAM) ARC maximum"),
        Tunable("zfs_arc_min", "ZFS", "8589934592", "8GB minimum ARC size"),
        Tunable("zfs_arc_meta_limit", "ZFS", "82493808844", "~76GB metadata cache limit"),
        Tunable("zfs_arc_meta_min", "ZFS", "4294967296", "4GB minimum metadata cache"),
        Tunable("zfs_arc_dnode_limit", "ZFS", "16498761768", "~15GB dnode caching"),
        Tunable("zfs_arc_sys_free", "ZFS", "2147483648", "Keep 2GB RAM free"),
        Tunable("zfs_dirty_data_max", "ZFS", "8589934592", "8GB max dirty data"),
        Tunable("zfs_dirty_data_max_percent", "ZFS", "10", "10% of RAM can be dirty"),
        Tunable("zfs_txg_timeout", "ZFS", "5", "Transaction group timeout"),
        Tunable("zfs_vdev_async_read_max_active", "ZFS", "16", "Async read operations per vdev"),
        Tunable("zfs_vdev_async_write_max_active", "ZFS", "16", "Async write operations per vdev"),
        Tunable("zfs_vdev_sync_read_max_active", "ZFS", "16", "Sync read operations per vdev"),
        Tunable("zfs_vdev_sync_write_max_active", "ZFS", "16", "Sync write operations per vdev"),
        Tunable("zfs_vdev_scrub_max_active", "ZFS", "3", "Scrub I/O operations"),
        Tunable("zfs_vdev_async_write_min_active", "ZFS", "4", "Minimum async writes"),
        Tunable("zfs_vdev_aggregation_limit", "ZFS", "1048576", "1MB I/O aggregation"),
        Tunable("zfs_prefetch_disable", "ZFS", "0", "Enable prefetch"),
        Tunable("zfs_resilver_delay", "ZFS", "2", "Delay between resilver I/Os"),
        Tunable("zfs_resilver_min_time_ms", "ZFS", "3000", "Minimum resilver time per TXG"),
        Tunable("zfs_scan_idle", "ZFS", "50", "Milliseconds before scanner idle"),
        Tunable("zfs_top_maxinflight", "ZFS", "128", "Maximum outstanding I/O per vdev"),
        Tunable("zfs_deadman_synctime_ms", "ZFS", "120000", "120 second deadman timer"),
        Tunable("zfs_deadman_ziotime_ms", "ZFS", "300000", "300 second I/O timeout"),
        Tunable("zfs_vdev_cache_size", "ZFS", "0", "Disable vdev cache"),
        Tunable("l2arc_write_max", "ZFS", "134217728", "128MB/s L2ARC write speed"),
        Tunable("l2arc_headroom", "ZFS", "8", "L2ARC headroom multiplier"),
        Tunable("l2arc_noprefetch", "ZFS", "0", "Allow L2ARC prefetch"),
        Tunable("zfs_multihost_interval", "ZFS", "1000", "Multihost heartbeat interval"),
        Tunable("zfs_multihost_fail_intervals", "ZFS", "10", "Heartbeat failures before suspension"),
        Tunable("spa_asize_inflation", "ZFS", "24", "Metadata overhead accounting"),
        Tunable("zfs_admin_snapshot", "ZFS", "1", "Allow non-root snapshot admin"),
        Tunable("zfs_flags", "ZFS", "0", "Default ZFS module flags"),
        Tunable("zvol_request_sync", "ZFS", "0", "Async zvol requests"),
        Tunable("zvol_threads", "ZFS", "32", "Worker threads for zvol operations"),
        Tunable("zvol_max_discard_blocks", "ZFS", "16384", "Maximum blocks per discard"),
        Tunable("zfetch_max_distance", "ZFS", "67108864", "64MB max distance for prefetch"),
        Tunable("metaslab_lba_weighting_enabled", "ZFS", "1", "Enable LBA weighting"),
    ]

    return sysctl_tunables + zfs_tunables

def cleanup_existing_test_tunables(api: TrueNASAPI):
    """Clean up any existing test tunables before starting"""
    try:
        response = api.session.get(f"{api.base_url}/tunable")
        if response.status_code == 200:
            tunables = response.json()
            test_tunables = [t for t in tunables if 'test' in t.get('comment', '').lower()]

            if test_tunables:
                print(f"🧹 Found {len(test_tunables)} existing test tunables, cleaning up...")
                for tunable in test_tunables:
                    api.delete_tunable(tunable['id'])
                print("✅ Cleanup completed")
    except Exception as e:
        print(f"⚠️  Cleanup warning: {e}")

def main():
    # Check for API key
    api_key = os.getenv("TRUENAS_API_KEY")
    if not api_key:
        print("ERROR: TRUENAS_API_KEY environment variable not set")
        sys.exit(1)

    # Initialize API client
    truenas_host = "10.0.2.10"
    api = TrueNASAPI(truenas_host, api_key)

    print(f"🔧 TrueNAS Tunable Validation Script")
    print(f"📡 Testing against: {truenas_host}")
    print(f"🔑 API Key: {'*' * (len(api_key) - 4)}{api_key[-4:]}")
    print("=" * 80)

    # Clean up any existing test tunables
    cleanup_existing_test_tunables(api)

    # Get all tunables to test
    tunables = get_performance_tunables()
    total_tunables = len(tunables)

    print(f"📊 Total tunables to test: {total_tunables}")
    print(f"   - SYSCTL tunables: {len([t for t in tunables if t.type == 'SYSCTL'])}")
    print(f"   - ZFS tunables: {len([t for t in tunables if t.type == 'ZFS'])}")
    print()

    # Results tracking
    valid_tunables = []
    invalid_tunables = []

    for i, tunable in enumerate(tunables, 1):
        print(f"[{i:2d}/{total_tunables}] Testing: {tunable.name}")
        print(f"         Type: {tunable.type}, Value: {tunable.value}")

        # Step 1: Create tunable
        success, tunable_id, message = api.create_tunable(tunable)
        if not success:
            print(f"❌ FAILED to create: {message}")
            invalid_tunables.append((tunable, f"Create failed: {message}"))
            print()
            continue

        print(f"✅ {message}")

        # Step 2: Verify tunable exists
        exists, check_message = api.get_tunable(tunable_id, tunable.name)
        if not exists:
            print(f"⚠️  Warning: Tunable created but verification failed: {check_message}")
        else:
            print(f"✅ Verified: {check_message}")

        # Step 3: Delete tunable
        deleted, delete_message = api.delete_tunable(tunable_id)
        if deleted:
            print(f"🗑️  {delete_message}")
            valid_tunables.append(tunable)
        else:
            print(f"⚠️  Cleanup issue: {delete_message}")
            # Still consider the tunable valid since it was created successfully
            valid_tunables.append(tunable)

        print()

    # Final results
    print("=" * 80)
    print("📈 VALIDATION RESULTS")
    print("=" * 80)
    print(f"✅ Valid tunables: {len(valid_tunables)}/{total_tunables}")
    print(f"❌ Invalid tunables: {len(invalid_tunables)}/{total_tunables}")

    if valid_tunables:
        print(f"\n✅ VALID TUNABLES ({len(valid_tunables)}):")
        for tunable in valid_tunables:
            print(f"   • {tunable.name} ({tunable.type})")

    if invalid_tunables:
        print(f"\n❌ INVALID TUNABLES ({len(invalid_tunables)}):")
        for tunable, reason in invalid_tunables:
            print(f"   • {tunable.name} ({tunable.type}): {reason}")

    # Write results to file
    results = {
        "total_tested": total_tunables,
        "valid_count": len(valid_tunables),
        "invalid_count": len(invalid_tunables),
        "valid_tunables": [{"name": t.name, "type": t.type, "value": t.value} for t in valid_tunables],
        "invalid_tunables": [{"name": t.name, "type": t.type, "value": t.value, "reason": r} for t, r in invalid_tunables]
    }

    with open("tunable_validation_results.json", "w") as f:
        json.dump(results, f, indent=2)

    print(f"\n📁 Results saved to: tunable_validation_results.json")

    # Exit with appropriate code
    if invalid_tunables:
        sys.exit(1)
    else:
        print("\n🎉 All tunables validated successfully!")
        sys.exit(0)

if __name__ == "__main__":
    main()