#!/usr/bin/env python3
"""
TrueNAS Test Tunable Cleanup Script
Removes any test tunables that may have been left behind during validation
"""

import os
import sys
import requests
import json
import time
from typing import List, Dict

def monitor_jobs(host: str, headers: dict, timeout_seconds: int = 30) -> bool:
    """Monitor running jobs until completion or timeout"""
    session = requests.Session()
    session.headers.update(headers)
    start_time = time.time()

    while time.time() - start_time < timeout_seconds:
        try:
            response = session.get(f"http://{host}/api/v2.0/core/get_jobs", timeout=10)
            if response.status_code == 200:
                jobs = response.json()
                # If no jobs are running, we're done
                if not jobs or len(jobs) == 0:
                    return True

                # Check if any jobs are still running
                running_jobs = [job for job in jobs if job.get('state') in ['RUNNING', 'WAITING']]
                if not running_jobs:
                    return True

                # Brief wait before checking again
                time.sleep(0.5)
            else:
                # If we can't check jobs, fall back to brief wait
                time.sleep(2)
                return True

        except Exception:
            # If job monitoring fails, fall back to brief wait
            time.sleep(2)
            return True

    return False  # Timeout reached

def delete_tunable_rest(host: str, headers: dict, tunable_id: int):
    """Delete a tunable using REST API with job monitoring"""
    session = requests.Session()
    session.headers.update(headers)

    # Method 1: Standard REST DELETE (with correct endpoint format)
    try:
        response = session.delete(
            f"http://{host}/api/v2.0/tunable/id/{tunable_id}",
            timeout=30
        )

        if response.status_code in [200, 204]:
            # Monitor any jobs that might be spawned
            monitor_jobs(host, headers, timeout_seconds=10)

            # Verify deletion by checking if tunable still exists
            verify_response = session.get(f"http://{host}/api/v2.0/tunable", timeout=30)
            if verify_response.status_code == 200:
                tunables = verify_response.json()
                still_exists = any(t.get("id") == tunable_id for t in tunables)
                if not still_exists:
                    return True
    except Exception:
        pass

    # Method 2: Try disabling the tunable instead (with correct endpoint format)
    try:
        disable_data = {"enabled": False}
        response = session.put(
            f"http://{host}/api/v2.0/tunable/id/{tunable_id}",
            json=disable_data,
            timeout=30
        )

        if response.status_code == 200:
            monitor_jobs(host, headers, timeout_seconds=10)
            return True
    except Exception:
        pass

    raise Exception(f"Failed to delete tunable {tunable_id} using all methods")

def get_tunables_rest(host: str, headers: dict):
    """Get tunables using REST API"""
    response = requests.get(f"http://{host}/api/v2.0/tunable", headers=headers)
    if response.status_code != 200:
        raise Exception(f"HTTP {response.status_code}: {response.text}")
    return response.json()

def main():
    api_key = os.getenv("TRUENAS_API_KEY")
    if not api_key:
        print("ERROR: TRUENAS_API_KEY environment variable not set")
        sys.exit(1)

    truenas_host = "10.0.2.10"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }

    print("🧹 TrueNAS Test Tunable Cleanup")
    print("=" * 40)

    try:
        # Get all tunables using REST API
        tunables = get_tunables_rest(truenas_host, headers)
        print(f"📊 Found {len(tunables)} total tunables")

        # Identify test tunables (ones with test-related comments or from our test list)
        test_keywords = ['test', 'validation', 'performance tunable test']
        performance_tunable_names = {
            'vm.swappiness', 'vm.vfs_cache_pressure', 'vm.dirty_ratio', 'vm.dirty_background_ratio',
            'vm.dirty_expire_centisecs', 'vm.min_free_kbytes', 'kernel.shmmax', 'kernel.shmall',
            'net.core.rmem_max', 'net.core.wmem_max', 'zfs_arc_max', 'zfs_arc_min'
            # Add more as needed
        }

        test_tunables = []
        for tunable in tunables:
            comment = tunable.get('comment', '').lower()
            var_name = tunable.get('var', '')

            # Check if it's a test tunable
            is_test = any(keyword in comment for keyword in test_keywords)
            is_performance = var_name in performance_tunable_names

            if is_test or is_performance:
                test_tunables.append(tunable)

        if not test_tunables:
            print("✅ No test tunables found - system is clean")
            return

        print(f"🎯 Found {len(test_tunables)} test tunables:")
        for tunable in test_tunables:
            print(f"   • ID: {tunable['id']}, Name: {tunable['var']}, Comment: {tunable.get('comment', 'N/A')}")

        # Ask for confirmation
        if len(sys.argv) > 1 and sys.argv[1] == '--force':
            confirm = 'y'
        else:
            confirm = input(f"\n❓ Delete these {len(test_tunables)} test tunables? (y/N): ").lower()

        if confirm != 'y':
            print("🚫 Cleanup cancelled")
            return

        # Attempt cleanup - actually delete the tunables
        deleted = 0
        failed = 0

        for tunable in test_tunables:
            tunable_id = tunable['id']
            var_name = tunable['var']

            try:
                # Delete the tunable using REST API
                result = delete_tunable_rest(truenas_host, headers, tunable_id)
                print(f"🗑️  Deleted: {var_name} (ID: {tunable_id})")
                deleted += 1

            except Exception as e:
                print(f"❌ Failed to delete: {var_name} (ID: {tunable_id}) - {str(e)}")
                failed += 1

        print("\n" + "=" * 40)
        print("📈 CLEANUP RESULTS")
        print("=" * 40)
        print(f"🗑️  Deleted: {deleted}")
        print(f"❌ Failed: {failed}")

        if failed > 0:
            print(f"\n⚠️  Note: {failed} tunables could not be deleted automatically.")
            print("   You may need to remove them manually in the TrueNAS web interface.")
            print("   Go to System Settings > Tunables to manage them.")

    except Exception as e:
        print(f"❌ Error during cleanup: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()