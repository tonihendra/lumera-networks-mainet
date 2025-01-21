#!/bin/bash

# verify_genesis_hashes.sh
# Usage: ./verify_genesis_hashes.sh [mainnet|testnet]

if [ $# -ne 1 ]; then
    echo "Usage: $0 [mainnet|testnet]"
    exit 1
fi

if [ "$1" != "mainnet" ] && [ "$1" != "testnet" ]; then
    echo "Error: Parameter must be either 'mainnet' or 'testnet'"
    exit 1
fi

NETWORK=$1
JSON_PATH="${NETWORK}/genesis.json"
ASC_PATH="${NETWORK}/genesis.asc"

if [ ! -f "$JSON_PATH" ]; then
    echo "Error: genesis.json not found at ${JSON_PATH}"
    exit 1
fi

if [ ! -f "$ASC_PATH" ]; then
    echo "Error: genesis.asc not found at ${ASC_PATH}"
    exit 1
fi

# Create temporary file for normalized JSON
TMP_JSON=$(mktemp)
jq -S '.' "$JSON_PATH" > "$TMP_JSON"

# Generate current hashes
CURR_SHA256=$(sha256sum "$TMP_JSON" | cut -d' ' -f1)
CURR_SHA512=$(sha512sum "$TMP_JSON" | cut -d' ' -f1)
CURR_SHAKE128=$(openssl dgst -shake128 "$TMP_JSON" | cut -d' ' -f2)
CURR_SHAKE256=$(openssl dgst -shake256 "$TMP_JSON" | cut -d' ' -f2)

# Read stored hashes
STORED_SHA256=$(grep "SHA256=" "$ASC_PATH" | cut -d'=' -f2)
STORED_SHA512=$(grep "SHA512=" "$ASC_PATH" | cut -d'=' -f2)
STORED_SHAKE128=$(grep "SHAKE128=" "$ASC_PATH" | cut -d'=' -f2)
STORED_SHAKE256=$(grep "SHAKE256=" "$ASC_PATH" | cut -d'=' -f2)

rm "$TMP_JSON"

# Verify each hash
verify_hash() {
    local hash_type=$1
    local current=$2
    local stored=$3
    
    if [ "$current" = "$stored" ]; then
        echo "${hash_type}: VERIFIED ✓"
    else
        echo "${hash_type}: FAILED ✗"
        echo "  Expected: ${stored}"
        echo "  Got:      ${current}"
        return 1
    fi
}

FAILED=0

verify_hash "SHA256" "$CURR_SHA256" "$STORED_SHA256" || FAILED=1
verify_hash "SHA512" "$CURR_SHA512" "$STORED_SHA512" || FAILED=1
verify_hash "SHAKE128" "$CURR_SHAKE128" "$STORED_SHAKE128" || FAILED=1
verify_hash "SHAKE256" "$CURR_SHAKE256" "$STORED_SHAKE256" || FAILED=1

if [ $FAILED -eq 0 ]; then
    echo "All hashes verified successfully!"
    exit 0
else
    echo "Hash verification failed!"
    exit 1
fi

