import WidgetKit
import SwiftUI

@main
struct DoggoWidgetBundle: WidgetBundle {
    var body: some Widget {
        // If you kept the default static widget code, include it here:
        //DoggoWidget()
        
        // Add your new Live Activity here:
        DoggoWidgetLiveActivity()
        
        // If you have Control Center widgets (iOS 18+), they go here too:
        // DoggoWidgetControl()
    }
}
