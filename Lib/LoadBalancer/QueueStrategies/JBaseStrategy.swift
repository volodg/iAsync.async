//
//  JBaseStrategy.swift
//  iAsync
//
//  Created by Vladimir Gorbenko on 09.07.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

public class JBaseStrategy<Value, Error: ErrorType> {
    
    public typealias ValueT = Value
    public typealias ErrorT = Error
    
    var queueState: JQueueState<ValueT, ErrorT>!
    
    init(queueState: JQueueState<ValueT, ErrorT>) {
        
        self.queueState = queueState
    }
    
    public func executePendingLoader(pendingLoader: JBaseLoaderOwner<ValueT, ErrorT>) {
        
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
        //    NSUInteger pendingLoadersCount = [_queueState->_pendingLoaders count]
        //    NSUInteger activeLoadersCount  = [_queueState->_activeLoaders  count]
        //    #endif //DEBUG
        
        pendingLoader.performLoader()
        
        //    #ifdef DEBUG
        //    NSParameterAssert(pendingLoadersCount >= [_queueState->_pendingLoaders count])
        //    NSParameterAssert(activeLoadersCount  >= [_queueState->_activeLoaders  count])
        //    #endif //DEBUG
    }
}
