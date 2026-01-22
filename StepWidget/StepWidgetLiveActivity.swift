//
//  StepWidgetLiveActivity.swift
//  StepWidget
//
//  Created by Alex Balakin on 1/22/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct StepWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct StepWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StepWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension StepWidgetAttributes {
    fileprivate static var preview: StepWidgetAttributes {
        StepWidgetAttributes(name: "World")
    }
}

extension StepWidgetAttributes.ContentState {
    fileprivate static var smiley: StepWidgetAttributes.ContentState {
        StepWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: StepWidgetAttributes.ContentState {
         StepWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: StepWidgetAttributes.preview) {
   StepWidgetLiveActivity()
} contentStates: {
    StepWidgetAttributes.ContentState.smiley
    StepWidgetAttributes.ContentState.starEyes
}
