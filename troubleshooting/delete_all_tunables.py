#!/usr/bin/env python3
"""
Script to delete all tunables from TrueNAS SCALE via API
"""
import os
import sys
import requests
import json

def delete_all_tunables():
    # Get API key from environment
    api_key = os.environ.get('TRUENAS_API_KEY')
    if not api_key:
        print("ERROR: TRUENAS_API_KEY environment variable not set")
        sys.exit(1)

    # TrueNAS API base URL
    base_url = "http://10.0.2.10/api/v2.0"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }

    try:
        # Get all tunables
        print("Fetching current tunables...")
        response = requests.get(f"{base_url}/tunable", headers=headers)
        response.raise_for_status()

        tunables = response.json()
        total_count = len(tunables)
        print(f"Found {total_count} tunables to delete")

        if total_count == 0:
            print("No tunables found to delete")
            return

        # Delete each tunable
        deleted_count = 0
        failed_count = 0

        for tunable in tunables:
            tunable_id = tunable['id']
            tunable_var = tunable['var']

            try:
                print(f"Deleting tunable {tunable_id}: {tunable_var}")
                delete_response = requests.delete(f"{base_url}/tunable/id/{tunable_id}", headers=headers)
                delete_response.raise_for_status()
                deleted_count += 1
                print(f"  ✓ Successfully deleted {tunable_var}")

            except requests.exceptions.RequestException as e:
                print(f"  ✗ Failed to delete {tunable_var}: {e}")
                failed_count += 1

        print(f"\nDeletion complete:")
        print(f"  Successfully deleted: {deleted_count}")
        print(f"  Failed to delete: {failed_count}")
        print(f"  Total processed: {deleted_count + failed_count}")

    except requests.exceptions.RequestException as e:
        print(f"ERROR: Failed to communicate with TrueNAS API: {e}")
        sys.exit(1)

if __name__ == "__main__":
    delete_all_tunables()