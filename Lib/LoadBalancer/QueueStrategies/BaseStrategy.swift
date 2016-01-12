//
//  BaseStrategy.swift
//  iAsync_async
//
//  Created by Vladimir Gorbenko on 09.07.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

public class BaseStrategy<Value, Error: ErrorType> {
    
    public typealias ValueT = Value
    public typealias ErrorT = Error
    
    var queueState: QueueState<ValueT, ErrorT>!
    
    init(queueState: QueueState<ValueT, ErrorT>) {
        
        self.queueState = queueState
    }
    
    public func executePendingLoader(pendingLoader: BaseLoaderOwner<ValueT, ErrorT>) {
        
        var objectIndex = Int.max

        for (index, loader) in queueState.pendingLoaders.enumerate() {
            if loader === pendingLoader {
                objectIndex = index
                break
            }
        }

        if objectIndex != Int.max {
            queueState.pendingLoaders.removeAtIndex(objectIndex)
        }

        queueState.activeLoaders.append(pendingLoader)
        
        //    #ifdef DEBUG
        //let pendingLoadersCount = queueState.activeLoaders.count
        //let activeLoadersCount  = queueState.activeLoaders.count
        //    #endif //DEBUG

        pendingLoader.performLoader()

        //    #ifdef DEBUG
        //assert(pendingLoadersCount >= queueState.activeLoaders.count)
        //assert(activeLoadersCount  >= queueState.activeLoaders.count)
        //    #endif //DEBUG
    }
}
