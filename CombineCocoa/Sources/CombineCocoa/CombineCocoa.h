//
//  CombineCocoa.h
//  CombineCocoa
//
//  Created by Joan Disho on 25/09/2019.
//  Copyright © 2020 Combine Community. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CombineCocoa/ObjcDelegateProxy.h>

FOUNDATION_EXPORT double CombineCocoaVersionNumber;
FOUNDATION_EXPORT const unsigned char CombineCocoaVersionString[];

/*
 这个库, 实现的都是在将, 如何设计一个源头的 Publisher.
 
 总体的思想是, 在 receive subscriber 的时候, 建立一个 Subscription. 然后在 Subscription 的初始化方法里面, 完成对于事件的监听.
 在事件的监听方法里面, 完成对于后续 subscriber 数据的发送.
 
 1. Event 触发
 1. Property 触发, 包括 KVO 的触发
 1. Delegate 的触发
 */
