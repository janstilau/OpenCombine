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
        // Publishers.ControlTarget(control: self 这种方式, 会让 control 的类型固定下来.
        Publishers.ControlTarget(control: self,
                                 addTargetAction: { control, target, action in
            control.target = target
            control.action = action
        },
                                 removeTargetAction: { control, _, _ in
            control?.target = nil
            control?.action = nil
        })
            .eraseToAnyPublisher()
    }
}
#endif
