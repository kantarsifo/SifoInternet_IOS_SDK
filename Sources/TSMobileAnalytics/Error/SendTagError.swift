//
//  SendTagError.swift
//  TSMobileAnalytics
//
//  Created by Andreas Lif on 2023-04-03.
//  Copyright © 2023 Kantar Sifo. All rights reserved.
//

import Foundation

enum SendTagError: Error, Equatable {
    case sdkNotInitialized
    case noPanelistCookieAvailable
    case combinedCategoriesTooLong
    case contentIDTooLong
}

extension SendTagError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .sdkNotInitialized:
            return "SDK has not been initialized."
        case .noPanelistCookieAvailable:
            return "Panelist-only tracking is enabled, but no panelist cookie is available."
        case .combinedCategoriesTooLong:
            return "Combined length of categories is too long."
        case .contentIDTooLong:
            return "Content ID is too long."
        }
    }
}
