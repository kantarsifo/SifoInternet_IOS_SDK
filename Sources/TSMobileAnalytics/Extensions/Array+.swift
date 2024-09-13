//
//  Array+.swift
//  TSMobileAnalytics
//
//  Created by Andreas Lif on 2023-04-03.
//  Copyright © 2023 Kantar Sifo. All rights reserved.
//

import Foundation

extension Array where Element == String {
    func slashSeparatedString() -> String {
        filter { !$0.isEmpty }
            .joined(separator: .slash)
    }
}

extension Array where Element == Cookie {
    
    func urlEncoded() throws -> String? {
        let encoded = try JSONEncoder().encode(self)
        return  String(data: encoded, encoding: .utf8)?.urlEncoded()
    }
}
