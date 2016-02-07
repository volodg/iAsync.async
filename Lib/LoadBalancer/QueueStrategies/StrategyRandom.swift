//
//  StrategyRandom.swift
//  iAsync_async
//
//  Created by Vladimir Gorbenko on 09.07.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

final internal class StrategyRandom<Value, Error: ErrorType> : BaseStrategy<Value, Error>, QueueStrategy {

    required override init(queueState: QueueState<Value, Error>) {
        super.init(queueState: queueState)
    }

    func firstPendingLoader() -> BaseLoaderOwner<Value, Error>? {

        let index = Int(arc4random_uniform(UInt32(queueState.pendingLoaders.count)))

        let result = queueState.pendingLoaders[index]
        return result
    }
}
