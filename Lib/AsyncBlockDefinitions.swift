//
//  AsyncBlockDefinitions.swift
//  iAsync_async
//
//  Created by Vladimir Gorbenko on 11.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

import ReactiveKit

public typealias AsyncProgressCallback = (progressInfo: AnyObject) -> ()

public typealias AsyncChangeStateCallback = (state: AsyncState) -> ()

public typealias AsyncHandler = (task: AsyncHandlerTask) -> ()

public enum AsyncTypes<Value, Error: ErrorType> {

    public typealias DidFinishAsyncCallback = (result: AsyncResult<Value, Error>) -> Void

    public typealias Async = (
        progressCallback: AsyncProgressCallback?,
        stateCallback   : AsyncChangeStateCallback?,
        finishCallback  : DidFinishAsyncCallback?) -> AsyncHandler

    //Synchronous block which can take a lot of time
    public typealias SyncOperation = () -> Result<Value, Error>

    //This block should call progress_callback_ block only from own thread
    public typealias SyncOperationWithProgress = (progressCallback: AsyncProgressCallback?) -> Result<Value, Error>
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

public func runAsync<Value, Error: ErrorType>(loader: AsyncTypes<Value, Error>.Async, onFinish: AsyncTypes<Value, Error>.DidFinishAsyncCallback? = nil) {

    if let onFinish = onFinish {

        let _ = loader(progressCallback: nil, stateCallback: nil, finishCallback: { (result) -> () in

            onFinish(result: result)
        })
    } else {

        let _ = loader(progressCallback: nil, stateCallback: nil, finishCallback: nil)
    }
}
