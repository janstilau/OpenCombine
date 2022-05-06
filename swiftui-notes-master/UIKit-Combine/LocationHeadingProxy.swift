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

// 使用, PassthroughSubject 作为信号的发射者, 可以将指令式的代码, 方便的嵌入到响应式的代码里面.
// 这相当于是一个 ViewModel. 将具体的业务逻辑, 封装到了自己的内部, 然后暴露出一个信号源出去, 外界根据这个信号源来
final class LocationHeadingProxy: NSObject, CLLocationManagerDelegate {
    let mgr: CLLocationManager
    // 对外暴露的接口, 使用 AnyPublisher 这种形式.
    var locationPublisher: AnyPublisher<CLHeading, Error>
    // 内部使用的 Object 这种, 可以直接在内部, 使用指令式的逻辑进行值的赋值.
    private let headingPublisher: PassthroughSubject<CLHeading, Error>

    override init() {
        mgr = CLLocationManager()
        headingPublisher = PassthroughSubject<CLHeading, Error>()
        locationPublisher = headingPublisher.eraseToAnyPublisher()

        super.init()
        mgr.delegate = self
    }

    // ViewModel 的 ModelAction, 在里面, 触发相关的业务逻辑.
    // 仅仅是触发相关的业务逻辑, 使用 Delegate 方式, 异步捕获了相关的状态改变, 然后使用 Subject 暴露给了外界. 
    func enable() {
        mgr.startUpdatingHeading()
    }

    func disable() {
        mgr.stopUpdatingHeading()
    }

    // MARK: - delegate methods

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
