# Delivery E2E Test Plan

## Flow A: Online happy path
1. Login as delivery agent
2. Go online
3. Receive assigned task (via socket)
4. Accept task
5. Complete OTP transitions
6. Verify task appears in history

## Flow B: Offline queue replay
1. Go offline / disable network
2. Attempt accept or status update
3. Verify queued action badge increases
4. Re-enable network
5. Wait for polling/background replay
6. Verify action applied and queue decreases

## Flow C: Telemetry export
1. Perform 2-3 tracked actions
2. Trigger telemetry export
3. Verify backend receives events batch with schemaVersion

## Flow D: Security policy
1. Run release with `--dart-define=TLS_PINNING_HEALTHY=false`
2. Verify sensitive API calls are blocked by gate
