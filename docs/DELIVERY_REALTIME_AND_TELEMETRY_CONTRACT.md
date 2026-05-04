# Delivery Realtime & Telemetry Contract

## Socket events
Delivery app consumes these socket events and refreshes task list:
- `task_assigned`
- `task_updated`
- `delivery_task_update`

Payload contract (recommended):
```json
{ "sequence": 123, "taskId": 99 }
```
- `sequence` (or `version`) should be monotonic to avoid stale updates.

## Telemetry ingest endpoint
Client exports events to:
- `POST /api/delivery/telemetry/events`

Request payload:
```json
{
  "schemaVersion": 1,
  "events": [
    {"name": "task_accept_success", "timestamp": "ISO-8601", "props": {"taskId": 42}}
  ]
}
```

Server expectations:
- Accept batch size up to 50 events.
- Return 2xx on success; non-2xx leaves events buffered client-side.

## Idempotency
Mutating endpoints should respect `X-Idempotency-Key`:
- `PUT /api/delivery/tasks/:id/accept`
- `PUT /api/delivery/tasks/:id/status`
- Replay queue `PUT` actions
