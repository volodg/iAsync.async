//
//  JAsyncContinuity.swift
//  iAsync_async
//
//  Created by Vladimir Gorbenko on 12.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

private var waterfallFirstObjectInstance: JWaterwallFirstObject? = nil

final private class JWaterwallFirstObject {

    static func sharedWaterwallFirstObject() -> JWaterwallFirstObject {

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
    _ loader2: AsyncTypes<Result2, Error>.Async) -> AsyncTypes<Result2, Error>.Async {

    let binder1 = { (result: JWaterwallFirstObject) -> AsyncTypes<Result1, Error>.Async in
        return loader1
    }
    let binder2 = { (result: Result1) -> AsyncTypes<Result2, Error>.Async in
        return loader2
    }
    let binder = bindSequenceOfBindersPair(binder1, binder2)
    return binder(JWaterwallFirstObject.sharedWaterwallFirstObject())
}

private func bindSequenceOfBindersPair<Param, Result1, Result2, Error: ErrorType>(
    firstBinder : AsyncTypes2<Param, Result1, Error>.AsyncBinder,
    _ secondBinder: AsyncTypes2<Result1, Result2, Error>.AsyncBinder) -> AsyncTypes2<Param, Result2, Error>.AsyncBinder {

    return { (bindResult: Param) -> AsyncTypes<Result2, Error>.Async in

        return { (
            progressCallback: AsyncProgressCallback?,
            finishCallback  : AsyncTypes<Result2, Error>.DidFinishAsyncCallback?) -> AsyncHandler in

            var handlerBlockHolder: AsyncHandler?

            var progressCallbackHolder = progressCallback
            var finishCallbackHolder   = finishCallback

            let progressCallbackWrapper = { (progressInfo: AnyObject) -> () in

                progressCallbackHolder?(progressInfo: progressInfo)
            }
            let doneCallbackWrapper = { (result: AsyncResult<Result2, Error>) -> () in

                if let callback = finishCallbackHolder {

                    finishCallbackHolder = nil
                    callback(result: result)
                }

                progressCallbackHolder = nil
                handlerBlockHolder     = nil
            }

            var finished = false

            let fistLoaderDoneCallback = { (result: AsyncResult<Result1, Error>) -> () in

                switch result {
                case .Success(let value):
                    let secondLoader = secondBinder(value)
                    handlerBlockHolder = secondLoader(
                        progressCallback: progressCallbackWrapper,
                        finishCallback  : doneCallbackWrapper)
                case .Failure(let error):
                    finished = true
                    doneCallbackWrapper(.Failure(error))
                }
            }

            let firstLoader = firstBinder(bindResult)
            let firstCancel = firstLoader(
                progressCallback: progressCallbackWrapper,
                finishCallback  : fistLoaderDoneCallback)

            if finished {
                return jStubHandlerAsyncBlock
            }

            if handlerBlockHolder == nil {
                handlerBlockHolder = firstCancel
            }

            return { (task: AsyncHandlerTask) -> () in

                guard let currentHandler = handlerBlockHolder else { return }

                if task == .Cancel || task == .UnSubscribe {

                    handlerBlockHolder = nil
                }

                if task != .UnSubscribe {
                    currentHandler(task: task)
                }

                progressCallbackHolder = nil
                finishCallbackHolder   = nil
            }
        }
    }
}

public func bindSequenceOfAsyncs<R1, R2, Error: ErrorType>(
    firstLoader: AsyncTypes<R1, Error>.Async,
    _ firstBinder: AsyncTypes2<R1, R2, Error>.AsyncBinder) -> AsyncTypes<R2, Error>.Async
{
    let firstBlock = { (result: JWaterwallFirstObject) -> AsyncTypes<R1, Error>.Async in
        return firstLoader
    }

    let binder = bindSequenceOfBindersPair(firstBlock, firstBinder)

    return binder(JWaterwallFirstObject.sharedWaterwallFirstObject())
}

public func bindSequenceOfAsyncs2<R1, R2, R3, Error: ErrorType>(
    firstBinder: AsyncTypes2<R1, R2, Error>.AsyncBinder,
    _ secondBinder: AsyncTypes2<R2, R3, Error>.AsyncBinder) -> AsyncTypes2<R1, R3, Error>.AsyncBinder
{
    return bindSequenceOfBindersPair(firstBinder, secondBinder)
}

public func bindSequenceOfAsyncs<R1, R2, R3, Error: ErrorType>(
    firstLoader : AsyncTypes<R1, Error>.Async,
    _ firstBinder : AsyncTypes2<R1, R2, Error>.AsyncBinder,
    _ secondBinder: AsyncTypes2<R2, R3, Error>.AsyncBinder) -> AsyncTypes<R3, Error>.Async
{
    let loader = bindSequenceOfAsyncs(
        bindSequenceOfAsyncs(firstLoader, firstBinder),
        secondBinder)
    return loader
}

/////////////////////////////////// TRY SEQUENCE ///////////////////////////////////

//calls loaders untill success
public func trySequenceOfAsyncs<Value>(
    firstLoader: AsyncTypes<Value, NSError>.Async,
    _ nextLoaders: AsyncTypes<Value, NSError>.Async...) -> AsyncTypes<Value, NSError>.Async
{
    var allLoaders = [firstLoader]
    allLoaders += nextLoaders

    return trySequenceOfAsyncsArray(allLoaders)
}

private func trySequenceOfAsyncsArray<Value>(loaders: [AsyncTypes<Value, NSError>.Async]) -> AsyncTypes<Value, NSError>.Async {

    assert(loaders.count > 0)

    var firstBlock = { (result: JWaterwallFirstObject) -> AsyncTypes<Value, NSError>.Async in
        return loaders[0]
    }

    for index in 1..<(loaders.count) {

        let secondBlockBinder = { (result: NSError) -> AsyncTypes<Value, NSError>.Async in
            return loaders[index]
        }
        firstBlock = bindTrySequenceOfBindersPair(firstBlock, secondBlockBinder)
    }

    return firstBlock(JWaterwallFirstObject.sharedWaterwallFirstObject())
}

private func bindTrySequenceOfBindersPair<Value, Result>(
    firstBinder: AsyncTypes2<Value, Result, NSError>.AsyncBinder,
    _ secondBinder: AsyncTypes2<NSError, Result, NSError>.AsyncBinder?) -> AsyncTypes2<Value, Result, NSError>.AsyncBinder
{
    guard let secondBinder = secondBinder else { return firstBinder }

    return { (binderResult: Value) -> AsyncTypes<Result, NSError>.Async in

        let firstLoader = firstBinder(binderResult)

        return { (progressCallback: AsyncProgressCallback?,
                  finishCallback  : AsyncTypes<Result, NSError>.DidFinishAsyncCallback?) -> AsyncHandler in

            var handlerBlockHolder: AsyncHandler?

            var progressCallbackHolder = progressCallback
            var finishCallbackHolder   = finishCallback

            let progressCallbackWrapper = { (progressInfo: AnyObject) -> () in

                progressCallbackHolder?(progressInfo: progressInfo)
                return
            }
            let doneCallbackWrapper = { (result: AsyncResult<Result, NSError>) -> () in

                if let finish = finishCallbackHolder {
                    finishCallbackHolder = nil
                    finish(result: result)
                }

                progressCallbackHolder = nil
                handlerBlockHolder     = nil
            }

            let firstHandler = firstLoader(
                progressCallback: progressCallbackWrapper,
                finishCallback  : { (result: AsyncResult<Result, NSError>) -> () in

                    switch result {
                    case .Success(let value):
                        doneCallbackWrapper(.Success(value))
                    case .Failure(let error):
                        if error is AsyncInterruptedError {
                            doneCallbackWrapper(result)
                            return
                        }
                        let secondLoader = secondBinder(error)
                        handlerBlockHolder = secondLoader(
                            progressCallback: progressCallbackWrapper,
                            finishCallback  : doneCallbackWrapper)
                    }
            })

            if handlerBlockHolder == nil {
                handlerBlockHolder = firstHandler
            }

            return { (task: AsyncHandlerTask) -> () in

                if handlerBlockHolder == nil {
                    return
                }

                let currentHandler = handlerBlockHolder

                handlerBlockHolder = nil

                if task != .UnSubscribe {
                    currentHandler!(task: task)
                }

                progressCallbackHolder = nil
                finishCallbackHolder   = nil
            }
        }
    }
}

/////////////////////////////// TRY SEQUENCE WITH BINDING ///////////////////////////////

//calls loaders while success
//@@ next binder will receive an error if previous operation fails
public func bindTrySequenceOfAsyncs<Value>(
    firstLoader: AsyncTypes<Value, NSError>.Async,
    _ nextBinders: AsyncTypes2<NSError, Value, NSError>.AsyncBinder...) -> AsyncTypes<Value, NSError>.Async {

    var firstBlock = { (data: JWaterwallFirstObject) -> AsyncTypes<Value, NSError>.Async in
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
    _ secondLoader: AsyncTypes<Value2, Error>.Async) -> AsyncTypes<(Value1, Value2), Error>.Async
{
    return groupOfAsyncsPair(firstLoader, secondLoader)
}

public func groupOfAsyncs<Value1, Value2, Value3, Error: ErrorType>(
    firstLoader : AsyncTypes<Value1, Error>.Async,
    _ secondLoader: AsyncTypes<Value2, Error>.Async,
    _ thirdLoader : AsyncTypes<Value3, Error>.Async) -> AsyncTypes<(Value1, Value2, Value3), Error>.Async
{
    let loader12 = groupOfAsyncsPair(firstLoader, secondLoader)
    let loader   = groupOfAsyncsPair(loader12   , thirdLoader )

    return bindSequenceOfAsyncs(loader, { (r12_3: ((Value1, Value2), Value3))  -> AsyncTypes<(Value1, Value2, Value3), Error>.Async in

        return async(value: (r12_3.0.0, r12_3.0.1, r12_3.1))
    })
}

public func groupOfAsyncs<Value1, Value2, Value3, Value4, Error: ErrorType>(
    firstLoader : AsyncTypes<Value1, Error>.Async,
    _ secondLoader: AsyncTypes<Value2, Error>.Async,
    _ thirdLoader : AsyncTypes<Value3, Error>.Async,
    _ fourthLoader: AsyncTypes<Value4, Error>.Async) -> AsyncTypes<(Value1, Value2, Value3, Value4), Error>.Async
{
    let loader123 = groupOfAsyncs(firstLoader, secondLoader, thirdLoader)
    let loader    = groupOfAsyncs(loader123  , fourthLoader)

    return bindSequenceOfAsyncs(loader, { (r123_4: ((Value1, Value2, Value3), Value4))  -> AsyncTypes<(Value1, Value2, Value3, Value4), Error>.Async in

        return async(value: (r123_4.0.0, r123_4.0.1, r123_4.0.2, r123_4.1))
    })
}

public func groupOfAsyncs<Value1, Value2, Value3, Value4, Value5, Error: ErrorType>(
    firstLoader : AsyncTypes<Value1, Error>.Async,
    _ secondLoader: AsyncTypes<Value2, Error>.Async,
    _ thirdLoader : AsyncTypes<Value3, Error>.Async,
    _ fourthLoader: AsyncTypes<Value4, Error>.Async,
    _ fifthLoader : AsyncTypes<Value5, Error>.Async) -> AsyncTypes<(Value1, Value2, Value3, Value4, Value5), Error>.Async
{
    let loader1234 = groupOfAsyncs(firstLoader, secondLoader, thirdLoader, fourthLoader)
    let loader     = groupOfAsyncs(loader1234 , fifthLoader)

    return bindSequenceOfAsyncs(loader, { (r1234_5: ((Value1, Value2, Value3, Value4), Value5))  -> AsyncTypes<(Value1, Value2, Value3, Value4, Value5), Error>.Async in

        return async(value: (r1234_5.0.0, r1234_5.0.1, r1234_5.0.2, r1234_5.0.3, r1234_5.1))
    })
}

final private class ResultHandlerData<Value1, Value2, Error: ErrorType> {

    var finished = false
    var loaded   = false

    var completeResult1: Value1? = nil
    var completeResult2: Value2? = nil

    var handlerHolder1: AsyncHandler?
    var handlerHolder2: AsyncHandler?

    var progressCallbackHolder: AsyncProgressCallback?
    var finishCallbackHolder  : AsyncTypes<(Value1, Value2), Error>.DidFinishAsyncCallback?

    init(progressCallback: AsyncProgressCallback?,
         finishCallback  : AsyncTypes<(Value1, Value2), Error>.DidFinishAsyncCallback?) {

        progressCallbackHolder = progressCallback
        finishCallbackHolder   = finishCallback
    }
}

private func makeResultHandler<Value, Value1, Value2, Error: ErrorType>(
    index index: Int,
    resultSetter: (v: Value, fields: ResultHandlerData<Value1, Value2, Error>) -> (),
    fields: ResultHandlerData<Value1, Value2, Error>
    ) -> AsyncTypes<Value, Error>.DidFinishAsyncCallback
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
        case .Success(let v):

            resultSetter(v: v, fields: fields)

            if fields.loaded {

                fields.finished = true

                fields.handlerHolder1 = nil
                fields.handlerHolder2 = nil

                fields.progressCallbackHolder = nil

                if let finish = fields.finishCallbackHolder {
                    fields.finishCallbackHolder   = nil
                    let completeResult = (fields.completeResult1!, fields.completeResult2!)
                    finish(result: .Success(completeResult))
                }
            } else {

                fields.loaded = true
            }
        case .Failure(let error):
            fields.finished = true

            fields.progressCallbackHolder = nil

            if let finish = fields.finishCallbackHolder {
                fields.finishCallbackHolder = nil
                finish(result: .Failure(error))
            }
        }
    }
}

private func groupOfAsyncsPair<Value1, Value2, Error: ErrorType>(
    firstLoader: AsyncTypes<Value1, Error>.Async,
    _ secondLoader: AsyncTypes<Value2, Error>.Async) -> AsyncTypes<(Value1, Value2), Error>.Async
{
    return { (progressCallback: AsyncProgressCallback?,
              finishCallback  : AsyncTypes<(Value1, Value2), Error>.DidFinishAsyncCallback?) -> AsyncHandler in

        let fields = ResultHandlerData(
            progressCallback: progressCallback,
            finishCallback  : finishCallback)

        let progressCallbackWrapper = { (progressInfo: AnyObject) -> () in
            fields.progressCallbackHolder?(progressInfo: progressInfo)
            return
        }

        func setter1(val: Value1, fields: ResultHandlerData<Value1, Value2, Error>) {
            fields.completeResult1 = val
        }

        let firstLoaderResultHandler = makeResultHandler(index: 0, resultSetter: setter1, fields: fields)
        let loaderHandler1 = firstLoader(
            progressCallback: progressCallbackWrapper,
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
            finishCallback  : secondLoaderResultHandler)

        if fields.finished {

            return jStubHandlerAsyncBlock
        }

        fields.handlerHolder2 = loaderHandler2

        return { (task: AsyncHandlerTask) -> () in

            if let handler = fields.handlerHolder1 {

                fields.handlerHolder1 = nil
                handler(task: task)
            }

            if let handler = fields.handlerHolder2 {

                fields.handlerHolder2 = nil
                handler(task: task)
            }

            fields.progressCallbackHolder = nil
            fields.finishCallbackHolder   = nil
        }
    }
}
