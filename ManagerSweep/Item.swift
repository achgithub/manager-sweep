//
//  Item.swift
//  ManagerSweep
//
//  Created by Andrew Harris on 22/05/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
