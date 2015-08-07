//
//  JAsyncBlockDefinitions.swift
//  JAsync
//
//  Created by Vladimir Gorbenko on 11.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

public typealias JAsyncProgressCallback = (progressInfo: AnyObject) -> ()

public typealias JAsyncChangeStateCallback = (state: JAsyncState) -> ()

public typealias JAsyncHandler = (task: JAsyncHandlerTask) -> ()

public enum JAsyncTypes<Value, Error: ErrorType> {
    
    public typealias JDidFinishAsyncCallback = (result: AsyncResult<Value, Error>) -> ()
    
    public typealias JAsync = (
        progressCallback: JAsyncProgressCallback?,
        stateCallback   : JAsyncChangeStateCallback?,
        finishCallback  : JDidFinishAsyncCallback?) -> JAsyncHandler
    
    //Synchronous block which can take a lot of time
    public typealias JSyncOperation = () -> AsyncResult<Value, Error>
    
    //This block should call progress_callback_ block only from own thread
    public typealias JSyncOperationWithProgress = (progressCallback: JAsyncProgressCallback?) -> AsyncResult<Value, Error>
}

public enum JAsyncTypes2<Value1, Value2, Error: ErrorType> {
    
    public typealias BinderType = Value1
    public typealias ErrorT = NSError
    public typealias ValueT = Value2
    
    public typealias JAsyncBinder = (Value1) -> JAsyncTypes<Value2, Error>.JAsync
    
    public typealias JDidFinishAsyncHook = (
        result        : AsyncResult<Value1, Error>,
        finishCallback: JAsyncTypes<Value2, Error>.JDidFinishAsyncCallback?) -> ()
}

public func runAsync<Value, Error: ErrorType>(loader: JAsyncTypes<Value, Error>.JAsync, onFinish: JAsyncTypes<Value, Error>.JDidFinishAsyncCallback? = nil)
{
    if let onFinish = onFinish {
        
        let _ = loader(progressCallback: nil, stateCallback: nil, finishCallback: { (result) -> () in
            
            onFinish(result: result)
        })
    } else {
        
        let _ = loader(progressCallback: nil, stateCallback: nil, finishCallback: nil)
    }
}
