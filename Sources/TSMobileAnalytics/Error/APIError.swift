//
//  APIError.swift
//  TSMobileAnalytics
//
//  Created by Andreas Lif on 2023-04-04.
//  Copyright © 2023 Kantar Sifo. All rights reserved.
//

import Foundation

enum APIError: Error {
    case unknown
    case badResponse(Int?)
    case noData
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unknown:
            return "Unknown API error."
        case .badResponse(let statusCode):
            if let statusCode {
                return "Unexpected API response status code: \(statusCode)."
            }

            return "Unexpected API response."
        case .noData:
            return "The API response did not include any data."
        }
    }
}
