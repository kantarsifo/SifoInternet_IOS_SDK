//
//  Date+.swift
//  TSMobileAnalytics
//
//  Created by Andreas Lif on 2023-03-29.
//  Copyright © 2023 Kantar Sifo. All rights reserved.
//

import Foundation

extension Date {
    func advancedBy(numberOfWeeks: Int) -> Date {
        var components = DateComponents()
        components.day = numberOfWeeks * 7
        return Calendar.current.date(byAdding: components, to: self) ?? Date()
    }
}
