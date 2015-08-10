//
//  JQueueState.swift
//  iAsync
//
//  Created by Vladimir Gorbenko on 09.07.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

public class JQueueState<Value, Error: ErrorType>  {
    var activeLoaders  = [JBaseLoaderOwner<Value, Error>]()
    var pendingLoaders = [JBaseLoaderOwner<Value, Error>]()
}
