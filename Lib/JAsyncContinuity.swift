//
//  JAsyncContinuity.swift
//  Async
//
//  Created by Vladimir Gorbenko on 12.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

private var waterfallFirstObjectInstance: JWaterwallFirstObject? = nil

private class JWaterwallFirstObject {
    
    class func sharedWaterwallFirstObject() -> JWaterwallFirstObject {
        
        if let instance = waterfallFirstObjectInstance {
            return instance
        }
        let instance = JWaterwallFirstObject()
        waterfallFirstObjectInstance = instance
        return instance
    }
}

//calls loaders while success
public func sequenceOfAsyncs<Result1, Result2, Error: ErrorType>(
    loader1: AsyncTypes<Result1, Error>.Async,
    loader2: AsyncTypes<Result2, Error>.Async) -> AsyncTypes<Result2, Error>.Async {
    
    let binder1 = { (result: JWaterwallFirstObject) -> AsyncTypes<Result1, Error>.Async in
        return loader1
    }
    let binder2 = { (result: Result1) -> AsyncTypes<Result2, Error>.Async in
        return loader2
    }
    let binder = bindSequenceOfBindersPair(binder1, binder2)
    return binder(JWaterwallFirstObject.sharedWaterwallFirstObject())
}

public func sequenceOfAsyncs<Result1, Result2, Result3, Error: ErrorType>(
    loader1: AsyncTypes<Result1, Error>.Async,
    loader2: AsyncTypes<Result2, Error>.Async,
    loader3: AsyncTypes<Result3, Error>.Async) -> AsyncTypes<Result3, Error>.Async
{
    return sequenceOfAsyncs(
        sequenceOfAsyncs(loader1, loader2),
        loader3)
}

public func sequenceOfAsyncs<Result1, Result2, Result3, Result4, Error: ErrorType>(
    loader1: AsyncTypes<Result1, Error>.Async,
    loader2: AsyncTypes<Result2, Error>.Async,
    loader3: AsyncTypes<Result3, Error>.Async,
    loader4: AsyncTypes<Result4, Error>.Async) -> AsyncTypes<Result4, Error>.Async
{
    return sequenceOfAsyncs(
        sequenceOfAsyncs(loader1, loader2, loader3),
        loader4)
}

func sequenceOfAsyncsArray<Value, Error: ErrorType>(loaders: [AsyncTypes<Value, Error>.Async]) -> AsyncTypes<Value, Error>.Async {

    var firstBlock = { (result: JWaterwallFirstObject) -> AsyncTypes<Value, Error>.Async in
        return loaders[0]
    }
    
    for index in 1..<(loaders.count) {
        
        let secondBlockBinder = { (result: Value) -> AsyncTypes<Value, Error>.Async in
            return loaders[index]
        }
        firstBlock = bindSequenceOfBindersPair(firstBlock, secondBlockBinder)
    }
    
    return firstBlock(JWaterwallFirstObject.sharedWaterwallFirstObject())
}

private func bindSequenceOfBindersPair<Param, Result1, Result2, Error: ErrorType>(
    firstBinder : AsyncTypes2<Param, Result1, Error>.JAsyncBinder,
    secondBinder: AsyncTypes2<Result1, Result2, Error>.JAsyncBinder) -> AsyncTypes2<Param, Result2, Error>.JAsyncBinder {
    
    return { (bindResult: Param) -> AsyncTypes<Result2, Error>.Async in
        
        return { (
            progressCallback: AsyncProgressCallback?,
            stateCallback   : AsyncChangeStateCallback?,
            finishCallback  : AsyncTypes<Result2, Error>.JDidFinishAsyncCallback?) -> JAsyncHandler in
            
            var handlerBlockHolder: JAsyncHandler?
            
            var progressCallbackHolder = progressCallback
            var stateCallbackHolder    = stateCallback
            var finishCallbackHolder   = finishCallback
            
            let progressCallbackWrapper = { (progressInfo: AnyObject) -> () in
                
                progressCallbackHolder?(progressInfo: progressInfo)
            }
            let stateCallbackWrapper = { (state: JAsyncState) -> () in
                
                stateCallbackHolder?(state: state)
            }
            let doneCallbackWrapper = { (result: AsyncResult<Result2, Error>) -> () in
                
                if let callback = finishCallbackHolder {
                    
                    finishCallbackHolder = nil
                    callback(result: result)
                }
                
                progressCallbackHolder = nil
                stateCallbackHolder    = nil
                handlerBlockHolder     = nil
            }
            
            var finished = false
            
            let fistLoaderDoneCallback = { (result: AsyncResult<Result1, Error>) -> () in
                
                switch result {
                case let .Success(v):
                    let secondLoader = secondBinder(v.value)
                    handlerBlockHolder = secondLoader(
                        progressCallback: progressCallbackWrapper,
                        stateCallback   : stateCallbackWrapper,
                        finishCallback  : doneCallbackWrapper)
                case let .Failure(error):
                    finished = true
                    doneCallbackWrapper(AsyncResult.failure(error.value))
                case .Interrupted:
                    finished = true
                    doneCallbackWrapper(.Interrupted)
                case .Unsubscribed:
                    finished = true
                    doneCallbackWrapper(.Unsubscribed)
                }
            }
            
            let firstLoader = firstBinder(bindResult)
            let firstCancel = firstLoader(
                progressCallback: progressCallbackWrapper,
                stateCallback   : stateCallbackWrapper,
                finishCallback  : fistLoaderDoneCallback)
            
            if finished {
                return jStubHandlerAsyncBlock
            }
            
            if handlerBlockHolder == nil {
                handlerBlockHolder = firstCancel
            }
            
            return { (task: JAsyncHandlerTask) -> () in
                
                if let currentHandler = handlerBlockHolder {
                    
                    if task == .Cancel || task == .UnSubscribe {
                            
                        handlerBlockHolder = nil
                    }
                    
                    if task == .UnSubscribe {
                        finishCallbackHolder?(result: .Unsubscribed)
                    } else {
                        currentHandler(task: task)
                    }
                    
                    if task == .Cancel || task == .UnSubscribe {
                            
                        progressCallbackHolder = nil
                        stateCallbackHolder    = nil
                        finishCallbackHolder   = nil
                    }
                }
            }
        }
    }
}

public func bindSequenceOfAsyncs<R1, R2, Error: ErrorType>(
    firstLoader: AsyncTypes<R1, Error>.Async,
    firstBinder: AsyncTypes2<R1, R2, Error>.JAsyncBinder) -> AsyncTypes<R2, Error>.Async
{
    var firstBlock = { (result: JWaterwallFirstObject) -> AsyncTypes<R1, Error>.Async in
        return firstLoader
    }
    
    let binder = bindSequenceOfBindersPair(firstBlock, firstBinder)
    
    return binder(JWaterwallFirstObject.sharedWaterwallFirstObject())
}

public func bindSequenceOfAsyncs<R1, R2, R3, Error: ErrorType>(
    firstLoader : AsyncTypes<R1, Error>.Async,
    firstBinder : AsyncTypes2<R1, R2, Error>.JAsyncBinder,
    secondBinder: AsyncTypes2<R2, R3, Error>.JAsyncBinder) -> AsyncTypes<R3, Error>.Async
{
    let loader = bindSequenceOfAsyncs(
        bindSequenceOfAsyncs(firstLoader, firstBinder),
        secondBinder)
    return loader
}

public func bindSequenceOfAsyncs<R1, R2, R3, R4, Error: ErrorType>(
    firstLoader : AsyncTypes<R1, Error>.Async,
    binder1: AsyncTypes2<R1, R2, Error>.JAsyncBinder,
    binder2: AsyncTypes2<R2, R3, Error>.JAsyncBinder,
    binder3: AsyncTypes2<R3, R4, Error>.JAsyncBinder) -> AsyncTypes<R4, Error>.Async
{
    let loader = bindSequenceOfAsyncs(
        bindSequenceOfAsyncs(firstLoader, binder1, binder2), binder3)
    return loader
}

public func bindSequenceOfAsyncs<R1, R2, R3, R4, R5, Error: ErrorType>(
    firstLoader : AsyncTypes<R1, Error>.Async,
    binder1: AsyncTypes2<R1, R2, Error>.JAsyncBinder,
    binder2: AsyncTypes2<R2, R3, Error>.JAsyncBinder,
    binder3: AsyncTypes2<R3, R4, Error>.JAsyncBinder,
    binder4: AsyncTypes2<R4, R5, Error>.JAsyncBinder) -> AsyncTypes<R5, Error>.Async
{
    let loader = bindSequenceOfAsyncs(
        bindSequenceOfAsyncs(firstLoader, binder1, binder2, binder3), binder4)
    return loader
}

/////////////////////////////// SEQUENCE WITH BINDING ///////////////////////////////

//calls binders while success
public func binderAsSequenceOfBinders<T, Error: ErrorType>(binders: AsyncTypes2<T, T, Error>.JAsyncBinder...) -> AsyncTypes2<T, T, Error>.JAsyncBinder {
    
    var firstBinder = binders[0]
    
    if binders.count < 2 {
        return firstBinder
    }
    
    for index in 1..<(binders.count) {
        
        firstBinder = bindSequenceOfBindersPair(firstBinder, binders[index])
    }
    
    return firstBinder
}

/////////////////////////////////// TRY SEQUENCE ///////////////////////////////////

//calls loaders untill success
public func trySequenceOfAsyncs<Value, Error: ErrorType>(firstLoader: AsyncTypes<Value, Error>.Async, nextLoaders: AsyncTypes<Value, Error>.Async...) -> AsyncTypes<Value, Error>.Async
{
    var allLoaders = [firstLoader]
    allLoaders += nextLoaders
    
    return trySequenceOfAsyncsArray(allLoaders)
}

public func trySequenceOfAsyncsArray<Value, Error: ErrorType>(loaders: [AsyncTypes<Value, Error>.Async]) -> AsyncTypes<Value, Error>.Async {
    
    assert(loaders.count > 0)
    
    var firstBlock = { (result: JWaterwallFirstObject) -> AsyncTypes<Value, Error>.Async in
        return loaders[0]
    }
    
    for index in 1..<(loaders.count) {
        
        let secondBlockBinder = { (result: Error) -> AsyncTypes<Value, Error>.Async in
            return loaders[index]
        }
        firstBlock = bindTrySequenceOfBindersPair(firstBlock, secondBlockBinder)
    }
    
    return firstBlock(JWaterwallFirstObject.sharedWaterwallFirstObject())
}

private func bindTrySequenceOfBindersPair<Value, Result, Error: ErrorType>(
    firstBinder: AsyncTypes2<Value, Result, Error>.JAsyncBinder,
    secondBinder: AsyncTypes2<Error, Result, Error>.JAsyncBinder?) -> AsyncTypes2<Value, Result, Error>.JAsyncBinder
{
    if let secondBinder = secondBinder {
        
        return { (binderResult: Value) -> AsyncTypes<Result, Error>.Async in
            
            let firstLoader = firstBinder(binderResult)
            
            return { (progressCallback: AsyncProgressCallback?,
                      stateCallback   : AsyncChangeStateCallback?,
                      finishCallback  : AsyncTypes<Result, Error>.JDidFinishAsyncCallback?) -> JAsyncHandler in
                
                var handlerBlockHolder: JAsyncHandler?
                
                var progressCallbackHolder = progressCallback
                var stateCallbackHolder    = stateCallback
                var finishCallbackHolder   = finishCallback
                
                let progressCallbackWrapper = { (progressInfo: AnyObject) -> () in
                    
                    progressCallbackHolder?(progressInfo: progressInfo)
                    return
                }
                let stateCallbackWrapper = { (state: JAsyncState) -> () in
                    
                    stateCallbackHolder?(state: state)
                    return
                }
                let doneCallbackWrapper = { (result: AsyncResult<Result, Error>) -> () in
                    
                    if let finish = finishCallbackHolder {
                        finishCallbackHolder = nil
                        finish(result: result)
                    }
                    
                    progressCallbackHolder = nil
                    stateCallbackHolder    = nil
                    handlerBlockHolder     = nil
                }
                
                let firstHandler = firstLoader(
                    progressCallback: progressCallbackWrapper,
                    stateCallback   : stateCallbackWrapper,
                    finishCallback  : { (result: AsyncResult<Result, Error>) -> () in
                        
                        switch result {
                        case let .Success(v):
                            doneCallbackWrapper(AsyncResult.success(v.value))
                        case let .Failure(error):
                            let secondLoader = secondBinder(error.value)
                            handlerBlockHolder = secondLoader(
                                progressCallback: progressCallbackWrapper,
                                stateCallback   : stateCallbackWrapper,
                                finishCallback  : doneCallbackWrapper)
                        case .Interrupted:
                            doneCallbackWrapper(.Interrupted)
                        case .Unsubscribed:
                            doneCallbackWrapper(.Unsubscribed) //TODO review
                        }
                })
                
                if handlerBlockHolder == nil {
                    handlerBlockHolder = firstHandler
                }
                
                return { (task: JAsyncHandlerTask) -> () in
                    
                    if handlerBlockHolder == nil {
                        return
                    }
                    
                    let currentHandler = handlerBlockHolder
                    
                    if task.unsubscribedOrCanceled {
                        handlerBlockHolder = nil
                    }
                    
                    if task == .UnSubscribe {
                        finishCallbackHolder?(result: .Unsubscribed)
                    } else {
                        currentHandler!(task: task)
                    }
                    
                    if task.unsubscribedOrCanceled {
                        
                        progressCallbackHolder = nil
                        stateCallbackHolder    = nil
                        finishCallbackHolder   = nil
                    }
                }
            }
        }
    }
    
    return firstBinder
}

/////////////////////////////// TRY SEQUENCE WITH BINDING ///////////////////////////////

//calls loaders while success
//@@ next binder will receive an error if previous operation fails
public func bindTrySequenceOfAsyncs<Value, Error: ErrorType>(firstLoader: AsyncTypes<Value, Error>.Async, nextBinders: AsyncTypes2<Error, Value, Error>.JAsyncBinder...) -> AsyncTypes<Value, Error>.Async {
    
    var firstBlock = { (data: JWaterwallFirstObject) -> AsyncTypes<Value, Error>.Async in
        return firstLoader
    }
    
    for nextBinder in nextBinders {
        
        firstBlock = bindTrySequenceOfBindersPair(firstBlock, nextBinder)
    }
    
    return firstBlock(JWaterwallFirstObject.sharedWaterwallFirstObject())
}

/////////////////////////////////////// GROUP //////////////////////////////////////

//calls finish callback when all loaders finished
public func groupOfAsyncs<Value1, Value2, Error: ErrorType>(
    firstLoader : AsyncTypes<Value1, Error>.Async,
    secondLoader: AsyncTypes<Value2, Error>.Async) -> AsyncTypes<(Value1, Value2), Error>.Async
{
    return groupOfAsyncsPair(firstLoader, secondLoader)
}

public func groupOfAsyncs<Value1, Value2, Value3, Error: ErrorType>(
    firstLoader : AsyncTypes<Value1, Error>.Async,
    secondLoader: AsyncTypes<Value2, Error>.Async,
    thirdLoader : AsyncTypes<Value3, Error>.Async) -> AsyncTypes<(Value1, Value2, Value3), Error>.Async
{
    let loader = groupOfAsyncsPair(firstLoader, secondLoader)
    
    return bindSequenceOfAsyncs(loader, { (r1, r2)  -> AsyncTypes<(Value1, Value2, Value3), Error>.Async in
        
        return bindSequenceOfAsyncs(thirdLoader, { r3  -> AsyncTypes<(Value1, Value2, Value3), Error>.Async in
            
            return asyncWithValue((r1, r2, r3))
        })
    })
}

public func groupOfAsyncsArray<Value, Error: ErrorType>(loaders: [AsyncTypes<Value, Error>.Async]) -> AsyncTypes<[Value], Error>.Async {
    
    if loaders.count == 0 {
        return asyncWithValue([])
    }
    
    func resultToArrayForLoader(async: AsyncTypes<Value, Error>.Async) -> AsyncTypes<[Value], Error>.Async {
        
        return bindSequenceOfAsyncs(async, { (value: Value) -> AsyncTypes<[Value], Error>.Async in
            
            return asyncWithValue([value])
        })
    }
    
    func pairToArrayForLoader(async: AsyncTypes<([Value], Value), Error>.Async) -> AsyncTypes<[Value], Error>.Async {
        
        return bindSequenceOfAsyncs(async, { (value: ([Value], Value)) -> AsyncTypes<[Value], Error>.Async in
            
            return asyncWithValue(value.0 + [value.1])
        })
    }
    
    let firstBlock = loaders[0]
    var arrayFirstBlock = resultToArrayForLoader(firstBlock)
    
    for index in 1..<(loaders.count) {
        
        let loader = groupOfAsyncs(arrayFirstBlock, loaders[index])
        arrayFirstBlock = pairToArrayForLoader(loader)
    }
    
    return arrayFirstBlock
}

private class ResultHandlerData<Value1, Value2, Error: ErrorType> {
    
    var finished = false
    var loaded   = false
    
    var completeResult1: Value1? = nil
    var completeResult2: Value2? = nil
    
    var handlerHolder1: JAsyncHandler?
    var handlerHolder2: JAsyncHandler?
    
    var progressCallbackHolder: AsyncProgressCallback?
    var stateCallbackHolder   : AsyncChangeStateCallback?
    var finishCallbackHolder  : AsyncTypes<(Value1, Value2), Error>.JDidFinishAsyncCallback?
    
    init(progressCallback: AsyncProgressCallback?,
         stateCallback   : AsyncChangeStateCallback?,
         finishCallback  : AsyncTypes<(Value1, Value2), Error>.JDidFinishAsyncCallback?)
    {
        progressCallbackHolder = progressCallback
        stateCallbackHolder    = stateCallback
        finishCallbackHolder   = finishCallback
    }
}

private func makeResultHandler<Value, Value1, Value2, Error: ErrorType>(
    index: Int,
    resultSetter: (v: Value, fields: ResultHandlerData<Value1, Value2, Error>) -> (),
    fields: ResultHandlerData<Value1, Value2, Error>
    ) -> AsyncTypes<Value, Error>.JDidFinishAsyncCallback
{
    return { (result: AsyncResult<Value, Error>) -> () in
        
        if fields.finished {
            return
        }
    
        if index == 0 {
            fields.handlerHolder1 = nil
        } else {
            fields.handlerHolder2 = nil
        }
        
        switch result {
        case let .Success(v):
            
            resultSetter(v: v.value, fields: fields)
            
            if fields.loaded {
                
                fields.finished = true
                
                fields.handlerHolder1 = nil
                fields.handlerHolder2 = nil
                
                fields.progressCallbackHolder = nil
                fields.stateCallbackHolder    = nil
                
                if let finish = fields.finishCallbackHolder {
                    fields.finishCallbackHolder   = nil
                    let completeResult = (fields.completeResult1!, fields.completeResult2!)
                    finish(result: AsyncResult.success(completeResult))
                }
            } else {
                
                fields.loaded = true
            }
        case let .Failure(error):
            fields.finished = true
            
            fields.progressCallbackHolder = nil
            fields.stateCallbackHolder    = nil
            
            if let finish = fields.finishCallbackHolder {
                fields.finishCallbackHolder = nil
                finish(result: AsyncResult.failure(error.value))
            }
        case .Interrupted:
            fields.finished = true
            
            fields.progressCallbackHolder = nil
            fields.stateCallbackHolder    = nil
            
            if let finish = fields.finishCallbackHolder {
                fields.finishCallbackHolder = nil
                finish(result: .Interrupted)
            }
        case .Unsubscribed:
            fields.finished = true
            
            fields.progressCallbackHolder = nil
            fields.stateCallbackHolder    = nil
            
            if let finish = fields.finishCallbackHolder {
                fields.finishCallbackHolder = nil
                finish(result: .Unsubscribed)
            }
        }
    }
}

private func groupOfAsyncsPair<Value1, Value2, Error: ErrorType>(firstLoader: AsyncTypes<Value1, Error>.Async, secondLoader: AsyncTypes<Value2, Error>.Async) -> AsyncTypes<(Value1, Value2), Error>.Async
{
    return { (progressCallback: AsyncProgressCallback?,
              stateCallback   : AsyncChangeStateCallback?,
              finishCallback  : AsyncTypes<(Value1, Value2), Error>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
        let fields = ResultHandlerData(
            progressCallback: progressCallback,
            stateCallback   : stateCallback,
            finishCallback  : finishCallback)
        
        let progressCallbackWrapper = { (progressInfo: AnyObject) -> () in
            fields.progressCallbackHolder?(progressInfo: progressInfo)
            return
        }
        
        let stateCallbackWrapper = { (state: JAsyncState) -> () in
            stateCallback?(state: state)
            return
        }
        
        func setter1(val: Value1, fields: ResultHandlerData<Value1, Value2, Error>) {
            fields.completeResult1 = val
        }
        
        let firstLoaderResultHandler = makeResultHandler(0, setter1, fields)
        let loaderHandler1 = firstLoader(
            progressCallback: progressCallbackWrapper,
            stateCallback   : stateCallbackWrapper,
            finishCallback  : firstLoaderResultHandler)
        
        if fields.finished {
            
            runAsync(secondLoader)
            return jStubHandlerAsyncBlock
        }
        
        fields.handlerHolder1 = loaderHandler1
        
        func setter2(val: Value2, fields: ResultHandlerData<Value1, Value2, Error>) {
            fields.completeResult2 = val
        }

        let secondLoaderResultHandler = makeResultHandler(1, setter2, fields)
        let loaderHandler2 = secondLoader(
            progressCallback: progressCallback,
            stateCallback   : stateCallback,
            finishCallback  : secondLoaderResultHandler)
        
        if fields.finished {
            
            return jStubHandlerAsyncBlock
        }
        
        fields.handlerHolder2 = loaderHandler2
        
        return { (task: JAsyncHandlerTask) -> () in
            
            let cancelOrUnSubscribe = task.unsubscribedOrCanceled
            
            if let handler = fields.handlerHolder1 {
                
                if cancelOrUnSubscribe {
                    fields.handlerHolder1 = nil
                }
                handler(task: task)
            }
            
            if let handler = fields.handlerHolder2 {
                
                if cancelOrUnSubscribe {
                    fields.handlerHolder2 = nil
                }
                handler(task: task)
            }
            
            if cancelOrUnSubscribe {
                
                fields.progressCallbackHolder = nil
                fields.stateCallbackHolder    = nil
                fields.finishCallbackHolder   = nil
            }
        }
    }
}

///////////////////////// ADD OBSERVERS OF ASYNC OP. RESULT ////////////////////////

//doneCallbackHook called an cancel or finish loader's callbacks
public func asyncWithDoneBlock<Value, Error: ErrorType>(loader: AsyncTypes<Value, Error>.Async, doneCallbackHook: SimpleBlock?) -> AsyncTypes<Value, Error>.Async {
    
    if let doneCallbackHook = doneCallbackHook {
        
        return { (
            progressCallback: AsyncProgressCallback?,
            stateCallback   : AsyncChangeStateCallback?,
            finishCallback  : AsyncTypes<Value, Error>.JDidFinishAsyncCallback?) -> JAsyncHandler in
            
            let wrappedDoneCallback = { (result: AsyncResult<Value, Error>) -> () in
                
                doneCallbackHook()
                finishCallback?(result: result)
            }
            return loader(
                progressCallback: progressCallback,
                stateCallback   : stateCallback,
                finishCallback  : wrappedDoneCallback)
        }
    }
    
    return loader
}
