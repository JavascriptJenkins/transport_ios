//
//  LocalCacheService.swift
//  BuneIOS
//
//  Caches reference data and active transfers locally for offline access.
//  Manages cache invalidation and refresh based on TTL.
//

import Foundation

@MainActor
class LocalCacheService: ObservableObject {
    @Published var cachedTransfers: [Transfer] = []
    @Published var cachedDrivers: [Driver] = []
    @Published var cachedVehicles: [Vehicle] = []
    @Published var cachedRoutes: [Route] = []
    @Published var cachedDestinations: [Destination] = []
    @Published var lastRefreshAt: Date?

    private let cacheDirectory: URL
    private let transfersCacheKey = "cached_transfers"
    private let driversCacheKey = "cached_drivers"
    private let vehiclesCacheKey = "cached_vehicles"
    private let routesCacheKey = "cached_routes"
    private let destinationsCacheKey = "cached_destinations"

    // Cache TTL: 5 minutes for transfers, 30 minutes for reference data
    private let transfersTTL: TimeInterval = 300
    private let referenceDataTTL: TimeInterval = 1800

    init() {
        // Create cache directory in Documents
        let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = documentDir.appendingPathComponent("BuneCache", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create cache directory: \(error)")
        }

        // Load cached data from disk
        loadCachedTransfers()
        loadCachedDrivers()
        loadCachedVehicles()
        loadCachedRoutes()
        loadCachedDestinations()
    }

    // MARK: - Cache Transfers

    func cacheTransfers(_ transfers: [Transfer]) {
        save(transfers, forKey: transfersCacheKey)
        cachedTransfers = transfers
    }

    private func loadCachedTransfers() {
        if let transfers: [Transfer] = load(forKey: transfersCacheKey), isTransferCacheValid() {
            cachedTransfers = transfers
        }
    }

    func isTransferCacheValid() -> Bool {
        guard let timestamp = getCacheTimestamp(forKey: transfersCacheKey) else { return false }
        return Date().timeIntervalSince(timestamp) < transfersTTL
    }

    // MARK: - Cache Drivers

    func cacheDrivers(_ drivers: [Driver]) {
        save(drivers, forKey: driversCacheKey)
        cachedDrivers = drivers
    }

    private func loadCachedDrivers() {
        if let drivers: [Driver] = load(forKey: driversCacheKey), isReferenceDataCacheValid() {
            cachedDrivers = drivers
        }
    }

    // MARK: - Cache Vehicles

    func cacheVehicles(_ vehicles: [Vehicle]) {
        save(vehicles, forKey: vehiclesCacheKey)
        cachedVehicles = vehicles
    }

    private func loadCachedVehicles() {
        if let vehicles: [Vehicle] = load(forKey: vehiclesCacheKey), isReferenceDataCacheValid() {
            cachedVehicles = vehicles
        }
    }

    // MARK: - Cache Routes

    func cacheRoutes(_ routes: [Route]) {
        save(routes, forKey: routesCacheKey)
        cachedRoutes = routes
    }

    private func loadCachedRoutes() {
        if let routes: [Route] = load(forKey: routesCacheKey), isReferenceDataCacheValid() {
            cachedRoutes = routes
        }
    }

    // MARK: - Cache Destinations

    func cacheDestinations(_ destinations: [Destination]) {
        save(destinations, forKey: destinationsCacheKey)
        cachedDestinations = destinations
    }

    private func loadCachedDestinations() {
        if let destinations: [Destination] = load(forKey: destinationsCacheKey), isReferenceDataCacheValid() {
            cachedDestinations = destinations
        }
    }

    // MARK: - Cache Validity

    func isReferenceDataCacheValid() -> Bool {
        guard let timestamp = getCacheTimestamp(forKey: driversCacheKey) else { return false }
        return Date().timeIntervalSince(timestamp) < referenceDataTTL
    }

    // MARK: - Full Refresh

    func refreshAll(using apiClient: TransportAPIClient) async {
        // Parallel fetch all reference data
        async let drivers = apiClient.listDrivers()
        async let vehicles = apiClient.listVehicles()
        async let routes = apiClient.listRoutes()
        async let destinations = apiClient.listDestinations()

        do {
            let (driverList, vehicleList, routeList, destinationList) = try await (drivers, vehicles, routes, destinations)

            // Cache everything
            cacheDrivers(driverList)
            cacheVehicles(vehicleList)
            cacheRoutes(routeList)
            cacheDestinations(destinationList)

            lastRefreshAt = Date()
        } catch {
            print("Failed to refresh reference data: \(error)")
        }
    }

    // MARK: - Clear

    func clearAll() {
        do {
            try FileManager.default.removeItem(at: cacheDirectory)
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

            cachedTransfers = []
            cachedDrivers = []
            cachedVehicles = []
            cachedRoutes = []
            cachedDestinations = []
            lastRefreshAt = nil
        } catch {
            print("Failed to clear cache: \(error)")
        }
    }

    // MARK: - Helpers

    private func save<T: Encodable>(_ data: T, forKey key: String) {
        let fileURL = cacheFileURL(forKey: key)
        do {
            let encodedData = try JSONEncoder().encode(data)
            try encodedData.write(to: fileURL)
            // Save timestamp
            UserDefaults.standard.set(Date(), forKey: "\(key)_timestamp")
        } catch {
            print("Failed to save cache for key \(key): \(error)")
        }
    }

    private func load<T: Decodable>(forKey key: String) -> T? {
        let fileURL = cacheFileURL(forKey: key)
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("Failed to load cache for key \(key): \(error)")
            return nil
        }
    }

    private func getCacheTimestamp(forKey key: String) -> Date? {
        return UserDefaults.standard.object(forKey: "\(key)_timestamp") as? Date
    }

    private func cacheFileURL(forKey key: String) -> URL {
        return cacheDirectory.appendingPathComponent("\(key).json")
    }
}
