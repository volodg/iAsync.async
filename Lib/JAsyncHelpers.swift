//
//  JAsyncHelpers.swift
//  iAsync
//
//  Created by Vladimir Gorbenko on 11.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

public func async<Value, Error>(result result: AsyncResult<Value, Error>) -> AsyncTypes<Value, Error>.Async {
    
    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> JAsyncHandler in
        
        doneCallback?(result: result)
        return jStubHandlerAsyncBlock
    }
}

public func async<Value, Error>(value value: Value) -> AsyncTypes<Value, Error>.Async {
    
    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> JAsyncHandler in
        
        doneCallback?(result: .Success(value))
        return jStubHandlerAsyncBlock
    }
}

public func async<Value, Error>(value: Value, progress: AnyObject) -> AsyncTypes<Value, Error>.Async {
    
    return { (
        progressCallback: AsyncProgressCallback?,
        stateCallback   : AsyncChangeStateCallback?,
        doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> JAsyncHandler in
        
        progressCallback?(progressInfo: progress)
        doneCallback?(result: .Success(value))
        return jStubHandlerAsyncBlock
    }
}

public func async<Value, Error: ErrorType>(error error: Error) -> AsyncTypes<Value, Error>.Async {
    
    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> JAsyncHandler in
        
        doneCallback?(result: .Failure(error))
        return jStubHandlerAsyncBlock
    }
}

public func async<Value, Error: ErrorType>(task task: AsyncHandlerTask) -> AsyncTypes<Value, Error>.Async {
    
    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> JAsyncHandler in
        
        processHandlerTast(task, stateCallback: stateCallback, doneCallback: doneCallback)
        return jStubHandlerAsyncBlock
    }
}

public func processHandlerTast<Value, Error: ErrorType>(
    task         : AsyncHandlerTask,
    stateCallback: AsyncChangeStateCallback?,
    doneCallback : AsyncTypes<Value, Error>.DidFinishAsyncCallback?)
{
    switch task {
    case .UnSubscribe:
        doneCallback?(result: .Unsubscribed)
    case .Cancel:
        doneCallback?(result: .Interrupted)
    case .Resume:
        stateCallback?(state: .Resumed)
    case .Suspend:
        stateCallback?(state: .Suspended)
    }
}

func neverFinishAsync() -> AsyncTypes<AnyObject, NSError>.Async {
    
    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              doneCallback    : AsyncTypes<AnyObject, NSError>.DidFinishAsyncCallback?) -> JAsyncHandler in
        
        var wasCanceled = false
        
        return { (task: AsyncHandlerTask) -> () in
            
            if wasCanceled {
                return
            }
            
            wasCanceled = (task == .Cancel
                || task == .UnSubscribe)
            
            processHandlerTast(task, stateCallback: stateCallback, doneCallback: doneCallback)
        }
    }
}

public func async<Value, Error>(sameThreadJob sameThreadJob: AsyncTypes<Value, Error>.SyncOperation) -> AsyncTypes<Value, Error>.Async
{
    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> JAsyncHandler in
        
        let result = sameThreadJob()
        doneCallback?(result: result)
        return jStubHandlerAsyncBlock
    }
}

public func asyncWithFinishCallbackBlock<Value, Error>(
    loader: AsyncTypes<Value, Error>.Async,
    finishCallbackBlock: AsyncTypes<Value, Error>.DidFinishAsyncCallback) -> AsyncTypes<Value, Error>.Async
{
    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> JAsyncHandler in
        
        return loader(
            progressCallback: progressCallback,
            stateCallback   : stateCallback,
            finishCallback  : { (result: AsyncResult<Value, Error>) -> () in
            
            finishCallbackBlock(result: result)
            doneCallback?(result: result)
        })
    }
}

public func asyncWithFinishHookBlock<Value1, Value2, Error>(loader: AsyncTypes<Value1, Error>.Async, finishCallbackHook: AsyncTypes2<Value1, Value2, Error>.JDidFinishAsyncHook) -> AsyncTypes<Value2, Error>.Async
{
    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              finishCallback  : AsyncTypes<Value2, Error>.DidFinishAsyncCallback?) -> JAsyncHandler in
        
        return loader(
            progressCallback: progressCallback,
            stateCallback   : stateCallback   ,
            finishCallback  : { (result: AsyncResult<Value1, Error>) -> () in
            
            finishCallbackHook(result: result, finishCallback: finishCallback)
        })
    }
}

func asyncWithStartAndFinishBlocks<Value, Error>(
    loader          : AsyncTypes<Value, Error>.Async,
    startBlockOption: SimpleBlock?,
    finishCallback  : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> AsyncTypes<Value, Error>.Async
{
    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> JAsyncHandler in
        
        startBlockOption?()
        
        let wrappedDoneCallback = { (result: AsyncResult<Value, Error>) -> () in
            
            finishCallback?(result: result)
            doneCallback?(result: result)
        }
        return loader(
            progressCallback: progressCallback,
            stateCallback   : stateCallback   ,
            finishCallback  : wrappedDoneCallback)
    }
}

func asyncWithOptionalStartAndFinishBlocks<Value, Error>(
    loader        : AsyncTypes<Value, Error>.Async,
    startBlock    : SimpleBlock?,
    finishCallback: AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> AsyncTypes<Value, Error>.Async
{
    return { (progressCallback  : AsyncProgressCallback?,
              stateCallback     : AsyncChangeStateCallback?,
              doneCallbackOption: AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> JAsyncHandler in
        
        var loading = true
        
        let wrappedDoneCallback = { (result: AsyncResult<Value, Error>) -> () in
            
            loading = false
            
            finishCallback?(result: result)
            doneCallbackOption?(result: result)
        }
        
        let cancel = loader(
            progressCallback: progressCallback,
            stateCallback   : stateCallback   ,
            finishCallback  : wrappedDoneCallback)
        
        if loading {
            
            startBlock?()
            return cancel
        }
        
        return jStubHandlerAsyncBlock
    }
}

func asyncWithChangedProgress<Value, Error: ErrorType>(
    loader: AsyncTypes<Value, Error>.Async,
    resultBuilder: UtilsBlockDefinitions2<AnyObject, AnyObject, Error>.JMappingBlock) -> AsyncTypes<Value, Error>.Async
{
    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              finishCallback  : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> JAsyncHandler in
        
        let progressCallbackWrapper = { (info: AnyObject) -> () in
            
            progressCallback?(progressInfo: resultBuilder(object: info))
            return
        }
        
        return loader(
            progressCallback: progressCallbackWrapper,
            stateCallback   : stateCallback          ,
            finishCallback  : finishCallback)
    }
}

public func logErrorForLoader<Value>(loader: AsyncTypes<Value, NSError>.Async) -> AsyncTypes<Value, NSError>.Async
{
    return { (
        progressCallback: AsyncProgressCallback?,
        stateCallback   : AsyncChangeStateCallback?,
        finishCallback  : AsyncTypes<Value, NSError>.DidFinishAsyncCallback?) -> JAsyncHandler in
        
        let wrappedDoneCallback = { (result: AsyncResult<Value, NSError>) -> () in
            
            result.error?.writeErrorWithLogger()
            finishCallback?(result: result)
        }
        
        let cancel = loader(
            progressCallback: progressCallback,
            stateCallback   : stateCallback,
            finishCallback  : wrappedDoneCallback)
        
        return cancel
    }
}

public func ignoreProgressLoader<Value, Error: ErrorType>(loader: AsyncTypes<Value, Error>.Async) -> AsyncTypes<Value, Error>.Async
{
    return { (
        progressCallback: AsyncProgressCallback?,
        stateCallback   : AsyncChangeStateCallback?,
        finishCallback  : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> JAsyncHandler in
        
        return loader(
            progressCallback: progressCallback,
            stateCallback   : stateCallback,
            finishCallback  : finishCallback)
    }
}
