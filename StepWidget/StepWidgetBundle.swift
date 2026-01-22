//
//  StepWidgetBundle.swift
//  StepWidget
//
//  Created by Alex Balakin on 1/22/26.
//

import WidgetKit
import SwiftUI

@main
struct StepWidgetBundle: WidgetBundle {
    var body: some Widget {
        StepWidget()
        StepWidgetControl()
        StepWidgetLiveActivity()
    }
}
