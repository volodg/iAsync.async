//
//  JAsyncHelpers.swift
//  Async
//
//  Created by Vladimir Gorbenko on 11.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

//TODO rename to asyncWithValue
public func asyncWithResult<Value, Error>(result: AsyncResult<Value, Error>) -> AsyncTypes<Value, Error>.Async {
    
    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> JAsyncHandler in
        
        doneCallback?(result: result)
        return jStubHandlerAsyncBlock
    }
}

//TODO rename to asyncWithValue
public func asyncWithValue<Value, Error>(value: Value) -> AsyncTypes<Value, Error>.Async {
    
    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> JAsyncHandler in
        
        doneCallback?(result: AsyncResult.success(value))
        return jStubHandlerAsyncBlock
    }
}

public func asyncWithError<Value, Error: ErrorType>(error: Error) -> AsyncTypes<Value, Error>.Async {
    
    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> JAsyncHandler in
        
        doneCallback?(result: AsyncResult.failure(error))
        return jStubHandlerAsyncBlock
    }
}

extension JAsyncHandlerTask {
    
    func buildFinishError<Value, Error: ErrorType>() -> AsyncResult<Value, Error>? {
        
        switch self {
        case UnSubscribe:
            return .Interrupted
        case Cancel:
            return .Unsubscribed
        default:
            return nil
        }
    }
}

public func asyncWithHandlerFlag<Value, Error: ErrorType>(task: JAsyncHandlerTask) -> AsyncTypes<Value, Error>.Async {
    
    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> JAsyncHandler in
        
        processHandlerFlag(task, stateCallback, doneCallback)
        return jStubHandlerAsyncBlock
    }
}

public func processHandlerFlag<Value, Error: ErrorType>(
    task         : JAsyncHandlerTask,
    stateCallback: AsyncChangeStateCallback?,
    doneCallback : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) {
        
    let errorOption: AsyncResult<Value, Error>? = task.buildFinishError()
    
    if let error = errorOption {
        
        doneCallback?(result: error)
    } else {
        
        assert(task != JAsyncHandlerTask.Undefined)
        
        stateCallback?(state: task == .Suspend
            ?JAsyncState.Suspended
            :JAsyncState.Resumed)
    }
}

func neverFinishAsync() -> AsyncTypes<AnyObject, NSError>.Async {
    
    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              doneCallback    : AsyncTypes<AnyObject, NSError>.DidFinishAsyncCallback?) -> JAsyncHandler in
        
        var wasCanceled = false
        
        return { (task: JAsyncHandlerTask) -> () in
            
            if wasCanceled {
                return
            }
            
            wasCanceled = (task == .Cancel
                || task == .UnSubscribe)
            
            processHandlerFlag(task, stateCallback, doneCallback)
        }
    }
}

public func asyncWithSyncOperationInCurrentQueue<Value, Error>(block: AsyncTypes<Value, Error>.JSyncOperation) -> AsyncTypes<Value, Error>.Async
{
    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> JAsyncHandler in
        
        doneCallback?(result: block())
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

public func asyncWithAnalyzer<Value, Result, Error: ErrorType>(
    data: Value, analyzer: UtilsBlockDefinitions2<Value, Result, Error>.JAnalyzer) -> AsyncTypes<Result, Error>.Async {
    
    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              finishCallback  : AsyncTypes<Result, Error>.DidFinishAsyncCallback?) -> JAsyncHandler in
        
        finishCallback?(result: analyzer(object: data))
        return jStubHandlerAsyncBlock
    }
}

public func asyncBinderWithAnalyzer<Value, Result, Error: ErrorType>(analyzer: UtilsBlockDefinitions2<Value, Result, Error>.JAnalyzer) -> AsyncTypes2<Value, Result, Error>.AsyncBinder {
    
    return { (result: Value) -> AsyncTypes<Result, Error>.Async in
        return asyncWithAnalyzer(result, analyzer)
    }
}

public func asyncWithChangedResult<Value, Result, Error: ErrorType>(
    loader: AsyncTypes<Value, Error>.Async,
    resultBuilder: UtilsBlockDefinitions2<Value, Result, Error>.JMappingBlock) -> AsyncTypes<Result, Error>.Async
{
    let secondLoaderBinder = asyncBinderWithAnalyzer({ (result: Value) -> AsyncResult<Result, Error> in
        
        let newResult = resultBuilder(object: result)
        return AsyncResult.success(newResult)
    })
    
    return bindSequenceOfAsyncs(loader, secondLoaderBinder)
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

func loaderWithAdditionalParalelLoaders<Result, Value, Error: ErrorType>(
    original         : AsyncTypes<Result, Error>.Async,
    additionalLoaders: AsyncTypes<Value , Error>.Async...) -> AsyncTypes<Result, Error>.Async
{
    let groupLoader = groupOfAsyncsArray(additionalLoaders)
    let allLoaders  = groupOfAsyncs(original, groupLoader)
    
    let getResult = { (result: (Result, [Value])) -> AsyncTypes<Result, Error>.Async in
        
        return asyncWithValue(result.0)
    }
    
    return bindSequenceOfAsyncs(allLoaders, getResult)
}

//TODO fix error type
public func logErrorForLoader<Value>(loader: AsyncTypes<Value, NSError>.Async) -> AsyncTypes<Value, NSError>.Async
{
    return { (
        progressCallback: AsyncProgressCallback?,
        stateCallback   : AsyncChangeStateCallback?,
        finishCallback  : AsyncTypes<Value, NSError>.DidFinishAsyncCallback?) -> JAsyncHandler in
        
        let wrappedDoneCallback = { (result: AsyncResult<Value, NSError>) -> () in
            
            result.error?.writeErrorWithJLogger()
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
