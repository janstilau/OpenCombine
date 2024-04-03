//
//  HeadingView.swift
//  SwiftUI-Notes
//
//  Created by Joseph Heck on 2/18/20.
//  Copyright © 2020 SwiftUI-Notes. All rights reserved.
//

import CoreLocation
import SwiftUI

struct HeadingView: View {
    @ObservedObject var locationModel: LocationProxy
    @State var lastHeading: CLHeading?
    @State var lastLocation: CLLocation?
    
    var body: some View {
        VStack {
            HStack {
                Text("authorization status:")
                Text(locationModel.authorizationStatusString())
            }
            if locationModel.authorizationStatus == .notDetermined {
                Button(action: {
                    self.locationModel.requestAuthorization()
                }) {
                    Image(systemName: "lock.shield")
                    Text("Request location authorization")
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.blue, lineWidth: 1)
                )
            }
            if self.lastHeading != nil {
                Text("Heading: ") + Text(String(self.lastHeading!.description))
            }
            if self.lastLocation != nil {
                Text("Location: ") + Text(lastLocation!.description)
                ZStack {
                    Circle()
                        .stroke(Color.blue, lineWidth: 1)
                    
                    GeometryReader { geometry in
                        Path { path in
                            let minWidthHeight = min(geometry.size.height, geometry.size.width)
                            
                            path.move(to: CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2))
                            path.addLine(to: CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2 - minWidthHeight / 2 + 5))
                        }
                        .stroke()
                        .rotation(Angle(degrees: self.lastLocation!.course))
                        .animation(.linear)
                    }
                }
            }
        }
        /*
         onReceive(_:perform:)
         Adds an action to perform when this view detects data emitted by the given publisher.
         
         在 SwiftUI 中，当你在 View 的 body 中使用 onReceive(_:perform:) 方法时，订阅会在 View 创建时建立，并在 View 销毁时自动取消。这是因为 SwiftUI 会管理 View 的生命周期，并在适当的时候自动创建和销毁 View。
         */
        .onReceive(self.locationModel.headingPublisher) { heading in
            self.lastHeading = heading
        }
        .onReceive(self.locationModel.locationPublisher, perform: {
            self.lastLocation = $0
        })
    }
}

// MARK: - SwiftUI VIEW DEBUG

#if DEBUG
#endif
