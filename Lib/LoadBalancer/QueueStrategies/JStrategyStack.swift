//
//  JStrategyStack.swift
//  Async
//
//  Created by Vladimir Gorbenko on 09.07.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

internal class JStrategyStack<Value, Error: ErrorType> : JBaseStrategy<Value, Error>, JQueueStrategy {
    
    required override init(queueState: JQueueState<Value, Error>) {
        super.init(queueState: queueState)
    }
    
    func firstPendingLoader() -> JBaseLoaderOwner<Value, Error>? {
        
        let result = queueState.pendingLoaders.last
        return result
    }
}
