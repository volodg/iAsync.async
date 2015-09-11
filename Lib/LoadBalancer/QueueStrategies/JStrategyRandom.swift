//
//  JStrategyRandom.swift
//  iAsync
//
//  Created by Vladimir Gorbenko on 09.07.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

internal class JStrategyRandom<Value, Error: ErrorType> : JBaseStrategy<Value, Error>, JQueueStrategy {
    
    required override init(queueState: JQueueState<Value, Error>) {
        super.init(queueState: queueState)
    }
    
    func firstPendingLoader() -> JBaseLoaderOwner<Value, Error>? {
        
        let index = Int(arc4random_uniform(UInt32(queueState.pendingLoaders.count)))
        
        let result = queueState.pendingLoaders[index]
        return result
    }
}
