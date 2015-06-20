//
//  JAsyncHelpers.swift
//  JAsync
//
//  Created by Vladimir Gorbenko on 11.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

import Result

public func async<T>(resultOrError result: Result<T, NSError>) -> JAsyncTypes<T>.JAsync {
    
    return { (progressCallback: JAsyncProgressCallback?,
        stateCallback: JAsyncChangeStateCallback?,
        doneCallback: JAsyncTypes<T>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
        doneCallback?(result: result)
        return jStubHandlerAsyncBlock
    }
}

public func async<T>(result result: T) -> JAsyncTypes<T>.JAsync {
    
    return { (progressCallback: JAsyncProgressCallback?,
              stateCallback: JAsyncChangeStateCallback?,
              doneCallback: JAsyncTypes<T>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
        doneCallback?(result: Result.success(result))
        return jStubHandlerAsyncBlock
    }
}

public func async<T>(error error: NSError) -> JAsyncTypes<T>.JAsync {
    
    return { (progressCallback: JAsyncProgressCallback?,
              stateCallback   : JAsyncChangeStateCallback?,
              doneCallback    : JAsyncTypes<T>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
        doneCallback?(result: Result.failure(error))
        return jStubHandlerAsyncBlock
    }
}

public func async<T>(task task: JAsyncHandlerTask) -> JAsyncTypes<T>.JAsync {
    
    return { (progressCallback: JAsyncProgressCallback?,
              stateCallback: JAsyncChangeStateCallback?,
              doneCallback: JAsyncTypes<T>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
        processHandlerTast(task, stateCallback: stateCallback, doneCallback: doneCallback)
        return jStubHandlerAsyncBlock
    }
}

public func processHandlerTast<T>(
    task         : JAsyncHandlerTask,
    stateCallback: JAsyncChangeStateCallback?,
    doneCallback : JAsyncTypes<T>.JDidFinishAsyncCallback?) {
        
    let errorOption = JAsyncAbstractFinishError.buildFinishError(task)
    
    if let error = errorOption {
        
        doneCallback?(result: Result.failure(error))
    } else {
        
        assert(task.rawValue <= JAsyncHandlerTask.Undefined.rawValue)
        
        stateCallback?(state: task == .Suspend
            ?JAsyncState.Suspended
            :JAsyncState.Resumed)
    }
}

func neverFinishAsync() -> JAsyncTypes<AnyObject>.JAsync {
    
    return { (progressCallback: JAsyncProgressCallback?,
              stateCallback   : JAsyncChangeStateCallback?,
              doneCallback    : JAsyncTypes<AnyObject>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
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

public func async<T>(sameThreadJob sameThreadJob: JAsyncTypes<T>.JSyncOperation) -> JAsyncTypes<T>.JAsync
{
    return { (progressCallback: JAsyncProgressCallback?,
              stateCallback   : JAsyncChangeStateCallback?,
              doneCallback    : JAsyncTypes<T>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
        doneCallback?(result: sameThreadJob())
        return jStubHandlerAsyncBlock
    }
}

public func asyncWithFinishCallbackBlock<T>(
    loader: JAsyncTypes<T>.JAsync,
    finishCallbackBlock: JAsyncTypes<T>.JDidFinishAsyncCallback) -> JAsyncTypes<T>.JAsync
{
    return { (progressCallback: JAsyncProgressCallback?,
              stateCallback   : JAsyncChangeStateCallback?,
              doneCallback    : JAsyncTypes<T>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
        return loader(
            progressCallback: progressCallback,
            stateCallback   : stateCallback,
            finishCallback  : { (result: Result<T, NSError>) -> () in
                
            finishCallbackBlock(result: result)
            doneCallback?(result: result)
        })
    }
}

public func asyncWithFinishHookBlock<T, R>(loader: JAsyncTypes<T>.JAsync, finishCallbackHook: JAsyncTypes2<T, R>.JDidFinishAsyncHook) -> JAsyncTypes<R>.JAsync
{
    return { (progressCallback: JAsyncProgressCallback?,
              stateCallback   : JAsyncChangeStateCallback?,
              finishCallback  : JAsyncTypes<R>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
        return loader(
            progressCallback: progressCallback,
            stateCallback   : stateCallback   ,
            finishCallback: { (result: Result<T, NSError>) -> () in
            
            finishCallbackHook(result: result, finishCallback: finishCallback)
        })
    }
}

func asyncWithStartAndFinishBlocks<T>(
    loader          : JAsyncTypes<T>.JAsync,
    startBlockOption: SimpleBlock?,
    finishCallback  : JAsyncTypes<T>.JDidFinishAsyncCallback?) -> JAsyncTypes<T>.JAsync
{
    return { (progressCallback: JAsyncProgressCallback?,
              stateCallback   : JAsyncChangeStateCallback?,
              doneCallback    : JAsyncTypes<T>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
        startBlockOption?()
        
        let wrappedDoneCallback = { (result: Result<T, NSError>) -> () in
            
            finishCallback?(result: result)
            doneCallback?(result: result)
        }
        return loader(
            progressCallback: progressCallback,
            stateCallback   : stateCallback   ,
            finishCallback  : wrappedDoneCallback)
    }
}

func asyncWithOptionalStartAndFinishBlocks<T>(
    loader        : JAsyncTypes<T>.JAsync,
    startBlock    : SimpleBlock?,
    finishCallback: JAsyncTypes<T>.JDidFinishAsyncCallback?) -> JAsyncTypes<T>.JAsync
{
    return { (progressCallback: JAsyncProgressCallback?,
              stateCallback   : JAsyncChangeStateCallback?,
              doneCallbackOption: JAsyncTypes<T>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
        var loading = true
        
        let wrappedDoneCallback = { (result: Result<T, NSError>) -> () in
            
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

func asyncWithChangedProgress<T>(
    loader: JAsyncTypes<T>.JAsync,
    resultBuilder: UtilsBlockDefinitions2<AnyObject, AnyObject>.JMappingBlock) -> JAsyncTypes<T>.JAsync
{
    return { (progressCallback: JAsyncProgressCallback?,
              stateCallback   : JAsyncChangeStateCallback?,
              finishCallback  : JAsyncTypes<T>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
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

public func logErrorForLoader<T>(loader: JAsyncTypes<T>.JAsync) -> JAsyncTypes<T>.JAsync
{
    return { (
        progressCallback: JAsyncProgressCallback?,
        stateCallback   : JAsyncChangeStateCallback?,
        finishCallback  : JAsyncTypes<T>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
        let wrappedDoneCallback = { (result: Result<T, NSError>) -> () in
            
            result.error?.writeErrorWithJLogger()
            finishCallback?(result: result)
        }
        
        let cancel = loader(
            progressCallback: progressCallback,
            stateCallback: stateCallback,
            finishCallback: wrappedDoneCallback)
        
        return cancel
    }
}

public func ignoreProgressLoader<T>(loader: JAsyncTypes<T>.JAsync) -> JAsyncTypes<T>.JAsync
{
    return { (
        progressCallback: JAsyncProgressCallback?,
        stateCallback   : JAsyncChangeStateCallback?,
        finishCallback  : JAsyncTypes<T>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
        return loader(
            progressCallback: progressCallback,
            stateCallback: stateCallback,
            finishCallback: finishCallback)
    }
}
