//
//  JStrategyFifo.swift
//  JAsync
//
//  Created by Vladimir Gorbenko on 09.07.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

public class JStrategyFifo<Value, Error: ErrorType> : JBaseStrategy<Value, Error>, JQueueStrategy {
    
    required override public init(queueState: JQueueState<Value, Error>) {
        super.init(queueState: queueState)
    }
    
    public func firstPendingLoader() -> JBaseLoaderOwner<Value, Error>? {
        
        let result = queueState.pendingLoaders[0]
        return result
    }
}
