//
//  AsyncHelpers.swift
//  iAsync_async
//
//  Created by Vladimir Gorbenko on 11.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

public func async<Value, Error>(result result: AsyncResult<Value, Error>) -> AsyncTypes<Value, Error>.Async {

    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> AsyncHandler in

        doneCallback?(result: result)
        return jStubHandlerAsyncBlock
    }
}

public func async<Value, Error>(value value: Value) -> AsyncTypes<Value, Error>.Async {

    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> AsyncHandler in

        doneCallback?(result: .Success(value))
        return jStubHandlerAsyncBlock
    }
}

public func async<Value, Error>(value: Value, progress: AnyObject) -> AsyncTypes<Value, Error>.Async {

    return { (
        progressCallback: AsyncProgressCallback?,
        stateCallback   : AsyncChangeStateCallback?,
        doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> AsyncHandler in

        progressCallback?(progressInfo: progress)
        doneCallback?(result: .Success(value))
        return jStubHandlerAsyncBlock
    }
}

public func async<Value, Error: ErrorType>(error error: Error) -> AsyncTypes<Value, Error>.Async {

    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> AsyncHandler in

        doneCallback?(result: .Failure(error))
        return jStubHandlerAsyncBlock
    }
}

public func async<Value, Error: ErrorType>(task task: AsyncHandlerTask) -> AsyncTypes<Value, Error>.Async {

    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> AsyncHandler in

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
              doneCallback    : AsyncTypes<AnyObject, NSError>.DidFinishAsyncCallback?) -> AsyncHandler in

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
              doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> AsyncHandler in

        let result = sameThreadJob()
        doneCallback?(result: result)
        return jStubHandlerAsyncBlock
    }
}

public func asyncWithFinishCallbackBlock<Value, Error>(
    loader: AsyncTypes<Value, Error>.Async,
    finishCallback: AsyncTypes<Value, Error>.DidFinishAsyncCallback) -> AsyncTypes<Value, Error>.Async
{
    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> AsyncHandler in

        return loader(
            progressCallback: progressCallback,
            stateCallback   : stateCallback,
            finishCallback  : { (result: AsyncResult<Value, Error>) -> () in

            finishCallback(result: result)
            doneCallback?(result: result)
        })
    }
}

public func asyncWithFinishHookBlock<Value1, Value2, Error>(loader: AsyncTypes<Value1, Error>.Async, finishCallbackHook: AsyncTypes2<Value1, Value2, Error>.JDidFinishAsyncHook) -> AsyncTypes<Value2, Error>.Async
{
    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              finishCallback  : AsyncTypes<Value2, Error>.DidFinishAsyncCallback?) -> AsyncHandler in

        return loader(
            progressCallback: progressCallback,
            stateCallback   : stateCallback   ,
            finishCallback  : { (result: AsyncResult<Value1, Error>) -> () in

            finishCallbackHook(result: result, finishCallback: finishCallback)
        })
    }
}

public func asyncWithStartAndFinishBlocks<Value, Error>(
    loader        : AsyncTypes<Value, Error>.Async,
    startCallback : SimpleBlock?,
    finishCallback: AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> AsyncTypes<Value, Error>.Async
{
    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> AsyncHandler in

        startCallback?()

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
              doneCallbackOption: AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> AsyncHandler in

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

public func logErrorForLoader<Value>(loader: AsyncTypes<Value, NSError>.Async) -> AsyncTypes<Value, NSError>.Async
{
    return { (
        progressCallback: AsyncProgressCallback?,
        stateCallback   : AsyncChangeStateCallback?,
        finishCallback  : AsyncTypes<Value, NSError>.DidFinishAsyncCallback?) -> AsyncHandler in

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
        finishCallback  : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> AsyncHandler in

        return loader(
            progressCallback: progressCallback,
            stateCallback   : stateCallback,
            finishCallback  : finishCallback)
    }
}
