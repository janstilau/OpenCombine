//
//  LocationHeadingProxy.swift
//  UIKit-Combine
//
//  Created by Joseph Heck on 7/13/19.
//  Copyright © 2019 SwiftUI-Notes. All rights reserved.
//

import Combine
import CoreLocation
import Foundation

// 这里是将原来的 Delegate 模式, 改变成为 Publisher 的形式.
final class LocationHeadingProxy: NSObject, CLLocationManagerDelegate {
    let mgr: CLLocationManager
    
    private let headingPublisher: PassthroughSubject<CLHeading, Error>
    // 这里使用计算属性, 应该是一个更好的方式吧.
    var publisher: AnyPublisher<CLHeading, Error>
    
    override init() {
        mgr = CLLocationManager()
        headingPublisher = PassthroughSubject<CLHeading, Error>()
        publisher = headingPublisher.eraseToAnyPublisher()
        
        super.init()
        mgr.delegate = self
    }
    
    func enable() {
        mgr.startUpdatingHeading()
    }
    
    func disable() {
        mgr.stopUpdatingHeading()
    }
    
    // MARK: - delegate methods
    
    // 在 Delegate 的相关方法里面, 触发信号的发送. 
    /*
     *  locationManager:didUpdateHeading:
     *
     *  Discussion:
     *    Invoked when a new heading is available.
     */
    func locationManager(_: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        headingPublisher.send(newHeading)
    }
    
    /*
     *  locationManager:didFailWithError:
     *  Discussion:
     *    Invoked when an error has occurred. Error types are defined in "CLError.h".
     */
    func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        headingPublisher.send(completion: Subscribers.Completion.failure(error))
    }
}


/*
 import CoreLocation

 class LocationManagerDelegate: NSObject, CLLocationManagerDelegate {
     var locationUpdateHandler: ((CLLocation) -> Void)?
     var regionUpdateHandler: ((CLRegion) -> Void)?

     func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
         if let location = locations.last {
             locationUpdateHandler?(location)
         }
     }

     func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
         regionUpdateHandler?(region)
     }
 }

 class LocationManager {
     private let manager: CLLocationManager
     private let delegate = LocationManagerDelegate()

 // 暴露出几个异步队列的属性, 就和不同的 Publisher 一样.
 // 在相关的 delegate 方法里面, 触发对应的协程唤醒.
     var locationUpdates: AsyncStream<CLLocation>
     var regionUpdates: AsyncStream<CLRegion>

     init(manager: CLLocationManager) {
         self.manager = manager
         self.manager.delegate = delegate

        // 智能通过这种方式, 获取到 continuation 对象.
        // 从 COChannel 的实现里面, 可以知道这个 continuation 背后可能没有协程的时. 它只是 COChannel 暴露出来的, 方便进行数据管理的一个接口.
         locationUpdates = AsyncStream { continuation in
             self.delegate.locationUpdateHandler = { location in
                 continuation.yield(location)
             }
         }

         regionUpdates = AsyncStream { continuation in
             self.delegate.regionUpdateHandler = { region in
                 continuation.yield(region)
             }
         }
     }

     func start() {
         manager.startUpdatingLocation()
     }
 }

 // 使用示例
 let manager = CLLocationManager()
 let locationManager = LocationManager(manager: manager)

 Task {
     for await location in locationManager.locationUpdates {
         print(location)
     }
 }

 Task {
     for await region in locationManager.regionUpdates {
         print(region)
     }
 }

 locationManager.start()
 */


/*
 import CoreLocation

 class LocationManagerDelegate: NSObject, CLLocationManagerDelegate {
     var updateHandler: ((CLLocation) -> Void)?

     func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
         if let location = locations.last {
             updateHandler?(location)
         }
     }
 }

 struct LocationUpdates: AsyncSequence {
     typealias Element = CLLocation
     typealias AsyncIterator = AsyncStream<CLLocation>.Iterator

     private let manager: CLLocationManager
     private let delegate = LocationManagerDelegate()

     init(manager: CLLocationManager) {
         self.manager = manager
         self.manager.delegate = delegate
     }

     func makeAsyncIterator() -> AsyncIterator {
         return AsyncStream { continuation in
             self.delegate.updateHandler = { location in
                 continuation.yield(location)
             }
             self.manager.startUpdatingLocation()
         }.makeAsyncIterator()
     }
 }

 // 使用示例
 let manager = CLLocationManager()
 let updates = LocationUpdates(manager: manager)
 Task {
     for await location in updates {
         print(location)
     }
 }
 */
