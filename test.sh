#!/usr/bin/env bash

#set -exo pipefail

rpm -q crypto-policies-scripts liboqs openssl oqsprovider
update-crypto-policies --show | grep TEST-PQ
openssl list -providers | grep 'name: OpenSSL OQS Provider'

# Function to start openssl s_server and return its PID
function start_s_server {
    local key=$1
    local cert=$2
    local port=$3

    # Start openssl s_server in the background and capture its PID
    openssl s_server -key "$key" -cert "$cert" -accept "$port" > /dev/null 2>&1 &
    s_server_pid=$!
    echo $s_server_pid
}

# Function to stop the openssl s_server process
function stop_s_server {
    local pid=$1

    # Kill the openssl s_server process
    if [ -n "$pid" ]; then
        kill "$pid" 2>/dev/null || true

        # Wait for the process to terminate
        wait "$pid" 2>/dev/null || true
    else
        echo "No PID provided or PID is empty."
    fi
}

# Function to run openssl s_client and grep for a pattern, then terminate the process
function run_s_client_and_grep {
    local group=$1
    local host=$2
    local port=$3
    local pattern=$4
    local found=0  # Flag to check if the pattern was found
    
    # Run openssl s_client in the background, redirecting output to a temporary file
    tmpfile=$(mktemp)
    timeout 10s openssl s_client ${group} -connect ${host}:${port} -trace > "$tmpfile" 2>&1 &
    s_client_pid=$!

    echo "Running s_client on ${host}:${port}, searching for pattern: '${pattern}'"

    # Monitor the output file for the pattern
    while read -r line; do
        echo "$line" | grep -q "$pattern"
        if [ $? -eq 0 ]; then
            echo "Pattern '${pattern}' found, terminating openssl s_client."
            found=1
            kill "$s_client_pid" 2>/dev/null || true
            break
        fi
    done < <(timeout 15s tail -f "$tmpfile")  # Process substitution to avoid subshell issues

    # Wait for the s_client process to exit
    wait "$s_client_pid" 2>/dev/null || true

    # If the pattern was not found, print an error message
    if [ $found -eq 0 ]; then
        echo "Error: Pattern '${pattern}' not found within the timeout period."
	return 1
    fi

    # Cleanup
    rm -f "$tmpfile"
}

# OpenSSL client and server tests

# Start the server
echo "Starting openssl s_server..."
s_server_pid=$(start_s_server "root.key" "root.crt" 4433)
echo "Server started with PID $s_server_pid"

# Give the server some time to start (if needed)
sleep 5

# TEST 1: Default connection to X25519-KYBER768
run_s_client_and_grep "" "localhost" "4433" "NamedGroup: X25519Kyber768Draft00 (25497)"

# Stop the server
echo "Stopping openssl s_server with PID $s_server_pid..."
stop_s_server "$s_server_pid"
echo "Server stopped."

# Start the server
echo "Starting openssl s_server..."
s_server_pid=$(start_s_server "root.key" "root.crt" 4433)
echo "Server started with PID $s_server_pid"

# Give the server some time to start (if needed)
sleep 5

# TEST 2: Specify the group explicitly
run_s_client_and_grep "-groups p256_kyber768" "localhost" "4433" "NamedGroup: SecP256r1Kyber768Draft00 (25498)"

# Stop the server
echo "Stopping openssl s_server with PID $s_server_pid..."
stop_s_server "$s_server_pid"
echo "Server stopped."

# TEST 3: Tests with the external server
run_s_client_and_grep "" "test.openquantumsafe.org" "6042" "CONNECTED(00000003)"
run_s_client_and_grep "" "test.openquantumsafe.org" "6042" "NamedGroup: SecP256r1Kyber768Draft00 (25498)"
run_s_client_and_grep "" "test.openquantumsafe.org" "6044" "CONNECTED(00000003)"
run_s_client_and_grep "" "test.openquantumsafe.org" "6044" "NamedGroup: X25519Kyber768Draft00 (25497)"

# TEST 4: Tests with the nginx server
# Path to the nginx.conf file
nginx_conf="/etc/nginx/nginx.conf"

# Uncomment the section under "Settings for a TLS enabled server"
sed -i '/# Settings for a TLS enabled server/ {
    n
    :a
    s/^#//
    n
    /^\s*}/!ba
}' "$nginx_conf"
nginx
run_s_client_and_grep "" "localhost" "443" "NamedGroup: X25519Kyber768Draft00 (25497)"
run_s_client_and_grep "" "localhost" "443" "CONNECTED(00000003)"

# TEST 5: Tests with curl
# Execute curl command and capture the exit status
curl --cacert root.crt https://localhost:443/ -o /dev/null
if [ $? -eq 0 ]; then
    echo "Curl command succeeded."
else
    echo "Curl command failed."
fi

