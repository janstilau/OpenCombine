//
//  UIBarButtonItem+Combine.swift
//  CombineCocoa
//
//  Created by Shai Mishali on 12/08/2019.
//  Copyright © 2020 Combine Community. All rights reserved.
//

#if !(os(iOS) && (arch(i386) || arch(arm)))
import Combine
import UIKit

@available(iOS 13.0, *)
public extension UIBarButtonItem {
    /// A publisher which emits whenever this UIBarButtonItem is tapped.
    
    var tapPublisher: AnyPublisher<Void, Never> {
        Publishers.ControlTarget(control: self,
                                 // 当通信链路建立的时候, 应该触发的动作
                                 addTargetAction: { control, target, action in
                                    control.target = target
                                    control.action = action
                                 },
                                 // 当通信链路取消的时候, 应该触发的动作
                                 removeTargetAction: { control, _, _ in
                                    control?.target = nil
                                    control?.action = nil
                                 })
                  .eraseToAnyPublisher()
  }
}
#endif
