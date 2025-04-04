//
//  Item.swift
//  OrganizeBy
//
//  Created by user940373 on 4/3/25.
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
