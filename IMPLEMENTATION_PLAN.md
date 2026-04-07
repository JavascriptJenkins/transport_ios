# BuneIOS — Full Implementation Plan

## App Overview
METRC-compliant cannabis transport/logistics iOS app for drivers, managers, and clients.
Backend: `haven.bunepos.com` (OAuth2 + Transport MCP APIs).
Design: Dark glassmorphic UI (already established in login screen).

---

## Phase 1 — Foundation Layer
**Goal:** Networking, models, auth, navigation shell. Everything future phases build on.

### Task 1.1: Swift Models (all Codable structs)
Drop in all transport entity models from the MCP schema. 22 entities total.
- `Transfer`, `TransferDestination`, `TransferPackage`
- `TransportSession`, `SessionPackage`
- `Package`, `Driver`, `Vehicle`, `Destination`, `Transporter`
- `Route`, `RouteStop`
- `Zone`, `ZonePackageAssignment`, `ZoneScanAudit`
- `Tote`, `ToteConfiguration`, `TotePackage`
- `GPSPing`, `TrackingEvent`, `VehicleLocationPing`
- `ActionLog`, `PackageMedia`
- `ScanSession`, `ScanPackage` (pickup/delivery scan models)
- `ChatMessage`, `DeliveryReceipt`
- Generic `APIResponse<T>` and `Pagination` wrappers
**File:** `Models/TransportModels.swift`

### Task 1.2: API Client (networking layer)
Build `TransportAPIClient` using async/await + URLSession.
- Inject OAuth2 access token from `AuthService` into every request
- Auto-refresh token on 401 responses
- Base URL: `https://haven.bunepos.com`
- All endpoints return `APIResponse<T>` wrapper
- Methods for every endpoint group: transfers, sessions, packages, routes, zones, GPS, pickup scan, delivery scan, chat, action log
**File:** `Services/TransportAPIClient.swift`

### Task 1.3: Upgrade AuthService for OAuth2 token injection
- Refactor `AuthService` to expose a method that returns an authorized `URLRequest`
- Parse `scope` from token response to extract user roles
- Store roles in published property for role-based UI rendering
- Add role helper computed properties: `isDriver`, `isManager`, `isClient`, `isAdmin`
**File:** Update `Services/AuthService.swift`

### Task 1.4: Role-based Navigation Shell
- `MainTabView` with conditional tabs based on user roles
- Driver tabs: Transfers, Pickup Scan, Delivery Scan, Tracking
- Manager tabs: Transfers, Create Manifest, Zones, Routes, Vehicles
- Client tabs: Portal, Track
- All tabs: Settings (with logout)
- Dark theme tab bar matching glassmorphic aesthetic
**Files:** `Views/MainTabView.swift`, update `ContentView.swift`

### Task 1.5: App-wide Theme / Design System
- Color palette constants (dark bg, glass fills, accent purples, status colors)
- Reusable glassmorphic card modifier
- Status badge component (color-coded by transfer status)
- Progress bar component (6-step transfer lifecycle)
- Reusable glass text field style (from login screen)
**File:** `Views/Components/Theme.swift`, `Views/Components/GlassCard.swift`, `Views/Components/StatusBadge.swift`, `Views/Components/TransferProgressBar.swift`

---

## Phase 2 — Transfer Dashboard + Detail
**Goal:** Core data views — list, filter, and inspect transfers.

### Task 2.1: Transfer List View
- Paginated list of transfers (lazy loading)
- Category sub-tabs: Outgoing, Incoming, Hub, Active Trips
- Each row: glassmorphic card with manifest #, status badge, origin→destination, package count, driver, vehicle, mini progress bar
- Color-coded left border by operational status
- Pull-to-refresh + auto-refresh timer
- Message count badges (polled every 60s)
**File:** `Views/Dashboard/TransferListView.swift`

### Task 2.2: Transfer Filters
- Collapsible filter bar with:
  - Date range quick-select (1, 3, 7, 14, 30, 90 days)
  - Text search (manifest, name, license, driver, vehicle)
  - Status pill filters (CREATED through ACCEPTED + CANCELED)
  - METRC status pills
  - Route filter pills
**File:** `Views/Dashboard/TransferFilterBar.swift`

### Task 2.3: Transfer Detail View
- Full transfer info: manifest, status, shipper/receiver, driver/vehicle
- Package list with labels, product names, quantities
- 6-step progress bar with animated fill
- Status action buttons (context-dependent: Dispatch, Accept Hub, Depart, Mark Delivered)
- Map preview showing route (if assigned)
- Chat button (navigates to chat view)
- Tracking events timeline
**File:** `Views/Dashboard/TransferDetailView.swift`

### Task 2.4: Transfer Detail ViewModel
- Loads transfer detail, packages, tracking events
- Handles status update actions
- Manages polling for live status updates
**File:** `ViewModels/TransferDetailViewModel.swift`

### Task 2.5: Chat View
- Per-transfer messaging thread
- Sender-aligned bubbles (driver right, admin left)
- Quick reply chips: "On my way", "Arrived", "Running late", "Need assistance"
- Polls every 10s when visible using `since` parameter
- Text input with send button
**File:** `Views/Chat/ChatView.swift`

---

## Phase 3 — Scanning Workflows
**Goal:** The core driver experience — pickup scan, delivery scan, session builder.

### Task 3.1: Barcode Scanner Service
- AVFoundation camera-based Code 128 barcode scanning
- 24-character METRC tag validation
- Haptic feedback on scan (success/error)
- Manual text entry fallback (large monospace input)
- Keep screen awake during scanning
- Auto-scan on detection (no tap required)
**File:** `Services/BarcodeScannerService.swift`, `Views/Components/BarcodeScannerView.swift`

### Task 3.2: Pickup Scan Flow
1. Transfer picker: list transfers in DISPATCH/AT_HUB status
2. Start scan session → show package checklist
3. Scan each package → mark green, update progress bar
4. Unscan option for mistakes
5. Complete pickup → transfer moves to IN_TRANSIT
6. Success screen with trip details
- Session resume on app relaunch (check `hasActiveSession`)
- Abandon session with confirmation dialog
**Files:** `Views/Scanning/PickupScanView.swift`, `ViewModels/PickupScanViewModel.swift`

### Task 3.3: Delivery Scan Flow
1. Transfer picker: list transfers in DELIVERED status
2. Start delivery session → show package checklist
3. Scan each package → progress bar updates
4. Complete → signature capture modal
5. Signature pad using PencilKit (PKCanvasView)
6. Export signature as base64 PNG + signer name
7. Submit → show QR code for receipt download
**Files:** `Views/Scanning/DeliveryScanView.swift`, `Views/Scanning/SignatureCaptureView.swift`, `ViewModels/DeliveryScanViewModel.swift`

### Task 3.4: Session Builder (Create Manifest — 3-phase wizard)
**Phase 1 — SCAN:** Large barcode input, search packages, browse all packages modal, scanned list with remove buttons
**Phase 2 — CONFIGURE:** Shipper (pre-filled), transporter picker, recipient picker, transfer type, driver/vehicle assignment, route, schedule (departure/arrival ETA)
**Phase 3 — REVIEW:** Summary card, package list, submit to METRC button
- Reference data pickers for drivers, vehicles, destinations, routes, transporters
- Session state persistence (resume if interrupted)
**Files:** `Views/Session/SessionBuilderView.swift`, `Views/Session/ScanPhaseView.swift`, `Views/Session/ConfigurePhaseView.swift`, `Views/Session/ReviewPhaseView.swift`, `ViewModels/SessionBuilderViewModel.swift`

---

## Phase 4 — GPS, Maps, Offline, Notifications
**Goal:** Live tracking, route maps, offline resilience, push notifications.

### Task 4.1: GPS Tracking Service
- CLLocationManager wrapper with background location support
- Submit pings every 30s during active transit
- Include speed, heading, accuracy, timestamp
- Handle geofence alerts from server response
- Battery optimization: reduce frequency when stationary
- Background Modes: Location updates capability
**File:** `Services/GPSTrackingService.swift`

### Task 4.2: Live Tracking View
- 6-step animated progress bar (CREATED → ACCEPTED)
- Status banner with ETA + overdue warning
- Driver action panel (conditional buttons: Depart, Pickup Scan, Mark Delivered, etc.)
- Polls status every 10 seconds
- GPS ping button (manual location submit)
- Route navigation button
**File:** `Views/Tracking/LiveTrackingView.swift`, `ViewModels/LiveTrackingViewModel.swift`

### Task 4.3: Map View (Route + Live Position)
- MapKit integration
- Plot route stops as numbered pins
- Draw route polyline between stops
- Show live vehicle position from GPS pings
- Geofence radius circles around stops
- Vehicle history trail (breadcrumb dots)
**File:** `Views/Map/RouteMapView.swift`

### Task 4.4: Offline Sync Service
- Network reachability monitoring (NWPathMonitor)
- Local queue for: GPS pings, package scans, status updates, zone scan events
- Cache active transfers, driver/vehicle/route reference data locally
- On reconnect: drain queue in order with exponential backoff
- Conflict resolution: server-wins (server timestamp is truth)
- Sync status indicator in UI (banner when offline)
- Prevent "Complete" actions while offline
**File:** `Services/OfflineSyncService.swift`, `Services/LocalCacheService.swift`

### Task 4.5: Zone Management View
- Zone grid display with package count badges
- Package scanner integration (scan into/out of zones)
- Zone types: Standard, Originator, Vehicle
- Recent scans list
- Scan audit log viewer
**File:** `Views/Zones/ZoneManagerView.swift`, `ViewModels/ZoneManagerViewModel.swift`

### Task 4.6: Notifications Service
- Local notification scheduling for status changes, geofence alerts, chat messages, ETA events
- Background App Refresh for periodic status checking
- UNUserNotificationCenter integration
- Notification categories with action buttons
**File:** `Services/NotificationService.swift`

### Task 4.7: Action Log View
- Infinite-scroll list of audit events
- Horizontal chip bar filter by action type
- Pull-to-refresh
- Color-coded by type (scan=blue, status=amber, alert=red)
- Tap to expand details
**File:** `Views/ActivityLog/ActionLogView.swift`

---

## Agent Assignment Strategy

### Parallel Execution Plan
Each agent works in an isolated worktree to avoid conflicts.

#### Wave 1 — Foundation (4 parallel agents)
| Agent | Tasks | Dependencies |
|-------|-------|-------------|
| **Agent A: Models** | Task 1.1 (all Swift models) | None |
| **Agent B: API Client** | Task 1.2 (TransportAPIClient) | Needs model names but can use forward declarations |
| **Agent C: Theme System** | Task 1.5 (design system, reusable components) | None |
| **Agent D: Auth Upgrade** | Task 1.3 (AuthService role parsing) | Existing AuthService |

#### Wave 2 — Navigation + Dashboard (3 parallel agents, after Wave 1 merges)
| Agent | Tasks | Dependencies |
|-------|-------|-------------|
| **Agent E: Nav Shell** | Task 1.4 (MainTabView, role-based routing) | Auth roles from Wave 1 |
| **Agent F: Transfer List** | Tasks 2.1, 2.2 (list view + filters) | Models, API client, theme from Wave 1 |
| **Agent G: Transfer Detail + Chat** | Tasks 2.3, 2.4, 2.5 (detail view, VM, chat) | Models, API client, theme from Wave 1 |

#### Wave 3 — Scanning (3 parallel agents, after Wave 2 merges)
| Agent | Tasks | Dependencies |
|-------|-------|-------------|
| **Agent H: Scanner Service** | Task 3.1 (AVFoundation barcode scanner) | None (standalone service) |
| **Agent I: Pickup + Delivery Scan** | Tasks 3.2, 3.3 (both scan flows + signature) | Scanner service, models, API |
| **Agent J: Session Builder** | Task 3.4 (3-phase manifest wizard) | Models, API client |

#### Wave 4 — GPS, Maps, Offline (4 parallel agents, after Wave 3 merges)
| Agent | Tasks | Dependencies |
|-------|-------|-------------|
| **Agent K: GPS + Tracking** | Tasks 4.1, 4.2 (GPS service, live tracking view) | Models, API client |
| **Agent L: Maps** | Task 4.3 (MapKit route/live view) | Models, GPS service |
| **Agent M: Offline + Cache** | Task 4.4 (sync service, local cache) | API client, models |
| **Agent N: Zones + Notifications + Log** | Tasks 4.5, 4.6, 4.7 (zone mgmt, notifs, action log) | Models, API, scanner |

### Total: 14 agent assignments across 4 waves
### Estimated file count: ~35-40 Swift files
### Merge strategy: Each wave merges to main before next wave starts
