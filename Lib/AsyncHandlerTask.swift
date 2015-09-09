//
//  AsyncHandlerTask.swift
//  Async
//
//  Created by Vladimir Gorbenko on 11.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

public enum AsyncHandlerTask : CustomStringConvertible {
    case UnSubscribe
    case Cancel
    case Resume
    case Suspend
    
    public var description: String {
        
        switch self {
        case .Cancel:
            return "AsyncHandlerTask.Cancel"
        case .Resume:
            return "AsyncHandlerTask.Resume"
        case .Suspend:
            return "AsyncHandlerTask.Suspend"
        case .UnSubscribe:
            return "AsyncHandlerTask.UnSubscribe"
        }
    }
    
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
