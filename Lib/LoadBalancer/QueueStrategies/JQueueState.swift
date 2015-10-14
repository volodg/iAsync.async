//
//  QueueState.swift
//  iAsync_async
//
//  Created by Vladimir Gorbenko on 09.07.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

final public class QueueState<Value, Error: ErrorType>  {
    var activeLoaders  = [BaseLoaderOwner<Value, Error>]()
    var pendingLoaders = [BaseLoaderOwner<Value, Error>]()
}
