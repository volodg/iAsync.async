//
//  JAsyncBlockDefinitions.swift
//  iAsync
//
//  Created by Vladimir Gorbenko on 11.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

public typealias AsyncProgressCallback = (progressInfo: AnyObject) -> ()

public typealias AsyncChangeStateCallback = (state: JAsyncState) -> ()

public typealias JAsyncHandler = (task: AsyncHandlerTask) -> ()

public struct Async<Value, Error: ErrorType> {
    
    public let async: AsyncTypes<Value, Error>.Async
    
    public init(_ async: AsyncTypes<Value, Error>.Async) {
        self.async = async
    }
    
    public func next<Result>(async: AsyncTypes<Result, Error>.Async) -> Async<Result, Error> {
        
        let loader = sequenceOfAsyncs(self.async, async)
        return Async<Result, Error>(loader)
    }
}

public enum AsyncTypes<Value, Error: ErrorType> {
    
    public typealias DidFinishAsyncCallback = (result: AsyncResult<Value, Error>) -> Void
    
    public typealias Async = (
        progressCallback: AsyncProgressCallback?,
        stateCallback   : AsyncChangeStateCallback?,
        finishCallback  : DidFinishAsyncCallback?) -> JAsyncHandler
    
    //Synchronous block which can take a lot of time
    public typealias SyncOperation = () -> AsyncResult<Value, Error>
    
    //This block should call progress_callback_ block only from own thread
    public typealias SyncOperationWithProgress = (progressCallback: AsyncProgressCallback?) -> AsyncResult<Value, Error>
}

public enum AsyncTypes2<Value1, Value2, Error: ErrorType> {
    
    public typealias BinderType = Value1
    public typealias ErrorT = NSError
    public typealias ValueT = Value2
    
    public typealias AsyncBinder = (Value1) -> AsyncTypes<Value2, Error>.Async
    
    public typealias JDidFinishAsyncHook = (
        result        : AsyncResult<Value1, Error>,
        finishCallback: AsyncTypes<Value2, Error>.DidFinishAsyncCallback?) -> ()
}

public func runAsync<Value, Error: ErrorType>(loader: AsyncTypes<Value, Error>.Async, onFinish: AsyncTypes<Value, Error>.DidFinishAsyncCallback? = nil)
{
    if let onFinish = onFinish {
        
        let _ = loader(progressCallback: nil, stateCallback: nil, finishCallback: { (result) -> () in
            
            onFinish(result: result)
        })
    } else {
        
        let _ = loader(progressCallback: nil, stateCallback: nil, finishCallback: nil)
    }
}
