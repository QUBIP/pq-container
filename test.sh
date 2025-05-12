#!/usr/bin/env bash

#set -exo pipefail

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

POLICY="$(update-crypto-policies --show)"
PACKAGES="crypto-policies-scripts liboqs openssl oqsprovider curl expect"
KEY="root.key"
CRT="root.crt"
SERVER_TXT="server_pid.txt"

# Function to start openssl s_server and return its PID
function start_s_server {
    local key=$1
    local cert=$2
    local port=$3

    # Start openssl s_server in the background and capture its PID
    rlRun "openssl s_server -www -key "$key" -cert "$cert" -accept "$port" > /dev/null 2>&1 &"
    s_server_pid=$!
    echo $s_server_pid > $SERVER_TXT
    rlWaitForSocket 4433 -p $s_server_pid
    rlLogInfo "The server started with the id $s_server_pid"
}

# Function to stop the openssl s_server process
function stop_s_server {
    local pid=$(cat $SERVER_TXT)

    # Kill the openssl s_server process
    if [ -n "$pid" ]; then
        rlLogInfo "Stopping openssl s_server with PID $pid..."
        kill "$pid" 2>/dev/null || true-
        rlWait $pid
        rlLogInfo "Server stopped."
    else
        rlLogWarning "No PID provided or PID is empty."
    fi
}

# Function to run openssl s_client and grep for a pattern, then terminate the process
function run_s_client_and_grep {
    local group=$1
    local host=$2
    local port=$3
    local patterns=$4
    local regex_flag=$5
    local modify=$6
    rlRun -s "./client.expect openssl s_client ${group} -connect ${host}:${port}" 0 "Run client"
    if [ ! -z $modify ]; then
        sed -i ':a;N;$!ba;s/using\r\n/using /g' $rlRun_LOG
        fi
    local IFS=';'
    for pattern in ${patterns[@]}; do
        rlAssertGrep "$pattern" $rlRun_LOG $regex_flag
    done
}

rlJournalStart

    rlPhaseStartSetup
        rlAssertRpm --all $PACKAGES
        rlRun -s "update-crypto-policies --show"
        rlAssertGrep "TEST-PQ" $rlRun_LOG
        rlRun -s "openssl list -providers"
        rlAssertGrep "name: OpenSSL OQS Provider" $rlRun_LOG
        rlRun "touch ${SERVER_TXT}"
    rlPhaseEnd

    rlPhaseStartTest "TEST 1: Default connection with X25519MLKEM768"
        start_s_server $KEY $CRT 4433
        run_s_client_and_grep "" "localhost" "4433" "Negotiated TLS1.3 group: X25519MLKEM768" "" ""
        stop_s_server
    rlPhaseEnd

    rlPhaseStartTest "TEST 2: Specifying groups: SecP256r1MLKEM768 and X25519MLKEM768"
        start_s_server $KEY $CRT 4433
        rlLogInfo "Specify the group SecP256r1MLKEM768"
        run_s_client_and_grep "-groups SecP256r1MLKEM768" "localhost" "4433" "Shared groups: SecP256r1MLKEM768" "" ""
        rlLogInfo "Specify the group X25519MLKEM768"
        run_s_client_and_grep "-groups X25519MLKEM768" "localhost" "4433" "Shared groups: X25519MLKEM768" "" ""
        stop_s_server
    rlPhaseEnd

    rlPhaseStartTest "TEST 3: Hybrid ML-KEM - TLS connection with oqs test server"
        rlLogInfo "Connection with SecP256r1MLKEM768"
        run_s_client_and_grep "" "test.openquantumsafe.org" "6001" 'CONNECTED\(00000003\);(Successfully connected using )([a-z]|[A-Z]|[0-9])*(-)*SecP256r1MLKEM768' "-P" "using"
        rlLogInfo "Connection with X25519MLKEM768"
        run_s_client_and_grep "" "test.openquantumsafe.org" "6002" 'CONNECTED\(00000003\);(Successfully connected using )([a-z]|[A-Z]|[0-9])*(-)*X25519MLKEM768' "-P" "using"
    rlPhaseEnd

    rlPhaseStartTest "TEST 4: Tests with the nginx server"
        rlRun "nginx"
        run_s_client_and_grep "" "localhost" "443" "CONNECTED(00000003);Negotiated TLS1.3 group: X25519MLKEM768" "" ""
    rlPhaseEnd

    rlPhaseStartTest "TEST 5: Tests with curl"
        rlRun "curl --cacert $CRT https://localhost:443/ -o /dev/null" 0 "Curl command exit status"
    rlPhaseEnd

    rlPhaseStartTest "TEST 6: List the supported ML-KEM algorithms"
        rlRun -s "openssl list -kem-algorithms -provider oqsprovider"
        rlAssertGrep "SecP256r1MLKEM768" $rlRun_LOG
        rlAssertGrep "X25519MLKEM768" $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartTest "TEST 7: Testing a ML-DSA Key"
        rlLogInfo "Generating a ML-DSA Key Pair"
        rlRun "openssl genpkey -algorithm mldsa65 -out mldsa65_private.pem"
        rlRun "openssl pkey -in mldsa65_private.pem -pubout -out mldsa65_public.pem"
        rlLogInfo "Signing a raw message"
        rlRun "seq 1 10 > message.txt"
        rlRun "openssl dgst -sign mldsa65_private.pem -out signature.bin message.txt"
        rlLogInfo "Verifying the signature"
        rlRun -s "openssl dgst -verify mldsa65_public.pem -signature signature.bin message.txt"
        rlAssertGrep "Verified OK" $rlRun_LOG
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd