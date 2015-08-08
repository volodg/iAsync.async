//
//  JAsyncContinuity.swift
//  JAsync
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
    loader1: JAsyncTypes<Result1, Error>.JAsync,
    _ loader2: JAsyncTypes<Result2, Error>.JAsync) -> JAsyncTypes<Result2, Error>.JAsync {
    
    let binder1 = { (result: JWaterwallFirstObject) -> JAsyncTypes<Result1, Error>.JAsync in
        return loader1
    }
    let binder2 = { (result: Result1) -> JAsyncTypes<Result2, Error>.JAsync in
        return loader2
    }
    let binder = bindSequenceOfBindersPair(binder1, binder2)
    return binder(JWaterwallFirstObject.sharedWaterwallFirstObject())
}

public func sequenceOfAsyncs<Result1, Result2, Result3, Error: ErrorType>(
    loader1: JAsyncTypes<Result1, Error>.JAsync,
    _ loader2: JAsyncTypes<Result2, Error>.JAsync,
    _ loader3: JAsyncTypes<Result3, Error>.JAsync) -> JAsyncTypes<Result3, Error>.JAsync
{
    return sequenceOfAsyncs(
        sequenceOfAsyncs(loader1, loader2),
        loader3)
}

public func sequenceOfAsyncs<Result1, Result2, Result3, Result4, Error: ErrorType>(
    loader1: JAsyncTypes<Result1, Error>.JAsync,
    _ loader2: JAsyncTypes<Result2, Error>.JAsync,
    _ loader3: JAsyncTypes<Result3, Error>.JAsync,
    _ loader4: JAsyncTypes<Result4, Error>.JAsync) -> JAsyncTypes<Result4, Error>.JAsync
{
    return sequenceOfAsyncs(
        sequenceOfAsyncs(loader1, loader2, loader3),
        loader4)
}

func sequenceOfAsyncsArray<Value, Error: ErrorType>(loaders: [JAsyncTypes<Value, Error>.JAsync]) -> JAsyncTypes<Value, Error>.JAsync {

    var firstBlock = { (result: JWaterwallFirstObject) -> JAsyncTypes<Value, Error>.JAsync in
        return loaders[0]
    }
    
    for index in 1..<(loaders.count) {
        
        let secondBlockBinder = { (result: Value) -> JAsyncTypes<Value, Error>.JAsync in
            return loaders[index]
        }
        firstBlock = bindSequenceOfBindersPair(firstBlock, secondBlockBinder)
    }
    
    return firstBlock(JWaterwallFirstObject.sharedWaterwallFirstObject())
}

private func bindSequenceOfBindersPair<Param, Result1, Result2, Error: ErrorType>(
    firstBinder : JAsyncTypes2<Param, Result1, Error>.JAsyncBinder,
    _ secondBinder: JAsyncTypes2<Result1, Result2, Error>.JAsyncBinder) -> JAsyncTypes2<Param, Result2, Error>.JAsyncBinder {
    
    return { (bindResult: Param) -> JAsyncTypes<Result2, Error>.JAsync in
        
        return { (
            progressCallback: JAsyncProgressCallback?,
            stateCallback   : JAsyncChangeStateCallback?,
            finishCallback  : JAsyncTypes<Result2, Error>.JDidFinishAsyncCallback?) -> JAsyncHandler in
            
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
                case let .Success(value):
                    let secondLoader = secondBinder(value)
                    handlerBlockHolder = secondLoader(
                        progressCallback: progressCallbackWrapper,
                        stateCallback   : stateCallbackWrapper,
                        finishCallback  : doneCallbackWrapper)
                case let .Failure(error):
                    finished = true
                    doneCallbackWrapper(AsyncResult.failure(error))
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
    firstLoader: JAsyncTypes<R1, Error>.JAsync,
    _ firstBinder: JAsyncTypes2<R1, R2, Error>.JAsyncBinder) -> JAsyncTypes<R2, Error>.JAsync
{
    let firstBlock = { (result: JWaterwallFirstObject) -> JAsyncTypes<R1, Error>.JAsync in
        return firstLoader
    }
    
    let binder = bindSequenceOfBindersPair(firstBlock, firstBinder)
    
    return binder(JWaterwallFirstObject.sharedWaterwallFirstObject())
}

public func bindSequenceOfAsyncs<R1, R2, R3, Error: ErrorType>(
    firstLoader : JAsyncTypes<R1, Error>.JAsync,
    _ firstBinder : JAsyncTypes2<R1, R2, Error>.JAsyncBinder,
    _ secondBinder: JAsyncTypes2<R2, R3, Error>.JAsyncBinder) -> JAsyncTypes<R3, Error>.JAsync
{
    let loader = bindSequenceOfAsyncs(
        bindSequenceOfAsyncs(firstLoader, firstBinder),
        secondBinder)
    return loader
}

public func bindSequenceOfAsyncs<R1, R2, R3, R4, Error: ErrorType>(
    firstLoader : JAsyncTypes<R1, Error>.JAsync,
    _ binder1: JAsyncTypes2<R1, R2, Error>.JAsyncBinder,
    _ binder2: JAsyncTypes2<R2, R3, Error>.JAsyncBinder,
    _ binder3: JAsyncTypes2<R3, R4, Error>.JAsyncBinder) -> JAsyncTypes<R4, Error>.JAsync
{
    let loader = bindSequenceOfAsyncs(
        bindSequenceOfAsyncs(firstLoader, binder1, binder2), binder3)
    return loader
}

public func bindSequenceOfAsyncs<R1, R2, R3, R4, R5, Error: ErrorType>(
    firstLoader : JAsyncTypes<R1, Error>.JAsync,
    _ binder1: JAsyncTypes2<R1, R2, Error>.JAsyncBinder,
    _ binder2: JAsyncTypes2<R2, R3, Error>.JAsyncBinder,
    _ binder3: JAsyncTypes2<R3, R4, Error>.JAsyncBinder,
    _ binder4: JAsyncTypes2<R4, R5, Error>.JAsyncBinder) -> JAsyncTypes<R5, Error>.JAsync
{
    let loader = bindSequenceOfAsyncs(
        bindSequenceOfAsyncs(firstLoader, binder1, binder2, binder3), binder4)
    return loader
}

/////////////////////////////// SEQUENCE WITH BINDING ///////////////////////////////

//calls binders while success
public func binderAsSequenceOfBinders<T, Error: ErrorType>(binders: JAsyncTypes2<T, T, Error>.JAsyncBinder...) -> JAsyncTypes2<T, T, Error>.JAsyncBinder {
    
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
public func trySequenceOfAsyncs<Value, Error: ErrorType>(
    firstLoader: JAsyncTypes<Value, Error>.JAsync,
    _ nextLoaders: JAsyncTypes<Value, Error>.JAsync...) -> JAsyncTypes<Value, Error>.JAsync
{
    var allLoaders = [firstLoader]
    allLoaders += nextLoaders
    
    return trySequenceOfAsyncsArray(allLoaders)
}

public func trySequenceOfAsyncsArray<Value, Error: ErrorType>(loaders: [JAsyncTypes<Value, Error>.JAsync]) -> JAsyncTypes<Value, Error>.JAsync {
    
    assert(loaders.count > 0)
    
    var firstBlock = { (result: JWaterwallFirstObject) -> JAsyncTypes<Value, Error>.JAsync in
        return loaders[0]
    }
    
    for index in 1..<(loaders.count) {
        
        let secondBlockBinder = { (result: Error) -> JAsyncTypes<Value, Error>.JAsync in
            return loaders[index]
        }
        firstBlock = bindTrySequenceOfBindersPair(firstBlock, secondBlockBinder)
    }
    
    return firstBlock(JWaterwallFirstObject.sharedWaterwallFirstObject())
}

private func bindTrySequenceOfBindersPair<Value, Result, Error: ErrorType>(
    firstBinder: JAsyncTypes2<Value, Result, Error>.JAsyncBinder,
    _ secondBinder: JAsyncTypes2<Error, Result, Error>.JAsyncBinder?) -> JAsyncTypes2<Value, Result, Error>.JAsyncBinder
{
    if let secondBinder = secondBinder {
        
        return { (binderResult: Value) -> JAsyncTypes<Result, Error>.JAsync in
            
            let firstLoader = firstBinder(binderResult)
            
            return { (progressCallback: JAsyncProgressCallback?,
                      stateCallback   : JAsyncChangeStateCallback?,
                      finishCallback  : JAsyncTypes<Result, Error>.JDidFinishAsyncCallback?) -> JAsyncHandler in
                
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
                        case let .Success(value):
                            doneCallbackWrapper(AsyncResult.success(value))
                        case let .Failure(error):
                            let secondLoader = secondBinder(error)
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
public func bindTrySequenceOfAsyncs<Value, Error: ErrorType>(
    firstLoader: JAsyncTypes<Value, Error>.JAsync,
    _ nextBinders: JAsyncTypes2<Error, Value, Error>.JAsyncBinder...) -> JAsyncTypes<Value, Error>.JAsync {
    
    var firstBlock = { (data: JWaterwallFirstObject) -> JAsyncTypes<Value, Error>.JAsync in
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
    firstLoader : JAsyncTypes<Value1, Error>.JAsync,
    _ secondLoader: JAsyncTypes<Value2, Error>.JAsync) -> JAsyncTypes<(Value1, Value2), Error>.JAsync
{
    return groupOfAsyncsPair(firstLoader, secondLoader)
}

public func groupOfAsyncs<Value1, Value2, Value3, Error: ErrorType>(
    firstLoader : JAsyncTypes<Value1, Error>.JAsync,
    _ secondLoader: JAsyncTypes<Value2, Error>.JAsync,
    _ thirdLoader : JAsyncTypes<Value3, Error>.JAsync) -> JAsyncTypes<(Value1, Value2, Value3), Error>.JAsync
{
    let loader = groupOfAsyncsPair(firstLoader, secondLoader)
    
    return bindSequenceOfAsyncs(loader, { (r1, r2)  -> JAsyncTypes<(Value1, Value2, Value3), Error>.JAsync in
        
        return bindSequenceOfAsyncs(thirdLoader, { r3  -> JAsyncTypes<(Value1, Value2, Value3), Error>.JAsync in
            
            return async(value: (r1, r2, r3))
        })
    })
}

public func groupOfAsyncsArray<Value, Error: ErrorType>(loaders: [JAsyncTypes<Value, Error>.JAsync]) -> JAsyncTypes<[Value], Error>.JAsync {
    
    if loaders.count == 0 {
        return async(value: [])
    }
    
    func resultToArrayForLoader(loader: JAsyncTypes<Value, Error>.JAsync) -> JAsyncTypes<[Value], Error>.JAsync {
        
        return bindSequenceOfAsyncs(loader, { (value: Value) -> JAsyncTypes<[Value], Error>.JAsync in
            
            return async(value: [value])
        })
    }
    
    func pairToArrayForLoader(loader: JAsyncTypes<([Value], Value), Error>.JAsync) -> JAsyncTypes<[Value], Error>.JAsync {
        
        return bindSequenceOfAsyncs(loader, { (value: ([Value], Value)) -> JAsyncTypes<[Value], Error>.JAsync in
            
            return async(value: value.0 + [value.1])
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
    
    var progressCallbackHolder: JAsyncProgressCallback?
    var stateCallbackHolder   : JAsyncChangeStateCallback?
    var finishCallbackHolder  : JAsyncTypes<(Value1, Value2), Error>.JDidFinishAsyncCallback?
    
    init(progressCallback: JAsyncProgressCallback?,
         stateCallback   : JAsyncChangeStateCallback?,
         finishCallback  : JAsyncTypes<(Value1, Value2), Error>.JDidFinishAsyncCallback?)
    {
        progressCallbackHolder = progressCallback
        stateCallbackHolder    = stateCallback
        finishCallbackHolder   = finishCallback
    }
}

private func makeResultHandler<Value, Value1, Value2, Error: ErrorType>(
    index index: Int,
    resultSetter: (v: Value, fields: ResultHandlerData<Value1, Value2, Error>) -> (),
    fields: ResultHandlerData<Value1, Value2, Error>
    ) -> JAsyncTypes<Value, Error>.JDidFinishAsyncCallback
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
            
            resultSetter(v: v, fields: fields)
            
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
                finish(result: AsyncResult.failure(error))
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

private func groupOfAsyncsPair<Value1, Value2, Error: ErrorType>(
    firstLoader: JAsyncTypes<Value1, Error>.JAsync,
    _ secondLoader: JAsyncTypes<Value2, Error>.JAsync) -> JAsyncTypes<(Value1, Value2), Error>.JAsync
{
    return { (progressCallback: JAsyncProgressCallback?,
              stateCallback   : JAsyncChangeStateCallback?,
              finishCallback  : JAsyncTypes<(Value1, Value2), Error>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
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
        
        let firstLoaderResultHandler = makeResultHandler(index: 0, resultSetter: setter1, fields: fields)
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

        let secondLoaderResultHandler = makeResultHandler(index: 1, resultSetter: setter2, fields: fields)
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
public func asyncWithDoneBlock<Value, Error: ErrorType>(loader: JAsyncTypes<Value, Error>.JAsync, doneCallbackHook: SimpleBlock?) -> JAsyncTypes<Value, Error>.JAsync {
    
    if let doneCallbackHook = doneCallbackHook {
        
        return { (
            progressCallback: JAsyncProgressCallback?,
            stateCallback   : JAsyncChangeStateCallback?,
            finishCallback  : JAsyncTypes<Value, Error>.JDidFinishAsyncCallback?) -> JAsyncHandler in
            
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
