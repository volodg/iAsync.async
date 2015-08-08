//
//  JAsyncHandlerTask.swift
//  Async
//
//  Created by Vladimir Gorbenko on 11.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

public enum JAsyncHandlerTask {
    case UnSubscribe
    case Cancel
    case Resume
    case Suspend
    case Undefined
    
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
        case Undefined:
            return false
        }
    }
}
