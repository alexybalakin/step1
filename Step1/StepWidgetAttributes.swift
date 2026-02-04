//
//  StepWidgetAttributes.swift
//  Step1
//
//  Shared between main app and widget extension
//  IMPORTANT: Add this file to BOTH targets (Step1 and StepWidget)
//

import ActivityKit
import Foundation

struct StepWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var steps: Int
        var goal: Int
        var progress: Double
    }
    
    var userName: String
}
