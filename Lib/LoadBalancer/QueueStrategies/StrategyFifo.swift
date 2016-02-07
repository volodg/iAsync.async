//
//  StrategyFifo.swift
//  iAsync_async
//
//  Created by Vladimir Gorbenko on 09.07.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

final public class StrategyFifo<Value, Error: ErrorType> : BaseStrategy<Value, Error>, QueueStrategy {

    required override public init(queueState: QueueState<Value, Error>) {
        super.init(queueState: queueState)
    }

    public func firstPendingLoader() -> BaseLoaderOwner<Value, Error>? {

        return queueState.pendingLoaders.first
    }
}
