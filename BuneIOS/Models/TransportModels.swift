import Foundation

// MARK: - Type Aliases for API Client Compatibility
typealias Session = TransportSession
typealias Message = ChatMessage

// MARK: - Generic API Response Wrappers

struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: String?
    let timestamp: String?
}

/// Response format for the dashboard transfer list endpoint:
/// `{"success": true, "transfers": {"TEMPLATE_OUTGOING": [...], "OUTGOING": [...], "INCOMING": [...], "HUB": [...]}}`.
///
/// Backend ignores query parameters — the whole dictionary is always returned
/// — so direction filtering has to happen client-side against the group keys.
///
/// NOTE: Pickup and Delivery list endpoints return a FLAT array instead
/// (`{"success":true, "transfers":[...]}`). Use `FlatTransferListResponse`
/// for those. Tagged enum-style decoder below tolerates either shape so
/// callers can share the type, but if you know the shape up front prefer
/// the specific struct.
struct TransferListResponse: Decodable {
    let success: Bool
    let transfers: [String: [Transfer]]?
    let error: String?

    /// Returns the transfers under a single group key (matches backend naming:
    /// OUTGOING, INCOMING, HUB, TEMPLATE_OUTGOING). Returns an empty array if
    /// the group is missing from the response.
    func transfers(inGroup group: String) -> [Transfer] {
        transfers?[group] ?? []
    }

    /// Flattens every group into a single array. Use sparingly — most call
    /// sites should scope to a specific group instead so that, for example,
    /// TEMPLATE_OUTGOING drafts don't leak into the HUB tab.
    var allTransfers: [Transfer] {
        guard let transfers = transfers else { return [] }
        return transfers.values.flatMap { $0 }
    }
}

/// Response format for the pickup + delivery list endpoints which return a
/// flat array instead of the dashboard's grouped dictionary:
/// `{"success": true, "transfers": [...]}`.
struct FlatTransferListResponse: Decodable {
    let success: Bool
    let transfers: [Transfer]?
    let error: String?
}

struct PaginatedResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: PaginatedData<T>?
    let error: String?
    let timestamp: String?
}

struct PaginatedData<T: Decodable>: Decodable {
    let content: [T]
    let totalElements: Int?
    let totalPages: Int?
    let number: Int?
    let size: Int?
}

// MARK: - Core Transfers

struct Transfer: Codable, Identifiable {
    let id: Int
    let manifestNumber: String?
    let shipperFacilityName: String?
    let shipperFacilityLicenseNumber: String?
    let status: String
    let direction: String?
    let packageCount: Int?
    let estimatedDepartureDateTime: String?
    let estimatedArrivalDateTime: String?
    let vehiclePlate: String?
    let driverName: String?
    let routeId: Int?
    let routeName: String?
    let statusProgress: Int?
    let statusColor: String?
    let destinations: [TransferDestination]?
    let packages: [Package]?
    let createdAt: String?

    // Memberwise initializer for previews and testing
    init(
        id: Int,
        manifestNumber: String? = nil,
        shipperFacilityName: String? = nil,
        shipperFacilityLicenseNumber: String? = nil,
        status: String,
        direction: String? = nil,
        packageCount: Int? = nil,
        estimatedDepartureDateTime: String? = nil,
        estimatedArrivalDateTime: String? = nil,
        vehiclePlate: String? = nil,
        driverName: String? = nil,
        routeId: Int? = nil,
        routeName: String? = nil,
        statusProgress: Int? = nil,
        statusColor: String? = nil,
        destinations: [TransferDestination]? = nil,
        packages: [Package]? = nil,
        createdAt: String? = nil
    ) {
        self.id = id
        self.manifestNumber = manifestNumber
        self.shipperFacilityName = shipperFacilityName
        self.shipperFacilityLicenseNumber = shipperFacilityLicenseNumber
        self.status = status
        self.direction = direction
        self.packageCount = packageCount
        self.estimatedDepartureDateTime = estimatedDepartureDateTime
        self.estimatedArrivalDateTime = estimatedArrivalDateTime
        self.vehiclePlate = vehiclePlate
        self.driverName = driverName
        self.routeId = routeId
        self.routeName = routeName
        self.statusProgress = statusProgress
        self.statusColor = statusColor
        self.destinations = destinations
        self.packages = packages
        self.createdAt = createdAt
    }

    // Custom decoding to handle the actual API response format
    // API fields: id, metrcId, manifestNumber, shipperName, shipperLicense,
    //   receiverName, transporterName, transporterLicense, transferType,
    //   shipmentTypeName, tulipStatus, statusLabel, statusColor,
    //   metrcTransferState, tulipStatusReason, direction, driverName,
    //   driverLicenseNumber, vehicleMake, vehicleModel, vehiclePlate, packageCount, etc.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FlexibleCodingKeys.self)

        // ID: try "id" first, then "transferId"
        if let idVal = try? container.decode(Int.self, forKey: FlexibleCodingKeys(stringValue: "id")!) {
            id = idVal
        } else if let idVal = try? container.decode(Int.self, forKey: FlexibleCodingKeys(stringValue: "transferId")!) {
            id = idVal
        } else {
            throw DecodingError.keyNotFound(
                FlexibleCodingKeys(stringValue: "id")!,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Neither 'id' nor 'transferId' found")
            )
        }

        manifestNumber = try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "manifestNumber")!)

        // Status: try "status", "tulipStatus", "statusLabel"
        status = (try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "status")!))
            ?? (try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "tulipStatus")!))
            ?? (try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "statusLabel")!))
            ?? "UNKNOWN"

        direction = try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "direction")!)
        packageCount = try? container.decode(Int.self, forKey: FlexibleCodingKeys(stringValue: "packageCount")!)
        statusProgress = try? container.decode(Int.self, forKey: FlexibleCodingKeys(stringValue: "statusProgress")!)
        statusColor = try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "statusColor")!)
        createdAt = try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "createdAt")!)

        // Departure/Arrival
        estimatedDepartureDateTime = (try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "estimatedDepartureDateTime")!))
            ?? (try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "estimatedDeparture")!))
        estimatedArrivalDateTime = (try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "estimatedArrivalDateTime")!))
            ?? (try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "estimatedArrival")!))

        // Shipper: try multiple key variations
        shipperFacilityName = (try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "shipperFacilityName")!))
            ?? (try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "shipperName")!))
            ?? {
                if let origin = try? container.decode(NestedFacility.self, forKey: FlexibleCodingKeys(stringValue: "origin")!) {
                    return origin.name
                }
                return nil
            }()
        shipperFacilityLicenseNumber = (try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "shipperFacilityLicenseNumber")!))
            ?? (try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "shipperLicense")!))

        // Driver
        driverName = (try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "driverName")!))
            ?? {
                if let driver = try? container.decode(NestedDriver.self, forKey: FlexibleCodingKeys(stringValue: "driver")!) {
                    return driver.name
                }
                return nil
            }()

        // Vehicle plate
        vehiclePlate = (try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "vehiclePlate")!))
            ?? {
                if let vehicle = try? container.decode(NestedVehicle.self, forKey: FlexibleCodingKeys(stringValue: "vehicle")!) {
                    return vehicle.plate
                }
                return nil
            }()

        // Route: try top-level fields first, then nested route object
        let nestedRoute = try? container.decode(NestedRoute.self, forKey: FlexibleCodingKeys(stringValue: "route")!)
        routeId = (try? container.decode(Int.self, forKey: FlexibleCodingKeys(stringValue: "routeId")!))
            ?? nestedRoute?.routeId
        routeName = (try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "routeName")!))
            ?? nestedRoute?.name

        // Destinations: try array, then single "destination" or "receiverName"
        if let dests = try? container.decode([TransferDestination].self, forKey: FlexibleCodingKeys(stringValue: "destinations")!) {
            destinations = dests
        } else if let receiverName = try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "receiverName")!),
                  !receiverName.isEmpty {
            destinations = [TransferDestination(id: 0, recipientFacilityName: receiverName, recipientFacilityLicenseNumber: nil)]
        } else if let dest = try? container.decode(NestedFacility.self, forKey: FlexibleCodingKeys(stringValue: "destination")!) {
            destinations = [TransferDestination(id: 0, recipientFacilityName: dest.name, recipientFacilityLicenseNumber: dest.license)]
        } else {
            destinations = nil
        }

        // Packages: detail endpoint returns packages inline
        packages = try? container.decode([Package].self, forKey: FlexibleCodingKeys(stringValue: "packages")!)
    }
}

// Helper types for nested API response objects
private struct NestedFacility: Codable {
    let name: String?
    let license: String?
}

private struct NestedDriver: Codable {
    let driverId: Int?
    let name: String?
}

private struct NestedVehicle: Codable {
    let vehicleId: Int?
    let make: String?
    let model: String?
    let plate: String?
    let status: String?
}

private struct NestedRoute: Codable {
    let routeId: Int?
    let name: String?
}

/// Flexible coding keys that accept any string key
struct FlexibleCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { self.intValue = intValue; self.stringValue = String(intValue) }
}

struct TransferDestination: Codable, Identifiable {
    let id: Int
    let recipientFacilityName: String?
    let recipientFacilityLicenseNumber: String?

    init(id: Int, recipientFacilityName: String?, recipientFacilityLicenseNumber: String?) {
        self.id = id
        self.recipientFacilityName = recipientFacilityName
        self.recipientFacilityLicenseNumber = recipientFacilityLicenseNumber
    }
}

struct TransferPackage: Codable, Identifiable {
    let id: Int
    let packageLabel: String
    let productName: String?
    let shippedQuantity: Double?
    let shippedUnit: String?
    let receivedQuantity: Double?
    let receivedUnit: String?
    let wholesalePrice: Double?
    let packageState: String?
    let isStaged: Int?
    let transferId: Int?
}

// MARK: - Scan Session Summary
//
// DTO returned by the pickup + delivery session endpoints
// (/transport/pickup/api/session/* and /transport/delivery/api/session/*).
// Different from TransportSession (which is the manifest-creation wizard) —
// this one wraps an in-progress pickup or delivery SCAN session.
struct ScanSessionSummary: Codable, Identifiable {
    let id: Int
    let transferId: Int
    let manifestNumber: String?
    let shipperName: String?
    let shipperLicense: String?
    let receiverName: String?
    let receiverLicense: String?
    let customerEmail: String?
    let vehiclePlate: String?
    let status: String?
    let startedBy: String?
    let startedAt: String?
    let completedAt: String?
    let totalPackages: Int?
    let scannedCount: Int?
}

/// Envelope returned by session endpoints: {success, session, resumed}.
struct ScanSessionEnvelope: Decodable {
    let success: Bool?
    let session: ScanSessionSummary?
    let resumed: Bool?
    let error: String?
}

// MARK: - Sessions

struct TransportSession: Codable, Identifiable {
    let id: Int
    let sessionUuid: String
    let sessionType: String
    let status: String
    let packageCount: Int?
    let driverId: Int?
    let vehicleId: Int?
    let destinationId: Int?
    let routeId: Int?
    let notes: String?
    let shipperLicense: String?
    let shipperName: String?
    let transporterLicense: String?
    let transporterName: String?
    let recipientLicense: String?
    let recipientName: String?
    let transferType: String?
    let driverName: String?
    let vehicleMake: String?
    let vehicleModel: String?
    let vehiclePlate: String?
    let errorMessage: String?
    let submittedAt: String?
    let createdAt: String?
    let updatedAt: String?
}

struct SessionPackage: Codable, Identifiable {
    let id: Int
    let packageLabel: String
    let productName: String?
    let quantity: Double?
    let unitOfMeasure: String?
    let wholesalePrice: Double?
    let sortOrder: Int?
    let submissionStatus: String?
    let errorMessage: String?
    let createdAt: String?
}

// MARK: - Packages

struct Package: Codable, Identifiable {
    let id: Int
    let packageLabel: String
    let productName: String?
    let shippedQuantity: Double?
    let shippedUnit: String?
    let receivedQuantity: Double?
    let receivedUnit: String?
    let transferId: Int?
    let itemCategory: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FlexibleCodingKeys.self)

        // ID: try "id", "transferPackageId", "packageId", or fallback to packageLabel hash
        if let idVal = try? container.decode(Int.self, forKey: FlexibleCodingKeys(stringValue: "id")!) {
            id = idVal
        } else if let idVal = try? container.decode(Int.self, forKey: FlexibleCodingKeys(stringValue: "transferPackageId")!) {
            id = idVal
        } else if let idVal = try? container.decode(Int.self, forKey: FlexibleCodingKeys(stringValue: "packageId")!) {
            id = idVal
        } else {
            // Inline packages from detail endpoint have no ID — use label hash
            let label = try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "packageLabel")!)
            id = abs(label?.hashValue ?? Int.random(in: 1...999999))
        }

        packageLabel = (try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "packageLabel")!)) ?? "Unknown"
        productName = try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "productName")!)
        shippedQuantity = try? container.decode(Double.self, forKey: FlexibleCodingKeys(stringValue: "shippedQuantity")!)
        shippedUnit = (try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "shippedUnit")!))
            ?? (try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "shippedUnitOfMeasureName")!))
        receivedQuantity = try? container.decode(Double.self, forKey: FlexibleCodingKeys(stringValue: "receivedQuantity")!)
        receivedUnit = (try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "receivedUnit")!))
            ?? (try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "receivedUnitOfMeasureName")!))
        transferId = try? container.decode(Int.self, forKey: FlexibleCodingKeys(stringValue: "transferId")!)
        itemCategory = try? container.decode(String.self, forKey: FlexibleCodingKeys(stringValue: "itemCategory")!)
    }
}

// MARK: - Reference Data

struct Driver: Codable, Identifiable {
    let id: Int
    let name: String
    let licenseNumber: String?
    let phone: String?
    let status: String?
    let createdAt: String?
    let updatedAt: String?
}

struct Vehicle: Codable, Identifiable {
    let id: Int
    let make: String?
    let model: String?
    let plate: String
    let registrationNumber: String?
    let status: String?
    let posX: Double?
    let posY: Double?
    let width: Double?
    let height: Double?
    let color: String?
    let createdAt: String?
    let updatedAt: String?
}

struct Destination: Codable, Identifiable {
    let id: Int
    let name: String
    let license: String?
    let address: String?
    let city: String?
    let state: String?
    let zipcode: String?
    let latitude: Double?
    let longitude: Double?
}

struct Transporter: Codable, Identifiable {
    let id: Int
    let license: String?
    let name: String
    let phone: String?
}

struct TransferType: Codable, Identifiable {
    let id: Int?
    let name: String
}

// MARK: - Routes

struct Route: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let originAddress: String?
    let originLat: Double?
    let originLon: Double?
    let destinationAddress: String?
    let destinationLat: Double?
    let destinationLon: Double?
    let geofencePolygonJson: String?
    let routePolylineJson: String?
    let bufferMeters: Int?
    let status: String?
    let stops: [RouteStop]?
    let createdAt: String?
    let updatedAt: String?
}

struct RouteStop: Codable, Identifiable {
    let id: Int
    let stopOrder: Int
    let name: String?
    let lat: Double?
    let lon: Double?
    let address: String?
    let stopType: String?
    let estimatedMinutes: Int?
    let createdAt: String?
}

// MARK: - Zones

struct Zone: Codable, Identifiable {
    let id: Int
    let name: String
    let zoneType: String
    let locationId: Int?
    let packageCount: Int?
    let posX: Double?
    let posY: Double?
    let width: Double?
    let height: Double?
    let color: String?
    let sortOrder: Int?
    let shipperLicense: String?
    let vehicleId: Int?
}

struct ZonePackageAssignment: Codable, Identifiable {
    let id: Int
    let zoneId: Int
    let packageLabel: String
    let transferPackageId: Int?
    let assignedAt: String?
    let removedAt: String?
}

struct ZoneScanAudit: Codable, Identifiable {
    let id: Int
    let packageLabel: String
    let action: String
    let success: Bool
    let errorMessage: String?
    let productName: String?
    let transferManifestNumber: String?
    let transferId: Int?
    let zoneName: String?
    let scannedBy: String?
    let scannedAt: String?
}

// MARK: - Totes

struct Tote: Codable, Identifiable {
    let id: Int
    let toteNumber: String
    let status: String
    let toteConfigId: Int?
    let transferId: Int?
    let packageCount: Int?
    let notes: String?
    let createdBy: String?
    let createdAt: String?
}

struct ToteConfiguration: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let widthInches: Double?
    let heightInches: Double?
    let lengthInches: Double?
    let price: Double?
    let isArchived: Bool?
    let createdAt: String?
}

struct TotePackage: Codable, Identifiable {
    let id: Int
    let toteId: Int
    let packageLabel: String
    let transferPackageId: Int?
    let addedBy: String?
    let addedAt: String?
    let removedBy: String?
    let removedAt: String?
}

// MARK: - GPS & Tracking

struct GPSPing: Codable {
    let vehicleId: Int
    let transferId: Int?
    let latitude: Double
    let longitude: Double
    let speed: Double?
    let heading: Double?
    let accuracy: Double?
    let timestamp: String
    let driverName: String?
}

struct TrackingEvent: Codable, Identifiable {
    let id: Int
    let transferId: Int
    let eventType: String
    let lat: Double?
    let lon: Double?
    let notes: String?
    let timestamp: String?
    let source: String?
    let createdAt: String?
}

struct VehicleLocationPing: Codable, Identifiable {
    let id: Int?
    let vehicleId: Int
    let latitude: Double
    let longitude: Double
    let speed: Double?
    let heading: Double?
    let accuracy: Double?
    let timestamp: String
}

// MARK: - Audit

struct ActionLog: Codable, Identifiable {
    let id: Int
    let actionType: String
    let actionLabel: String?
    let sessionUuid: String?
    let licenseNumber: String?
    let packageCount: Int?
    let manifestNumber: String?
    let recipientName: String?
    let detailSummary: String?
    let metrcResponse: String?
    let status: String?
    let userEmail: String?
    let createdAt: String?
}

// MARK: - Media

struct PackageMedia: Codable, Identifiable {
    let id: Int
    let packageLabel: String
    let filename: String?
    let originalFilename: String?
    let fileType: String?
    let mimeType: String?
    let fileSize: Int?
    let uploadedBy: String?
    let uploadedAt: String?
    let transferId: Int?
    let notes: String?
}

// MARK: - Scanning (Pickup/Delivery)

struct ScanSession: Codable {
    let sessionId: Int
    let transferId: Int
    var packages: [ScanPackage]
    let scannedCount: Int
    let totalCount: Int
}

struct ScanPackage: Codable {
    let label: String
    let productName: String?
    var scanned: Bool
}

struct DeliveryCompletion: Codable {
    let signatureData: String
    let signerName: String
}

struct DeliveryReceipt: Codable {
    let receiptUrl: String
    let qrCodeUrl: String
}

// MARK: - Chat

struct ChatMessage: Codable, Identifiable {
    let messageId: Int?
    var id: Int? { messageId }
    let transferId: Int
    let sender: String
    let senderName: String?
    let text: String
    let timestamp: String
}

// MARK: - Public Tracking

struct TrackingStatus: Codable {
    let transferId: Int
    let status: String
    let step: Int
    let totalSteps: Int
    let eta: String?
    let overdue: Bool?
    let departed: Bool?
    let metrcState: String?
    let hasPickupSession: Bool?
    let hasDeliverySession: Bool?
    let isDriver: Bool?
}
