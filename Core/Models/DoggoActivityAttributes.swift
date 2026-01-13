//
//  DoggoActivityAttributes.swift
//  Doggo
//
//  Created by Sorest on 1/7/26.
//

import ActivityKit
import SwiftUI

struct DoggoActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // This is the only dynamic data we need: When does the timer end?
        var endTime: Date
    }
}
