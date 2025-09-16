#!/bin/bash

# Get all tunable IDs
IDS=$(curl -s -X GET "http://10.0.2.10/api/v2.0/tunable" -H "Authorization: Bearer $TRUENAS_API_KEY" -H "Content-Type: application/json" | sed -n 's/.*"id": *\([0-9]*\).*/\1/p')

echo "Found tunable IDs: $IDS"

# Delete each tunable
for id in $IDS; do
    echo "Deleting tunable ID: $id"
    response=$(curl -s -w "%{http_code}" -X DELETE "http://10.0.2.10/api/v2.0/tunable/id/$id" -H "Authorization: Bearer $TRUENAS_API_KEY" -H "Content-Type: application/json")
    http_code="${response: -3}"
    body="${response%???}"
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "204" ]; then
        echo "✓ Successfully deleted tunable $id"
    else
        echo "✗ Failed to delete tunable $id (HTTP $http_code): $body"
    fi
done

echo "All tunables deletion process completed"
