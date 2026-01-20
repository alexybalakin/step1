//
//  Step1App.swift
//  Step1
//
//  Created by Alex Balakin on 1/18/26.
//

import SwiftUI
import FirebaseCore

@main
struct Step1App: App {
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
