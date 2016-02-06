//
//  AsyncHandlerTask.swift
//  iAsync_async
//
//  Created by Vladimir Gorbenko on 11.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

public enum AsyncHandlerTask {
    case UnSubscribe
    case Cancel
    case Resume
    case Suspend

    public var unsubscribedOrCanceled: Bool {

        switch self {
        case UnSubscribe:
            return true
        case Cancel:
            return true
        case Resume:
            return false
        case Suspend:
            return false
        }
    }
}
