//
//  TransportAPIClient.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import Foundation
import SwiftUI

// MARK: - Helper Request/Response Structs

struct SessionUpdateRequest: Encodable {
    var driverId: Int?
    var vehicleId: Int?
    var destinationId: Int?
    var routeId: Int?
    var estimatedDeparture: String?
    var estimatedArrival: String?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case driverId
        case vehicleId
        case destinationId
        case routeId
        case estimatedDeparture
        case estimatedArrival
        case notes
    }
}

struct RouteStopRequest: Encodable {
    var destinationId: Int
    var stopOrder: Int
    var latitude: Double
    var longitude: Double
    var estimatedArrivalOffset: Int?
    var estimatedDwellMinutes: Int?
}

struct GeofenceConfig: Encodable {
    var radiusMeters: Double
    var alertOnEntry: Bool
    var alertOnExit: Bool
    var alertOnDeviation: Bool
    var deviationThresholdMeters: Double?
}

struct GPSPingResponse: Codable {
    var pingId: Int?
    var recorded: Bool?
    var geofenceAlert: GeofenceAlert?
}

struct GeofenceAlert: Codable {
    var type: String
    var zoneName: String?
}

// MARK: - API Error

enum APIError: LocalizedError {
    case serverError(String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .serverError(let message): return message
        case .decodingFailed(let message): return "Decoding failed: \(message)"
        }
    }
}

/// Empty placeholder for decoding error-only responses
struct EmptyData: Codable {}

// MARK: - Transport API Client

@MainActor
class TransportAPIClient: ObservableObject {

    /// Base URL for the selected tenant, resolved dynamically per request.
    /// Falls back to the legacy single-tenant value when no tenant is selected.
    /// Exposed so callers (e.g. view models building receipt URLs) can stay
    /// tenant-aware without re-implementing the fallback logic.
    var baseURL: String {
        authService.selectedTenant?.baseURL ?? Config.transportBaseURL
    }

    /// API key for the selected tenant, resolved per request.
    private var apiKey: String { authService.apiKey }

    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    // MARK: - Generic HTTP Methods

    private func get<T: Decodable>(path: String) async throws -> T {
        let (data, statusCode) = try await performRequest(
            method: "GET",
            path: path,
            body: nil
        )

        if statusCode == 401 {
            try await authService.refreshAccessToken()
            let (retryData, retryStatusCode) = try await performRequest(
                method: "GET",
                path: path,
                body: nil
            )
            return try decodeResponse(retryData, statusCode: retryStatusCode)
        }

        return try decodeResponse(data, statusCode: statusCode)
    }

    private func post<T: Decodable>(path: String, body: Encodable? = nil) async throws -> T {
        let (data, statusCode) = try await performRequest(
            method: "POST",
            path: path,
            body: body
        )

        if statusCode == 401 {
            try await authService.refreshAccessToken()
            let (retryData, retryStatusCode) = try await performRequest(
                method: "POST",
                path: path,
                body: body
            )
            return try decodeResponse(retryData, statusCode: retryStatusCode)
        }

        return try decodeResponse(data, statusCode: statusCode)
    }

    private func put<T: Decodable>(path: String, body: Encodable? = nil) async throws -> T {
        let (data, statusCode) = try await performRequest(
            method: "PUT",
            path: path,
            body: body
        )

        if statusCode == 401 {
            try await authService.refreshAccessToken()
            let (retryData, retryStatusCode) = try await performRequest(
                method: "PUT",
                path: path,
                body: body
            )
            return try decodeResponse(retryData, statusCode: retryStatusCode)
        }

        return try decodeResponse(data, statusCode: statusCode)
    }

    private func delete(path: String) async throws {
        let (_, statusCode) = try await performRequest(
            method: "DELETE",
            path: path,
            body: nil
        )

        if statusCode == 401 {
            try await authService.refreshAccessToken()
            _ = try await performRequest(
                method: "DELETE",
                path: path,
                body: nil
            )
        }
    }

    // MARK: - Request Execution

    private func performRequest(method: String, path: String, body: Encodable?) async throws -> (Data, Int) {
        guard let url = URL(string: baseURL + path) else {
            print("❌ [API] Bad URL: \(baseURL + path)")
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        // Add headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        if let token = authService.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Encode body if provided
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        #if DEBUG
        print("🌐 [API] \(method) \(url.absoluteString)")
        print("🌐 [API] API-Key present: \(!apiKey.isEmpty), Token present: \(authService.accessToken != nil)")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [API] Response is not HTTPURLResponse for \(path)")
            throw URLError(.badServerResponse)
        }

        #if DEBUG
        print("🌐 [API] \(method) \(path) → HTTP \(httpResponse.statusCode) (\(data.count) bytes)")
        if !(200...299).contains(httpResponse.statusCode),
           let bodyStr = String(data: data, encoding: .utf8) {
            print("❌ [API] Error body: \(String(bodyStr.prefix(500)))")
        }
        #endif

        return (data, httpResponse.statusCode)
    }

    private func decodeResponse<T: Decodable>(_ data: Data, statusCode: Int) throws -> T {
        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🔍 [decodeResponse] Type: \(T.self), Status: \(statusCode)")
            print("🔍 [decodeResponse] Raw JSON (first 500): \(String(jsonString.prefix(500)))")
        }
        #endif

        guard (200...299).contains(statusCode) else {
            // Try to extract error message from API response
            if let errorResponse = try? JSONDecoder().decode(APIResponse<EmptyData>.self, from: data),
               let errorMsg = errorResponse.error {
                throw APIError.serverError("HTTP \(statusCode): \(errorMsg)")
            }
            throw APIError.serverError("HTTP \(statusCode): Server returned an error")
        }

        // Try to unwrap APIResponse<T> envelope first
        do {
            let apiResponse = try JSONDecoder().decode(APIResponse<T>.self, from: data)
            if let responseData = apiResponse.data {
                print("✅ [decodeResponse] Successfully unwrapped APIResponse<\(T.self)>")
                return responseData
            } else if let error = apiResponse.error {
                throw APIError.serverError(error)
            }
        } catch {
            print("⚠️ [decodeResponse] APIResponse<\(T.self)> decode failed: \(error)")
        }

        // Fallback: try direct decode (for endpoints that don't use the wrapper)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Decode a paginated API response, extracting the content array from the envelope
    private func decodePaginatedResponse<T: Decodable>(_ data: Data, statusCode: Int) throws -> [T] {
        guard (200...299).contains(statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(APIResponse<EmptyData>.self, from: data),
               let errorMsg = errorResponse.error {
                throw APIError.serverError("HTTP \(statusCode): \(errorMsg)")
            }
            throw APIError.serverError("HTTP \(statusCode): Server returned an error")
        }

        // Debug: print raw response for troubleshooting
        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📦 [API Response] Type: \(T.self)")
            print("📦 [API Response] Raw JSON (first 500 chars): \(String(jsonString.prefix(500)))")
        }
        #endif

        // Try paginated format: {"success": true, "data": {"content": [...], ...}}
        do {
            let paginatedResponse = try JSONDecoder().decode(PaginatedResponse<T>.self, from: data)
            if let pageData = paginatedResponse.data {
                print("✅ Decoded as paginated response with \(pageData.content.count) items")
                return pageData.content
            }
        } catch {
            print("⚠️ Paginated decode failed for \(T.self): \(error)")
        }

        // Try array-in-data format: {"success": true, "data": [...]}
        do {
            let apiResponse = try JSONDecoder().decode(APIResponse<[T]>.self, from: data)
            if let items = apiResponse.data {
                print("✅ Decoded as array-in-data with \(items.count) items")
                return items
            }
        } catch {
            print("⚠️ Array-in-data decode failed for \(T.self): \(error)")
        }

        // Fallback: try direct array decode
        print("⚠️ Falling back to direct array decode for \(T.self)")
        return try JSONDecoder().decode([T].self, from: data)
    }

    // MARK: - Paginated GET

    private func getPaginated<T: Decodable>(path: String) async throws -> [T] {
        let (data, statusCode) = try await performRequest(
            method: "GET",
            path: path,
            body: nil
        )

        if statusCode == 401 {
            try await authService.refreshAccessToken()
            let (retryData, retryStatusCode) = try await performRequest(
                method: "GET",
                path: path,
                body: nil
            )
            return try decodePaginatedResponse(retryData, statusCode: retryStatusCode)
        }

        return try decodePaginatedResponse(data, statusCode: statusCode)
    }

    // MARK: - Transfers

    func listTransfers(
        direction: String? = nil,
        page: Int? = nil,
        size: Int? = nil,
        status: String? = nil
    ) async throws -> [Transfer] {
        // Dashboard list endpoint. The backend returns the full dictionary
        // grouped by direction and ignores query parameters, so we request
        // once and slice client-side.
        let response: TransferListResponse = try await get(path: "/transport/api/transfers")

        // Start from the selected group (or every group when no direction is
        // specified). Intentionally scopes to one key so the HUB tab doesn't
        // show OUTGOING or TEMPLATE_OUTGOING rows.
        var result: [Transfer]
        if let direction = direction {
            result = response.transfers(inGroup: direction)
        } else {
            result = response.allTransfers
        }

        // Apply status filter client-side (comma-separated allowed).
        if let status = status, !status.isEmpty {
            let allowed = Set(status.split(separator: ",").map { String($0).uppercased() })
            result = result.filter { allowed.contains($0.status.uppercased()) }
        }

        // Simulate pagination over the client-side slice so the caller's
        // pagination state continues to make sense.
        if let page = page, let size = size, size > 0 {
            let start = page * size
            if start >= result.count {
                return []
            }
            let end = min(start + size, result.count)
            result = Array(result[start..<end])
        }

        return result
    }

    // MCP: GET /api/v1/transport/{id}  (no /transfers/ segment)
    func getTransfer(id: Int) async throws -> Transfer {
        try await get(path: "/api/v1/transport/\(id)")
    }

    // MCP: POST /api/v1/transport/{id}/status  (POST, not PUT)
    func updateTransferStatus(id: Int, status: String) async throws -> Transfer {
        struct StatusRequest: Encodable {
            let status: String
        }
        return try await post(path: "/api/v1/transport/\(id)/status", body: StatusRequest(status: status))
    }

    // MCP: POST /api/v1/transport/{id}/stage-package
    func stagePackage(transferId: Int, packageLabel: String) async throws -> Package {
        struct StageRequest: Encodable {
            let packageLabel: String
        }
        return try await post(path: "/api/v1/transport/\(transferId)/stage-package", body: StageRequest(packageLabel: packageLabel))
    }

    // MCP: POST /api/v1/transport/{id}/assign-route  (POST, not PUT)
    func assignRoute(transferId: Int, routeId: Int) async throws -> Transfer {
        struct AssignRequest: Encodable {
            let routeId: Int
        }
        return try await post(path: "/api/v1/transport/\(transferId)/assign-route", body: AssignRequest(routeId: routeId))
    }

    // MCP: GET /api/v1/transport/{id}/packages  (no /transfers/ segment)
    func getTransferPackages(transferId: Int) async throws -> [Package] {
        try await getPaginated(path: "/api/v1/transport/\(transferId)/packages")
    }

    // MCP: GET /api/v1/transport/scan-package?label={barcode}  (query param, not path)
    func scanPackage(barcode: String) async throws -> Package {
        try await get(path: "/api/v1/transport/scan-package?label=\(barcode)")
    }

    // MARK: - Sessions

    func createSession(type: String) async throws -> Session {
        struct CreateSessionRequest: Encodable {
            let sessionType: String
        }
        return try await post(path: "/api/v1/transport/sessions", body: CreateSessionRequest(sessionType: type))
    }

    func listSessions() async throws -> [Session] {
        try await getPaginated(path: "/api/v1/transport/sessions")
    }

    func getSession(uuid: String) async throws -> Session {
        try await get(path: "/api/v1/transport/sessions/\(uuid)")
    }

    func updateSession(uuid: String, config: SessionUpdateRequest) async throws -> Session {
        try await put(path: "/api/v1/transport/sessions/\(uuid)", body: config)
    }

    func deleteSession(uuid: String) async throws {
        try await delete(path: "/api/v1/transport/sessions/\(uuid)")
    }

    func addPackageToSession(uuid: String, packageTag: String) async throws -> Session {
        struct AddPackageRequest: Encodable {
            let packageTag: String
        }
        return try await post(path: "/api/v1/transport/sessions/\(uuid)/package", body: AddPackageRequest(packageTag: packageTag))
    }

    func bulkAddPackages(uuid: String, packageTags: [String]) async throws -> Session {
        struct BulkAddRequest: Encodable {
            let packageTags: [String]
        }
        return try await post(path: "/api/v1/transport/sessions/\(uuid)/packages/bulk", body: BulkAddRequest(packageTags: packageTags))
    }

    @discardableResult
    func removePackageFromSession(uuid: String, packageLabel: String) async throws -> Session {
        try await delete(path: "/api/v1/transport/sessions/\(uuid)/package/\(packageLabel)")
        return try await getSession(uuid: uuid)
    }

    func submitSession(uuid: String) async throws -> Session {
        return try await post(path: "/api/v1/transport/sessions/\(uuid)/submit", body: nil)
    }

    // MARK: - Pickup Scan

    func listPickupTransfers() async throws -> [Transfer] {
        // Returns a flat array under `transfers`, not the dashboard's grouped
        // dictionary. See FlatTransferListResponse for the shape.
        let response: FlatTransferListResponse = try await get(path: "/transport/pickup/api/transfers")
        return response.transfers ?? []
    }

    /// Start or resume a pickup scan session.
    /// Backend path is SINGULAR "session" and ends in "/start" — not
    /// POST /sessions as earlier versions of this client assumed.
    /// Response is wrapped as {success, session: {...}, resumed}.
    func startPickupSession(transferId: Int) async throws -> ScanSessionSummary {
        struct StartSessionRequest: Encodable { let transferId: Int }
        let envelope: ScanSessionEnvelope = try await post(
            path: "/transport/pickup/api/session/start",
            body: StartSessionRequest(transferId: transferId)
        )
        guard let session = envelope.session else {
            throw APIError.serverError(envelope.error ?? "Failed to start pickup session")
        }
        return session
    }

    /// Scan a package label into a pickup session. Backend returns a flat
    /// {success, packageLabel, productName, scannedCount, totalPackages,
    /// allScanned} envelope — we only surface success/error since the VM
    /// tracks local progress off its own ScanSession state.
    func scanPickupPackage(sessionId: Int, packageLabel: String) async throws {
        struct ScanRequest: Encodable { let packageLabel: String }
        struct ScanResponse: Decodable {
            let success: Bool
            let error: String?
            let alreadyScanned: Bool?
        }
        let response: ScanResponse = try await post(
            path: "/transport/pickup/api/session/\(sessionId)/scan",
            body: ScanRequest(packageLabel: packageLabel)
        )
        if !response.success {
            throw APIError.serverError(response.error ?? "Scan rejected")
        }
    }

    /// Undo a scan. Backend uses POST /unscan with a body, not DELETE.
    func unscanPickupPackage(sessionId: Int, packageLabel: String) async throws {
        struct UnscanRequest: Encodable { let packageLabel: String }
        struct UnscanResponse: Decodable {
            let success: Bool
            let error: String?
        }
        let response: UnscanResponse = try await post(
            path: "/transport/pickup/api/session/\(sessionId)/unscan",
            body: UnscanRequest(packageLabel: packageLabel)
        )
        if !response.success {
            throw APIError.serverError(response.error ?? "Unscan rejected")
        }
    }

    @discardableResult
    func completePickup(sessionId: Int) async throws -> ScanSessionSummary {
        let envelope: ScanSessionEnvelope = try await post(
            path: "/transport/pickup/api/session/\(sessionId)/complete",
            body: nil
        )
        guard let session = envelope.session else {
            throw APIError.serverError(envelope.error ?? "Failed to complete pickup")
        }
        return session
    }

    // MARK: - Delivery Scan

    func listDeliveryTransfers() async throws -> [Transfer] {
        // Same flat-array shape as the pickup list — not the grouped
        // dashboard dictionary.
        let response: FlatTransferListResponse = try await get(path: "/transport/delivery/api/transfers")
        return response.transfers ?? []
    }

    /// Start or resume a delivery handoff session. Same shape as pickup
    /// (singular "session", envelope wrapper). `resumed` flips to true when
    /// the backend found an IN_PROGRESS session for the same transfer and
    /// returned that instead of creating a new one — callers should then
    /// fetch getDeliverySession() to rehydrate scan state.
    func startDeliverySession(transferId: Int) async throws -> (session: ScanSessionSummary, resumed: Bool) {
        struct StartSessionRequest: Encodable { let transferId: Int }
        let envelope: ScanSessionEnvelope = try await post(
            path: "/transport/delivery/api/session/start",
            body: StartSessionRequest(transferId: transferId)
        )
        guard let session = envelope.session else {
            throw APIError.serverError(envelope.error ?? "Failed to start delivery session")
        }
        return (session, envelope.resumed ?? false)
    }

    /// Load the unified session + package-scan state. Use after a
    /// resumed start so the local ScanSession matches whatever the driver
    /// already scanned on another device / before backing out.
    func getDeliverySession(sessionId: Int) async throws -> DeliverySessionDetail.SessionWithPackages {
        let response: DeliverySessionDetail = try await get(
            path: "/transport/delivery/api/session/\(sessionId)"
        )
        guard let session = response.session else {
            throw APIError.serverError(response.error ?? "Failed to load delivery session")
        }
        return session
    }

    func scanDeliveryPackage(sessionId: Int, packageLabel: String) async throws {
        struct ScanRequest: Encodable { let packageLabel: String }
        struct ScanResponse: Decodable {
            let success: Bool
            let error: String?
            let alreadyScanned: Bool?
        }
        let response: ScanResponse = try await post(
            path: "/transport/delivery/api/session/\(sessionId)/scan",
            body: ScanRequest(packageLabel: packageLabel)
        )
        if !response.success {
            throw APIError.serverError(response.error ?? "Scan rejected")
        }
    }

    func unscanDeliveryPackage(sessionId: Int, packageLabel: String) async throws {
        struct UnscanRequest: Encodable { let packageLabel: String }
        struct UnscanResponse: Decodable {
            let success: Bool
            let error: String?
        }
        let response: UnscanResponse = try await post(
            path: "/transport/delivery/api/session/\(sessionId)/unscan",
            body: UnscanRequest(packageLabel: packageLabel)
        )
        if !response.success {
            throw APIError.serverError(response.error ?? "Unscan rejected")
        }
    }

    @discardableResult
    func completeDelivery(sessionId: Int, signatureData: String, signerName: String) async throws -> ScanSessionSummary {
        struct CompleteRequest: Encodable {
            let signatureData: String
            let signerName: String
        }
        let envelope: ScanSessionEnvelope = try await post(
            path: "/transport/delivery/api/session/\(sessionId)/complete",
            body: CompleteRequest(signatureData: signatureData, signerName: signerName)
        )
        guard let session = envelope.session else {
            throw APIError.serverError(envelope.error ?? "Failed to complete delivery")
        }
        return session
    }

    // MARK: - GPS

    func submitGPSPing(_ ping: GPSPing) async throws -> GPSPingResponse {
        try await post(path: "/api/v1/transport/gps-ping", body: ping)
    }

    /// GPS history for a vehicle — backend path is `/transport/api/vehicles/{id}/pings`
    /// (served by TransportDashboardController). Returns a chronological list of pings.
    func getVehicleHistory(vehicleId: Int, from: String? = nil, to: String? = nil) async throws -> [GPSPing] {
        var path = "/transport/api/vehicles/\(vehicleId)/pings"
        var components = URLComponents()

        var queryItems: [URLQueryItem] = []
        if let from = from { queryItems.append(URLQueryItem(name: "from", value: from)) }
        if let to = to { queryItems.append(URLQueryItem(name: "to", value: to)) }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
            if let query = components.query {
                path += "?\(query)"
            }
        }

        return try await get(path: path)
    }

    /// Latest known position for a vehicle: last element of the pings history.
    func getVehicleLatest(vehicleId: Int) async throws -> GPSPing? {
        let history = try await getVehicleHistory(vehicleId: vehicleId)
        return history.last
    }

    func trackTransfer(transferId: Int) async throws -> TrackingEvent {
        try await get(path: "/api/v1/transport/tracking-events/\(transferId)")
    }

    // MARK: - Routes

    func listRoutes() async throws -> [Route] {
        try await getPaginated(path: "/api/v1/transport/routes")
    }

    func createRoute(name: String, description: String? = nil) async throws -> Route {
        struct CreateRouteRequest: Encodable {
            let name: String
            let description: String?
        }
        return try await post(path: "/api/v1/transport/routes", body: CreateRouteRequest(name: name, description: description))
    }

    func getRoute(id: Int) async throws -> Route {
        try await get(path: "/api/v1/transport/routes/\(id)")
    }

    func deleteRoute(id: Int) async throws {
        try await delete(path: "/api/v1/transport/routes/\(id)")
    }

    func addStop(routeId: Int, stop: RouteStopRequest) async throws -> Route {
        return try await post(path: "/api/v1/transport/routes/\(routeId)/stops", body: stop)
    }

    @discardableResult
    func removeStop(routeId: Int, stopId: Int) async throws -> Route {
        try await delete(path: "/api/v1/transport/routes/\(routeId)/stops/\(stopId)")
        return try await getRoute(id: routeId)
    }

    /// Geofence settings live in the Route entity itself; backend expects them
    /// inside the PUT /routes/{id} body (fields: geofencePolygonJson, bufferMeters).
    /// Callers should use `updateRoute` / the generic route PUT instead of a
    /// dedicated geofence endpoint — there is no `/routes/{id}/geofence` route.
    @available(*, deprecated, message: "No separate endpoint — include geofence fields in PUT /routes/{id}")
    func setGeofence(routeId: Int, config: GeofenceConfig) async throws -> Route {
        return try await post(path: "/api/v1/transport/routes/\(routeId)", body: config)
    }

    // MARK: - Zones
    //
    // Real backend paths live under `/transport/api/...` (ZoneController), NOT
    // `/api/v1/transport/zones`. Also: there is no flat list endpoint — zones
    // are scoped to a location (warehouse/hub).

    /// List zones in a location. Backend: GET /transport/api/location/{locationId}/zones.
    func listZones(locationId: Int) async throws -> [Zone] {
        try await get(path: "/transport/api/location/\(locationId)/zones")
    }

    func scanIntoZone(zoneId: Int, packageLabel: String, action: String) async throws -> Package {
        struct ScanRequest: Encodable {
            let packageLabel: String
            let action: String
        }
        return try await post(path: "/transport/api/zones/\(zoneId)/scan", body: ScanRequest(packageLabel: packageLabel, action: action))
    }

    func getZonePackages(zoneId: Int) async throws -> [Package] {
        try await get(path: "/transport/api/zones/\(zoneId)/packages")
    }

    func getZoneAudit(zoneId: Int) async throws -> [ZoneScanAudit] {
        try await get(path: "/transport/api/zones/\(zoneId)/audit")
    }

    // MARK: - Totes
    //
    // Real backend paths live under `/transport/tote/api/...` (ToteController).

    /// List totes for a transfer. Backend: GET /transport/tote/api/transfer/{transferId}/totes.
    func listTotes(transferId: Int) async throws -> [Tote] {
        try await get(path: "/transport/tote/api/transfer/\(transferId)/totes")
    }

    /// Add a package to a tote by scanning. Backend: POST /transport/tote/api/totes/{id}/scan.
    func addPackageToTote(toteId: Int, packageLabel: String) async throws -> Tote {
        struct AddPackageRequest: Encodable {
            let packageLabel: String
        }
        return try await post(path: "/transport/tote/api/totes/\(toteId)/scan", body: AddPackageRequest(packageLabel: packageLabel))
    }

    func getTotePackages(toteId: Int) async throws -> [Package] {
        try await get(path: "/transport/tote/api/totes/\(toteId)/packages")
    }

    func getTote(toteId: Int) async throws -> Tote {
        try await get(path: "/transport/tote/api/totes/\(toteId)")
    }

    // MARK: - Reference Data

    func listDrivers() async throws -> [Driver] {
        try await getPaginated(path: "/api/v1/transport/drivers")
    }

    func listVehicles() async throws -> [Vehicle] {
        try await getPaginated(path: "/api/v1/transport/vehicles")
    }

    func listDestinations() async throws -> [Destination] {
        try await getPaginated(path: "/api/v1/transport/destinations")
    }

    func listTransporters() async throws -> [Transporter] {
        try await getPaginated(path: "/api/v1/transport/transporters")
    }

    func listTransferTypes() async throws -> [TransferType] {
        try await getPaginated(path: "/api/v1/transport/transfer-types")
    }

    // MARK: - Tracking (Public)
    //
    // PublicTransferTrackingController reads transferId from either a query
    // param (GET) or the JSON body (POST) — never from the path. Field names
    // on the ping body are lat/lon (the backend does not accept lng).

    func getTrackingStatus(transferId: Int) async throws -> PublicTrackingStatus {
        try await get(path: "/public/transfer/track/status?transferId=\(transferId)")
    }

    func getTrackingDetails(transferId: Int) async throws -> PublicTrackingDetails {
        try await get(path: "/public/transfer/track/details?transferId=\(transferId)")
    }

    func departTransfer(transferId: Int) async throws -> TrackingActionResponse {
        struct DepartRequest: Encodable { let transferId: Int }
        return try await post(
            path: "/public/transfer/track/depart",
            body: DepartRequest(transferId: transferId)
        )
    }

    func markDelivered(transferId: Int) async throws -> TrackingActionResponse {
        struct DeliveredRequest: Encodable { let transferId: Int }
        return try await post(
            path: "/public/transfer/track/mark-delivered",
            body: DeliveredRequest(transferId: transferId)
        )
    }

    func pingLocation(transferId: Int, lat: Double, lon: Double) async throws -> TrackingActionResponse {
        struct PingRequest: Encodable {
            let transferId: Int
            let lat: Double
            let lon: Double
        }
        return try await post(
            path: "/public/transfer/track/ping",
            body: PingRequest(transferId: transferId, lat: lat, lon: lon)
        )
    }

    // MARK: - Action Log

    func listActionLog(actionType: String? = nil, page: Int? = nil, size: Int? = nil) async throws -> [ActionLog] {
        // MCP: GET /api/v1/transport/action-log
        var path = "/api/v1/transport/action-log"
        var components = URLComponents()

        var queryItems: [URLQueryItem] = []
        if let actionType = actionType { queryItems.append(URLQueryItem(name: "actionType", value: actionType)) }
        if let page = page { queryItems.append(URLQueryItem(name: "page", value: String(page))) }
        if let size = size { queryItems.append(URLQueryItem(name: "size", value: String(size))) }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
            if let query = components.query {
                path += "?\(query)"
            }
        }

        return try await getPaginated(path: path)
    }

    func getTransferActions(transferId: Int) async throws -> [ActionLog] {
        // Action log by transfer — not a confirmed v1 endpoint; using action-log with filter
        try await getPaginated(path: "/api/v1/transport/action-log?transferId=\(transferId)")
    }

    // MARK: - Package Media
    //
    // Backend PackageMediaController lives at /transport/pkg-media/**. Media is
    // keyed by METRC package LABEL (string), not package id.

    func getPackageMedia(packageLabel: String) async throws -> [PackageMedia] {
        let encoded = packageLabel.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? packageLabel
        return try await get(path: "/transport/pkg-media/api/\(encoded)/info")
    }

    func uploadPackageMedia(packageLabel: String, imageData: Data, filename: String) async throws -> PackageMedia {
        let encoded = packageLabel.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? packageLabel
        guard let url = URL(string: baseURL + "/transport/pkg-media/api/\(encoded)/upload") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        if let token = authService.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        // Unwrap API response envelope
        if let apiResponse = try? JSONDecoder().decode(APIResponse<PackageMedia>.self, from: data),
           let mediaData = apiResponse.data {
            return mediaData
        }
        return try JSONDecoder().decode(PackageMedia.self, from: data)
    }

    // MARK: - Demo Mode
    //
    // Backend:
    //   GET  /api/v1/transport/demo/status  — public, just { success, demoMode }
    //   POST /api/v1/transport/demo/toggle?enabled=<bool>
    //        — admin/manager/super-admin only; creates or wipes DEMO-0000001
    //          and its 5 synthetic packages
    //
    // Demo mode is an **account-global** flag: flipping it on affects every
    // user of this backend, and flipping it off cascade-deletes all demo
    // artifacts. The iOS UI wraps this in a confirm sheet before disable.

    func getDemoStatus() async throws -> Bool {
        let response: DemoStatusResult = try await get(path: "/api/v1/transport/demo/status")
        return response.demoMode
    }

    @discardableResult
    func setDemoMode(enabled: Bool) async throws -> DemoToggleResult {
        // The backend reads the flag from a query parameter on a POST — no
        // request body. Empty-body POST is what the dashboard JS does too.
        let result: DemoToggleResult = try await post(
            path: "/api/v1/transport/demo/toggle?enabled=\(enabled)",
            body: nil
        )
        if !result.success {
            throw APIError.serverError(result.error ?? "Demo toggle failed")
        }
        return result
    }

    // MARK: - Hub Intake
    //
    // End-to-end flow:
    //   1. hubAcceptTransfer(id) — opens intake without changing status
    //   2. createHubIntakeSession(...) — creates or resumes IN_PROGRESS session
    //   3. scanIntoZone(...) for each package — existing zone-scan endpoint
    //   4. getHubIntakeSession(id) — polls assignedCount for progress
    //   5. completeHubIntakeSession(id) — auto-advances transfer to AT_HUB
    //      when all packages are in STANDARD zones
    //   6. abandonHubIntakeSession(id) — aborts

    /// List available locations (warehouses/hubs) so the intake flow can
    /// target the correct facility. Backend: GET /transport/api/locations.
    func listLocations() async throws -> [Location] {
        struct LocationsEnvelope: Decodable {
            let success: Bool?
            let locations: [Location]?
        }
        let envelope: LocationsEnvelope = try await get(path: "/transport/api/locations")
        return envelope.locations ?? []
    }

    /// Pre-flight check before starting hub intake. Backend enforces that the
    /// transfer is IN_TRANSIT and has packages; returns an error string if not.
    /// Backend: POST /transport/api/transfers/{id}/hub-accept.
    @discardableResult
    func hubAcceptTransfer(transferId: Int) async throws -> Bool {
        struct HubAcceptResponse: Decodable {
            let success: Bool
            let message: String?
            let error: String?
        }
        let response: HubAcceptResponse = try await post(
            path: "/transport/api/transfers/\(transferId)/hub-accept",
            body: nil
        )
        if !response.success, let err = response.error {
            throw APIError.serverError(err)
        }
        return response.success
    }

    /// Create or resume an IN_PROGRESS hub intake session for a transfer.
    /// When a session already exists for the transfer, backend returns the
    /// existing one with `resumed: true`. Backend: POST /transport/api/hub-intake/session.
    func createHubIntakeSession(
        transferId: Int,
        transferManifestNumber: String?,
        shipperName: String?,
        receiverName: String?,
        totalPackages: Int,
        locationId: Int?,
        locationName: String?
    ) async throws -> (session: HubIntakeSession, resumed: Bool) {
        struct CreateRequest: Encodable {
            let transferId: Int
            let transferManifestNumber: String?
            let shipperName: String?
            let receiverName: String?
            let totalPackages: Int
            let locationId: Int?
            let locationName: String?
        }
        struct SessionEnvelope: Decodable {
            let success: Bool
            let session: HubIntakeSession?
            let resumed: Bool?
            let error: String?
        }
        let body = CreateRequest(
            transferId: transferId,
            transferManifestNumber: transferManifestNumber,
            shipperName: shipperName,
            receiverName: receiverName,
            totalPackages: totalPackages,
            locationId: locationId,
            locationName: locationName
        )
        let response: SessionEnvelope = try await post(path: "/transport/api/hub-intake/session", body: body)
        guard response.success, let session = response.session else {
            throw APIError.serverError(response.error ?? "Could not create hub intake session")
        }
        return (session, response.resumed ?? false)
    }

    /// Refresh a hub intake session from the server — the response includes
    /// assignedCount (packages in hub zones so far) which drives the progress bar.
    /// Backend: GET /transport/api/hub-intake/session/{id}.
    func getHubIntakeSession(id: Int) async throws -> HubIntakeSession {
        struct SessionEnvelope: Decodable {
            let success: Bool
            let session: HubIntakeSession?
            let error: String?
        }
        let response: SessionEnvelope = try await get(path: "/transport/api/hub-intake/session/\(id)")
        guard response.success, let session = response.session else {
            throw APIError.serverError(response.error ?? "Session not found")
        }
        return session
    }

    /// List all IN_PROGRESS sessions across the account.
    /// Backend: GET /transport/api/hub-intake/sessions.
    func listHubIntakeSessions() async throws -> [HubIntakeSession] {
        struct SessionsEnvelope: Decodable {
            let success: Bool?
            let sessions: [HubIntakeSession]?
        }
        let response: SessionsEnvelope = try await get(path: "/transport/api/hub-intake/sessions")
        return response.sessions ?? []
    }

    /// Mark a session COMPLETE. Server auto-advances the transfer to AT_HUB
    /// when all packages are in STANDARD zones. Return value indicates whether
    /// the status advance actually happened.
    /// Backend: PUT /transport/api/hub-intake/session/{id}/complete.
    @discardableResult
    func completeHubIntakeSession(id: Int) async throws -> Bool {
        struct CompleteResponse: Decodable {
            let success: Bool
            let statusAdvanced: Bool?
            let error: String?
        }
        let response: CompleteResponse = try await put(
            path: "/transport/api/hub-intake/session/\(id)/complete",
            body: nil
        )
        if !response.success {
            throw APIError.serverError(response.error ?? "Failed to complete session")
        }
        return response.statusAdvanced ?? false
    }

    /// Abort a session without completing it. Abandoned sessions can later be
    /// re-created from scratch if needed.
    /// Backend: PUT /transport/api/hub-intake/session/{id}/abandon.
    @discardableResult
    func abandonHubIntakeSession(id: Int) async throws -> Bool {
        struct AbandonResponse: Decodable {
            let success: Bool
            let error: String?
        }
        let response: AbandonResponse = try await put(
            path: "/transport/api/hub-intake/session/\(id)/abandon",
            body: nil
        )
        return response.success
    }

    // MARK: - Package Browse / Search
    //
    // Both browse and search live on the dashboard controller and return
    // JSON envelopes of the form { success, packages: [...] }. Field names
    // differ slightly between the two, so we decode into a common shape.

    /// Full inventory for the active license (or a given one). Backend:
    /// GET /transport/api/packages/browse?licenseNumber=&allowNotSubmitted=
    func browsePackages(licenseNumber: String? = nil, allowNotSubmitted: Bool = false) async throws -> [BrowsablePackage] {
        var path = "/transport/api/packages/browse?allowNotSubmitted=\(allowNotSubmitted)"
        if let licenseNumber = licenseNumber, !licenseNumber.isEmpty {
            let encoded = licenseNumber.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? licenseNumber
            path += "&licenseNumber=\(encoded)"
        }
        struct BrowseEnvelope: Decodable {
            let success: Bool?
            let packages: [BrowsablePackage.BrowseShape]?
        }
        let envelope: BrowseEnvelope = try await get(path: path)
        return (envelope.packages ?? []).map { $0.normalized }
    }

    /// Free-text search. Minimum 2 characters, max 20 results. Backend:
    /// GET /transport/api/search-packages?q=&licenseNumber=&includeNotSubmitted=
    func searchPackages(query: String, licenseNumber: String? = nil, includeNotSubmitted: Bool = false) async throws -> [BrowsablePackage] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }
        let encodedQuery = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        var path = "/transport/api/search-packages?q=\(encodedQuery)&includeNotSubmitted=\(includeNotSubmitted)"
        if let licenseNumber = licenseNumber, !licenseNumber.isEmpty {
            let encodedLicense = licenseNumber.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? licenseNumber
            path += "&licenseNumber=\(encodedLicense)"
        }
        struct SearchEnvelope: Decodable {
            let success: Bool?
            let packages: [BrowsablePackage.SearchShape]?
        }
        let envelope: SearchEnvelope = try await get(path: path)
        return (envelope.packages ?? []).map { $0.normalized }
    }

    // MARK: - Session from Template (duplicate transfer)

    /// Create a new editable session seeded from an existing transfer's
    /// shipper/recipient/vehicle/driver fields + full package list.
    /// Backend: POST /transport/api/sessions/from-template/{transferId}.
    @discardableResult
    func duplicateTransferAsSession(transferId: Int) async throws -> TransportSession {
        return try await post(
            path: "/transport/api/sessions/from-template/\(transferId)",
            body: nil
        )
    }

    // MARK: - Manifest PDF

    /// Download the METRC manifest PDF for a transfer. Returns raw bytes suitable
    /// for writing to disk / sharing via UIActivityViewController.
    /// Backend: GET /transport/api/transfers/{id}/pdf.
    func downloadManifestPDF(transferId: Int) async throws -> Data {
        guard let url = URL(string: baseURL + "/transport/api/transfers/\(transferId)/pdf") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        if let token = authService.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    // MARK: - Messaging (chat)
    //
    // Backend: POST /transport/api/messages/batch — used for both fetching and
    // posting messages. Single source of truth for per-transfer threads.

    func loadMessages(transferId: Int, since: String? = nil) async throws -> [ChatMessage] {
        struct MessagesRequest: Encodable {
            let transferIds: [Int]
            let since: String?
            let includeMessages: Bool
        }
        struct MessagesResponse: Decodable {
            let messages: [Int: [ChatMessage]]?
        }
        let body = MessagesRequest(transferIds: [transferId], since: since, includeMessages: true)
        let response: MessagesResponse = try await post(path: "/transport/api/messages/batch", body: body)
        return response.messages?[transferId] ?? []
    }

    func postMessage(transferId: Int, text: String, sender: String) async throws -> ChatMessage {
        struct PostMessageRequest: Encodable {
            let transferId: Int
            let message: String
            let sender: String
        }
        return try await post(
            path: "/transport/api/messages/batch",
            body: PostMessageRequest(transferId: transferId, message: text, sender: sender)
        )
    }

    /// Batched unread-message counts for the dashboard badge row. Backend
    /// returns a map keyed by transferId.
    func batchMessageCounts(transferIds: [Int]) async throws -> [Int: Int] {
        guard !transferIds.isEmpty else { return [:] }
        struct CountsRequest: Encodable {
            let transferIds: [Int]
            let includeMessages: Bool
        }
        struct CountsResponse: Decodable {
            let counts: [String: Int]?
        }
        let body = CountsRequest(transferIds: transferIds, includeMessages: false)
        let response: CountsResponse = try await post(path: "/transport/api/messages/batch", body: body)
        var result: [Int: Int] = [:]
        for (k, v) in response.counts ?? [:] {
            if let id = Int(k) { result[id] = v }
        }
        return result
    }
}
