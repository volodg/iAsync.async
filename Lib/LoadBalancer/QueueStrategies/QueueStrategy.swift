//
//  QueueStrategy.swift
//  iAsync_async
//
//  Created by Vladimir Gorbenko on 09.07.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

public protocol QueueStrategy {
    
    typealias ValueT : Any
    typealias ErrorT : ErrorType
    
    init(queueState: QueueState<ValueT, ErrorT>)
    
    func firstPendingLoader() -> BaseLoaderOwner<ValueT, ErrorT>?
    func executePendingLoader(pendingLoader: BaseLoaderOwner<ValueT, ErrorT>)
}
