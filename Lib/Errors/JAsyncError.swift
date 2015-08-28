//
//  JAsyncError.swift
//  iAsync
//
//  Created by Vladimir Gorbenko on 11.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

public class JAsyncError: Error {
    
    public override class func iAsyncErrorsDomain() -> String {
        
        return "com.just_for_fun.jff_async_operations.library"
    }
}
