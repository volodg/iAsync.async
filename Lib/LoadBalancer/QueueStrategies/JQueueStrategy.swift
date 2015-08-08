//
//  JQueueStrategy.swift
//  Async
//
//  Created by Vladimir Gorbenko on 09.07.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

public protocol JQueueStrategy {
    
    typealias ValueT : Any
    typealias ErrorT : ErrorType
    
    init(queueState: JQueueState<ValueT, ErrorT>)
    
    func firstPendingLoader() -> JBaseLoaderOwner<ValueT, ErrorT>?
    func executePendingLoader(pendingLoader: JBaseLoaderOwner<ValueT, ErrorT>)
}
