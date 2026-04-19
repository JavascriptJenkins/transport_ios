//
//  BrowsablePackage.swift
//  BuneIOS
//
//  Unified shape for package browse + search results. The backend endpoints
//  return subtly different field names (`label`/`name` vs `packageLabel`/
//  `productName`), so each server shape has a small decoder struct that
//  produces a normalized `BrowsablePackage`.
//

import Foundation

struct BrowsablePackage: Identifiable, Hashable {
    /// METRC package label — unique per package, used as id.
    let packageLabel: String
    let productName: String
    let quantity: Double?
    let unitOfMeasure: String?
    let category: String?
    let labTestingState: String?

    var id: String { packageLabel }

    /// Raw shape returned by `/transport/api/packages/browse`.
    struct BrowseShape: Decodable {
        let label: String
        let name: String?
        let quantity: Double?
        let unit: String?
        let category: String?
        let labState: String?

        var normalized: BrowsablePackage {
            BrowsablePackage(
                packageLabel: label,
                productName: name ?? "",
                quantity: quantity,
                unitOfMeasure: unit,
                category: category,
                labTestingState: labState
            )
        }
    }

    /// Raw shape returned by `/transport/api/search-packages`.
    struct SearchShape: Decodable {
        let packageLabel: String
        let productName: String?
        let quantity: Double?
        let unitOfMeasure: String?
        let category: String?
        let labTestingState: String?

        var normalized: BrowsablePackage {
            BrowsablePackage(
                packageLabel: packageLabel,
                productName: productName ?? "",
                quantity: quantity,
                unitOfMeasure: unitOfMeasure,
                category: category,
                labTestingState: labTestingState
            )
        }
    }
}
