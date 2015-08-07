//
//  JAsyncHelpers.swift
//  JAsync
//
//  Created by Vladimir Gorbenko on 11.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

//TODO !!! rename to asyncWithResult
public func async<Value, Error>(resultOrError result: AsyncResult<Value, Error>) -> JAsyncTypes<Value, Error>.JAsync {
    
    return { (progressCallback: JAsyncProgressCallback?,
              stateCallback   : JAsyncChangeStateCallback?,
              doneCallback    : JAsyncTypes<Value, Error>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
        doneCallback?(result: result)
        return jStubHandlerAsyncBlock
    }
}

//TODO !!! rename to asyncWithValue
public func async<Value, Error>(result result: Value) -> JAsyncTypes<Value, Error>.JAsync {
    
    return { (progressCallback: JAsyncProgressCallback?,
              stateCallback   : JAsyncChangeStateCallback?,
              doneCallback    : JAsyncTypes<Value, Error>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
        doneCallback?(result: AsyncResult.success(result))
        return jStubHandlerAsyncBlock
    }
}

//TODO remove ?
public func async<Value, Error: ErrorType>(error error: Error) -> JAsyncTypes<Value, Error>.JAsync {
    
    return { (progressCallback: JAsyncProgressCallback?,
              stateCallback   : JAsyncChangeStateCallback?,
              doneCallback    : JAsyncTypes<Value, Error>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
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

public func async<Value, Error: ErrorType>(task task: JAsyncHandlerTask) -> JAsyncTypes<Value, Error>.JAsync {
    
    return { (progressCallback: JAsyncProgressCallback?,
              stateCallback   : JAsyncChangeStateCallback?,
              doneCallback    : JAsyncTypes<Value, Error>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
        processHandlerTast(task, stateCallback: stateCallback, doneCallback: doneCallback)
        return jStubHandlerAsyncBlock
    }
}

public func processHandlerTast<Value, Error: ErrorType>(
    task         : JAsyncHandlerTask,
    stateCallback: JAsyncChangeStateCallback?,
    doneCallback : JAsyncTypes<Value, Error>.JDidFinishAsyncCallback?) {
        
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

func neverFinishAsync() -> JAsyncTypes<AnyObject, NSError>.JAsync {
    
    return { (progressCallback: JAsyncProgressCallback?,
              stateCallback   : JAsyncChangeStateCallback?,
              doneCallback    : JAsyncTypes<AnyObject, NSError>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
        var wasCanceled = false
        
        return { (task: JAsyncHandlerTask) -> () in
            
            if wasCanceled {
                return
            }
            
            wasCanceled = (task == .Cancel
                || task == .UnSubscribe)
            
            processHandlerTast(task, stateCallback: stateCallback, doneCallback: doneCallback)
        }
    }
}

public func async<Value, Error>(sameThreadJob sameThreadJob: JAsyncTypes<Value, Error>.JSyncOperation) -> JAsyncTypes<Value, Error>.JAsync
{
    return { (progressCallback: JAsyncProgressCallback?,
              stateCallback   : JAsyncChangeStateCallback?,
              doneCallback    : JAsyncTypes<Value, Error>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
        doneCallback?(result: sameThreadJob())
        return jStubHandlerAsyncBlock
    }
}

public func asyncWithFinishCallbackBlock<Value, Error>(
    loader: JAsyncTypes<Value, Error>.JAsync,
    finishCallbackBlock: JAsyncTypes<Value, Error>.JDidFinishAsyncCallback) -> JAsyncTypes<Value, Error>.JAsync
{
    return { (progressCallback: JAsyncProgressCallback?,
              stateCallback   : JAsyncChangeStateCallback?,
              doneCallback    : JAsyncTypes<Value, Error>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
        return loader(
            progressCallback: progressCallback,
            stateCallback   : stateCallback,
            finishCallback  : { (result: AsyncResult<Value, Error>) -> () in
                
            finishCallbackBlock(result: result)
            doneCallback?(result: result)
        })
    }
}

public func asyncWithFinishHookBlock<Value1, Value2, Error>(loader: JAsyncTypes<Value1, Error>.JAsync, finishCallbackHook: JAsyncTypes2<Value1, Value2, Error>.JDidFinishAsyncHook) -> JAsyncTypes<Value2, Error>.JAsync
{
    return { (progressCallback: JAsyncProgressCallback?,
              stateCallback   : JAsyncChangeStateCallback?,
              finishCallback  : JAsyncTypes<Value2, Error>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
        return loader(
            progressCallback: progressCallback,
            stateCallback   : stateCallback   ,
            finishCallback  : { (result: AsyncResult<Value1, Error>) -> () in
            
            finishCallbackHook(result: result, finishCallback: finishCallback)
        })
    }
}

func asyncWithStartAndFinishBlocks<Value, Error>(
    loader          : JAsyncTypes<Value, Error>.JAsync,
    startBlockOption: SimpleBlock?,
    finishCallback  : JAsyncTypes<Value, Error>.JDidFinishAsyncCallback?) -> JAsyncTypes<Value, Error>.JAsync
{
    return { (progressCallback: JAsyncProgressCallback?,
              stateCallback   : JAsyncChangeStateCallback?,
              doneCallback    : JAsyncTypes<Value, Error>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
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
    loader        : JAsyncTypes<Value, Error>.JAsync,
    startBlock    : SimpleBlock?,
    finishCallback: JAsyncTypes<Value, Error>.JDidFinishAsyncCallback?) -> JAsyncTypes<Value, Error>.JAsync
{
    return { (progressCallback  : JAsyncProgressCallback?,
              stateCallback     : JAsyncChangeStateCallback?,
              doneCallbackOption: JAsyncTypes<Value, Error>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
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
    loader: JAsyncTypes<Value, Error>.JAsync,
    resultBuilder: UtilsBlockDefinitions2<AnyObject, AnyObject, Error>.JMappingBlock) -> JAsyncTypes<Value, Error>.JAsync
{
    return { (progressCallback: JAsyncProgressCallback?,
              stateCallback   : JAsyncChangeStateCallback?,
              finishCallback  : JAsyncTypes<Value, Error>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
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

public func logErrorForLoader<Value, Error: ErrorType>(loader: JAsyncTypes<Value, Error>.JAsync) -> JAsyncTypes<Value, Error>.JAsync
{
    return { (
        progressCallback: JAsyncProgressCallback?,
        stateCallback   : JAsyncChangeStateCallback?,
        finishCallback  : JAsyncTypes<Value, Error>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
        let wrappedDoneCallback = { (result: AsyncResult<Value, Error>) -> () in
            
            //TODO !!! result.error?.writeErrorWithJLogger()
            finishCallback?(result: result)
        }
        
        let cancel = loader(
            progressCallback: progressCallback,
            stateCallback   : stateCallback,
            finishCallback  : wrappedDoneCallback)
        
        return cancel
    }
}

public func ignoreProgressLoader<Value, Error: ErrorType>(loader: JAsyncTypes<Value, Error>.JAsync) -> JAsyncTypes<Value, Error>.JAsync
{
    return { (
        progressCallback: JAsyncProgressCallback?,
        stateCallback   : JAsyncChangeStateCallback?,
        finishCallback  : JAsyncTypes<Value, Error>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
        return loader(
            progressCallback: progressCallback,
            stateCallback   : stateCallback,
            finishCallback  : finishCallback)
    }
}
