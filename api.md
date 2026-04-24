# API Specification - Parent Bus Tracker

All APIs use `Authorization: Bearer <token>` after OTP verification.

## 1) Send OTP
- Endpoint: `POST /v1/auth/send-otp`
- Screen: `Login`
- Headers: `Content-Type: application/json`
- Request:
```json
{ "mobile": "+919000000000" }
```
- Response:
```json
{ "success": true, "requestId": "otp_req_123", "message": "OTP sent" }
```
- Errors: `400 invalid_mobile`, `429 rate_limited`, `500 server_error`

## 2) Verify OTP
- Endpoint: `POST /v1/auth/verify-otp`
- Screen: `Login`
- Headers: `Content-Type: application/json`
- Request:
```json
{ "mobile": "+919000000000", "otp": "123456", "requestId": "otp_req_123" }
```
- Response:
```json
{
  "success": true,
  "token": "jwt_token",
  "parent": { "id": "p_1", "name": "Sarah Lee", "mobile": "+919000000000" },
  "child": { "id": "c_1", "name": "Ethan Lee", "assignedStopId": "s5" }
}
```
- Errors: `401 invalid_otp`, `410 otp_expired`

## 3) Get Assigned Route
- Endpoint: `GET /v1/routes/assigned`
- Screens: `Home`, `Profile`
- Response:
```json
{
  "routeId": "r_green",
  "routeName": "Green Line",
  "busNumber": "KA-01-BT-204",
  "driver": { "name": "Rajesh", "phone": "+919111111111" }
}
```

## 4) Get Route Stops
- Endpoint: `GET /v1/routes/{routeId}/stops`
- Screens: `Home`, `Map`
- Response:
```json
{
  "stops": [
    { "id": "s1", "name": "Central School", "lat": 12.9716, "lng": 77.5946, "sequence": 1 },
    { "id": "s2", "name": "Lake View Stop", "lat": 12.9738, "lng": 77.5986, "sequence": 2 }
  ]
}
```

## 5) Get Live Bus Location
- Endpoint: `GET /v1/bus/live-location?routeId={routeId}`
- Screens: `Home`, `Map`
- Polling: fallback every 5s if socket disconnected
- Realtime: WebSocket/Firebase preferred
- Response:
```json
{
  "lat": 12.9734,
  "lng": 77.5978,
  "heading": 92,
  "speedKmh": 32,
  "timestamp": "2026-04-21T08:50:00Z",
  "isStale": false,
  "deviated": false
}
```

## 6) ETA Calculation
- Endpoint: `GET /v1/bus/eta?routeId={routeId}&stopId={stopId}`
- Screen: `Home`
- Response:
```json
{
  "currentStopId": "s2",
  "nextStopId": "s3",
  "etaToNextMinutes": 4,
  "delayMinutes": 2,
  "completionPercent": 38
}
```

## 7) Route Change Request
- Endpoint: `POST /v1/routes/change-request`
- Screen: `Profile`
- Request:
```json
{
  "childId": "c_1",
  "currentRouteId": "r_green",
  "requestedRouteId": "r_blue",
  "reason": "New pickup location"
}
```
- Response:
```json
{ "success": true, "requestId": "rc_1001", "status": "pending" }
```

## 8) Notification Fetch
- Endpoint: `GET /v1/notifications?limit=30`
- Screen: `Home` (Admin tab)
- Response:
```json
{
  "items": [
    { "id": "n1", "type": "delay", "title": "Route Delayed", "message": "Bus delayed by 7 minutes", "priority": "high", "timestamp": "2026-04-21T08:40:00Z" }
  ]
}
```

## 9) Logout
- Endpoint: `POST /v1/auth/logout`
- Screen: `Profile`
- Request:
```json
{ "deviceId": "android_abc123" }
```
- Response:
```json
{ "success": true }
```

## OpenRouteService Polyline
- Endpoint: `POST https://api.openrouteservice.org/v2/directions/driving-car/geojson`
- Screen: `Map`
- Usage: fetch route path once at load, cache in memory
- Headers:
  - `Authorization: <OPENROUTESERVICE_API_KEY>`
  - `Content-Type: application/json`

## Realtime Event Contract (WebSocket/Firebase)

- `route_started`
- `location_update`
- `eta_update`
- `stop_crossed`
- `bus_arriving_2_stops`
- `bus_arriving_1_stop`
- `bus_arrived`
- `route_completed`
- `emergency_alert`

Clients must persist the last payload and display `Last updated <time>` when network is weak.
