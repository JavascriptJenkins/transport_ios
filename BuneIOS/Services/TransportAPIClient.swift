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

    private let baseURL = "https://haven.bunepos.com"
    private let apiKey = Config.apiKey
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

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        return (data, httpResponse.statusCode)
    }

    private func decodeResponse<T: Decodable>(_ data: Data, statusCode: Int) throws -> T {
        guard (200...299).contains(statusCode) else {
            // Try to extract error message from API response
            if let errorResponse = try? JSONDecoder().decode(APIResponse<EmptyData>.self, from: data),
               let errorMsg = errorResponse.error {
                throw APIError.serverError(errorMsg)
            }
            throw URLError(.badServerResponse)
        }

        // Try to unwrap APIResponse<T> envelope first
        if let apiResponse = try? JSONDecoder().decode(APIResponse<T>.self, from: data) {
            if let responseData = apiResponse.data {
                return responseData
            } else if let error = apiResponse.error {
                throw APIError.serverError(error)
            }
        }

        // Fallback: try direct decode (for endpoints that don't use the wrapper)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Decode a paginated API response, extracting the content array from the envelope
    private func decodePaginatedResponse<T: Decodable>(_ data: Data, statusCode: Int) throws -> [T] {
        guard (200...299).contains(statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(APIResponse<EmptyData>.self, from: data),
               let errorMsg = errorResponse.error {
                throw APIError.serverError(errorMsg)
            }
            throw URLError(.badServerResponse)
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
        var path = "/transport/api/transfers"
        var components = URLComponents()

        var queryItems: [URLQueryItem] = []
        if let direction = direction { queryItems.append(URLQueryItem(name: "direction", value: direction)) }
        if let page = page { queryItems.append(URLQueryItem(name: "page", value: String(page))) }
        if let size = size { queryItems.append(URLQueryItem(name: "size", value: String(size))) }
        if let status = status { queryItems.append(URLQueryItem(name: "status", value: status)) }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
            if let query = components.query {
                path += "?\(query)"
            }
        }

        let response: TransferListResponse = try await get(path: path)
        return response.allTransfers
    }

    func getTransfer(id: Int) async throws -> Transfer {
        try await get(path: "/transport/api/transfers/\(id)")
    }

    func updateTransferStatus(id: Int, status: String) async throws -> Transfer {
        struct StatusRequest: Encodable {
            let status: String
        }
        return try await put(path: "/transport/api/transfers/\(id)/status", body: StatusRequest(status: status))
    }

    func stagePackage(transferId: Int, packageLabel: String) async throws -> Package {
        struct StageRequest: Encodable {
            let packageLabel: String
        }
        return try await post(path: "/transport/api/transfers/\(transferId)/stage", body: StageRequest(packageLabel: packageLabel))
    }

    func assignRoute(transferId: Int, routeId: Int) async throws -> Transfer {
        struct AssignRequest: Encodable {
            let routeId: Int
        }
        return try await put(path: "/transport/api/transfers/\(transferId)/route", body: AssignRequest(routeId: routeId))
    }

    func getTransferPackages(transferId: Int) async throws -> [Package] {
        try await getPaginated(path: "/transport/api/transfers/\(transferId)/packages")
    }

    func scanPackage(barcode: String) async throws -> Package {
        struct ScanRequest: Encodable {
            let barcode: String
        }
        return try await post(path: "/transport/api/packages/scan", body: ScanRequest(barcode: barcode))
    }

    // MARK: - Sessions

    func createSession(type: String) async throws -> Session {
        struct CreateSessionRequest: Encodable {
            let type: String
        }
        return try await post(path: "/transport/api/sessions", body: CreateSessionRequest(type: type))
    }

    func listSessions() async throws -> [Session] {
        try await getPaginated(path: "/transport/api/sessions")
    }

    func getSession(uuid: String) async throws -> Session {
        try await get(path: "/transport/api/sessions/\(uuid)")
    }

    func updateSession(uuid: String, config: SessionUpdateRequest) async throws -> Session {
        try await put(path: "/transport/api/sessions/\(uuid)", body: config)
    }

    func deleteSession(uuid: String) async throws {
        try await delete(path: "/transport/api/sessions/\(uuid)")
    }

    func addPackageToSession(uuid: String, packageTag: String) async throws -> Session {
        struct AddPackageRequest: Encodable {
            let packageTag: String
        }
        return try await post(path: "/transport/api/sessions/\(uuid)/packages", body: AddPackageRequest(packageTag: packageTag))
    }

    func bulkAddPackages(uuid: String, packageTags: [String]) async throws -> Session {
        struct BulkAddRequest: Encodable {
            let packageTags: [String]
        }
        return try await post(path: "/transport/api/sessions/\(uuid)/packages/bulk", body: BulkAddRequest(packageTags: packageTags))
    }

    @discardableResult
    func removePackageFromSession(uuid: String, packageLabel: String) async throws -> Session {
        try await delete(path: "/transport/api/sessions/\(uuid)/packages/\(packageLabel)")
        return try await getSession(uuid: uuid)
    }

    func submitSession(uuid: String) async throws -> Session {
        return try await post(path: "/transport/api/sessions/\(uuid)/submit", body: nil)
    }

    // MARK: - Pickup Scan

    func listPickupTransfers() async throws -> [Transfer] {
        let response: TransferListResponse = try await get(path: "/transport/pickup/api/transfers")
        return response.allTransfers
    }

    func startPickupSession(transferId: Int) async throws -> Session {
        struct StartSessionRequest: Encodable {
            let transferId: Int
        }
        return try await post(path: "/transport/pickup/api/sessions", body: StartSessionRequest(transferId: transferId))
    }

    func scanPickupPackage(sessionId: String, packageLabel: String) async throws -> Package {
        struct ScanRequest: Encodable {
            let packageLabel: String
        }
        return try await post(path: "/transport/pickup/api/sessions/\(sessionId)/scan", body: ScanRequest(packageLabel: packageLabel))
    }

    @discardableResult
    func unscanPickupPackage(sessionId: String, packageLabel: String) async throws -> Package {
        try await delete(path: "/transport/pickup/api/sessions/\(sessionId)/scan/\(packageLabel)")
        return try await scanPackage(barcode: packageLabel)
    }

    func completePickup(sessionId: String) async throws -> Session {
        return try await post(path: "/transport/pickup/api/sessions/\(sessionId)/complete", body: nil)
    }

    // MARK: - Delivery Scan

    func listDeliveryTransfers() async throws -> [Transfer] {
        let response: TransferListResponse = try await get(path: "/transport/delivery/api/transfers")
        return response.allTransfers
    }

    func startDeliverySession(transferId: Int) async throws -> Session {
        struct StartSessionRequest: Encodable {
            let transferId: Int
        }
        return try await post(path: "/transport/delivery/api/sessions", body: StartSessionRequest(transferId: transferId))
    }

    func scanDeliveryPackage(sessionId: String, packageLabel: String) async throws -> Package {
        struct ScanRequest: Encodable {
            let packageLabel: String
        }
        return try await post(path: "/transport/delivery/api/sessions/\(sessionId)/scan", body: ScanRequest(packageLabel: packageLabel))
    }

    @discardableResult
    func unscanDeliveryPackage(sessionId: String, packageLabel: String) async throws -> Package {
        try await delete(path: "/transport/delivery/api/sessions/\(sessionId)/scan/\(packageLabel)")
        return try await scanPackage(barcode: packageLabel)
    }

    func completeDelivery(sessionId: String, signatureData: String, signerName: String) async throws -> Session {
        struct CompleteRequest: Encodable {
            let signatureData: String
            let signerName: String
        }
        return try await post(path: "/transport/delivery/api/sessions/\(sessionId)/complete", body: CompleteRequest(signatureData: signatureData, signerName: signerName))
    }

    // MARK: - GPS

    func submitGPSPing(_ ping: GPSPing) async throws -> GPSPingResponse {
        try await post(path: "/transport/api/gps/ping", body: ping)
    }

    func getVehicleHistory(vehicleId: Int, from: String? = nil, to: String? = nil) async throws -> [GPSPing] {
        var path = "/transport/api/gps/vehicles/\(vehicleId)/history"
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

    func getVehicleLatest(vehicleId: Int) async throws -> GPSPing {
        try await get(path: "/transport/api/gps/vehicles/\(vehicleId)/latest")
    }

    func trackTransfer(transferId: Int) async throws -> TrackingEvent {
        try await get(path: "/transport/api/transfers/\(transferId)/track")
    }

    // MARK: - Routes

    func listRoutes() async throws -> [Route] {
        try await getPaginated(path: "/transport/api/routes")
    }

    func createRoute(name: String, description: String? = nil) async throws -> Route {
        struct CreateRouteRequest: Encodable {
            let name: String
            let description: String?
        }
        return try await post(path: "/transport/api/routes", body: CreateRouteRequest(name: name, description: description))
    }

    func getRoute(id: Int) async throws -> Route {
        try await get(path: "/transport/api/routes/\(id)")
    }

    func deleteRoute(id: Int) async throws {
        try await delete(path: "/transport/api/routes/\(id)")
    }

    func addStop(routeId: Int, stop: RouteStopRequest) async throws -> Route {
        return try await post(path: "/transport/api/routes/\(routeId)/stops", body: stop)
    }

    @discardableResult
    func removeStop(routeId: Int, stopId: Int) async throws -> Route {
        try await delete(path: "/transport/api/routes/\(routeId)/stops/\(stopId)")
        return try await getRoute(id: routeId)
    }

    func setGeofence(routeId: Int, config: GeofenceConfig) async throws -> Route {
        return try await post(path: "/transport/api/routes/\(routeId)/geofence", body: config)
    }

    // MARK: - Zones

    func listZones() async throws -> [Zone] {
        try await getPaginated(path: "/transport/api/zones")
    }

    func getZone(id: Int) async throws -> Zone {
        try await get(path: "/transport/api/zones/\(id)")
    }

    func scanIntoZone(zoneId: Int, packageLabel: String, action: String) async throws -> Package {
        struct ScanRequest: Encodable {
            let packageLabel: String
            let action: String
        }
        return try await post(path: "/transport/api/zones/\(zoneId)/scan", body: ScanRequest(packageLabel: packageLabel, action: action))
    }

    func getZonePackages(zoneId: Int) async throws -> [Package] {
        try await getPaginated(path: "/transport/api/zones/\(zoneId)/packages")
    }

    func getZoneAudit(zoneId: Int) async throws -> [ZoneScanAudit] {
        try await getPaginated(path: "/transport/api/zones/\(zoneId)/audit")
    }

    // MARK: - Totes

    func listTotes() async throws -> [Tote] {
        try await getPaginated(path: "/transport/api/totes")
    }

    func addPackageToTote(toteId: Int, packageLabel: String) async throws -> Tote {
        struct AddPackageRequest: Encodable {
            let packageLabel: String
        }
        return try await post(path: "/transport/api/totes/\(toteId)/packages", body: AddPackageRequest(packageLabel: packageLabel))
    }

    @discardableResult
    func removePackageFromTote(toteId: Int, packageId: Int) async throws -> Tote {
        try await delete(path: "/transport/api/totes/\(toteId)/packages/\(packageId)")
        return try await get(path: "/transport/api/totes/\(toteId)")
    }

    // MARK: - Reference Data

    func listDrivers() async throws -> [Driver] {
        try await getPaginated(path: "/transport/api/reference/drivers")
    }

    func listVehicles() async throws -> [Vehicle] {
        try await getPaginated(path: "/transport/api/reference/vehicles")
    }

    func listDestinations() async throws -> [Destination] {
        try await getPaginated(path: "/transport/api/reference/destinations")
    }

    func listTransporters() async throws -> [Transporter] {
        try await getPaginated(path: "/transport/api/reference/transporters")
    }

    func listTransferTypes() async throws -> [TransferType] {
        try await getPaginated(path: "/transport/api/reference/transfer-types")
    }

    // MARK: - Chat/Messaging

    func loadMessages(transferId: Int, since: String? = nil) async throws -> [Message] {
        var path = "/transport/api/transfers/\(transferId)/messages"

        if let since = since {
            path += "?since=\(since)"
        }

        return try await getPaginated(path: path)
    }

    func postMessage(transferId: Int, text: String, sender: String) async throws -> Message {
        struct PostMessageRequest: Encodable {
            let text: String
            let sender: String
        }
        return try await post(path: "/transport/api/transfers/\(transferId)/messages", body: PostMessageRequest(text: text, sender: sender))
    }

    func batchMessageCounts(transferIds: [Int]) async throws -> [Int: Int] {
        struct BatchCountRequest: Encodable {
            let transferIds: [Int]
        }
        return try await post(path: "/transport/api/messages/batch-counts", body: BatchCountRequest(transferIds: transferIds))
    }

    // MARK: - Tracking (Public)

    func getTrackingStatus(transferId: Int) async throws -> Transfer {
        try await get(path: "/public/transfer/track/\(transferId)/status")
    }

    func departTransfer(transferId: Int) async throws -> Transfer {
        return try await post(path: "/public/transfer/track/\(transferId)/depart", body: nil)
    }

    func markDelivered(transferId: Int) async throws -> Transfer {
        return try await post(path: "/public/transfer/track/\(transferId)/delivered", body: nil)
    }

    func pingLocation(transferId: Int, lat: Double, lng: Double) async throws -> GPSPingResponse {
        struct LocationRequest: Encodable {
            let lat: Double
            let lng: Double
        }
        return try await post(path: "/public/transfer/track/\(transferId)/ping", body: LocationRequest(lat: lat, lng: lng))
    }

    // MARK: - Action Log

    func listActionLog(actionType: String? = nil, page: Int? = nil, size: Int? = nil) async throws -> [ActionLog] {
        var path = "/transport/api/action-log"
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
        try await getPaginated(path: "/transport/api/transfers/\(transferId)/actions")
    }

    // MARK: - Package Media

    func getPackageMedia(packageId: Int) async throws -> [PackageMedia] {
        try await getPaginated(path: "/transport/api/packages/\(packageId)/media")
    }

    func uploadPackageMedia(packageId: Int, imageData: Data, filename: String) async throws -> PackageMedia {
        guard let url = URL(string: baseURL + "/transport/api/packages/\(packageId)/media") else {
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
}
