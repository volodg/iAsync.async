//
//  JTimerAsyncHelpers.swift
//  Timer
//
//  Created by Vladimir Gorbenko on 27.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

//TODO remove inheritence from NSObject
public class JAsyncTimerResult : NSObject {}

//TODO remove inheritence from NSObject
private class JAsyncScheduler : NSObject, JAsyncInterface {
    
    typealias ErrorT = NSError //TODO use NoError
    typealias ValueT = JAsyncTimerResult
    
    private var _timer: Timer?
    
    private let duration: NSTimeInterval
    private let leeway  : NSTimeInterval
    private let callbacksQueue: dispatch_queue_t
    
    init(duration: NSTimeInterval,
        leeway  : NSTimeInterval,
        callbacksQueue: dispatch_queue_t) {
            
            self.duration = duration
            self.leeway   = leeway
            self.callbacksQueue = callbacksQueue
    }
    
    private var _finishCallback: AsyncTypes<ValueT, ErrorT>.JDidFinishAsyncCallback?
    
    func asyncWithResultCallback(
        finishCallback  : AsyncTypes<ValueT, ErrorT>.JDidFinishAsyncCallback,
        stateCallback   : AsyncChangeStateCallback,
        progressCallback: AsyncProgressCallback) {
            
        _finishCallback   = finishCallback
        
        startIfNeeds()
    }
    
    func doTask(task: JAsyncHandlerTask) {
        
        switch (task) {
            
        case .UnSubscribe, .Cancel, .Suspend:
            _timer = nil
        case .Resume:
            startIfNeeds()
        default:
            assert(false)
        }
    }
    
    var isForeignThreadResultCallback: Bool {
        return false
    }
    
    private func startIfNeeds() {
        
        if _timer != nil {
            return
        }
        
        let timer = Timer()
        _timer = timer
        let cancel = timer.addBlock( { [weak self] (cancel: JCancelScheduledBlock) in
            
            cancel()
            self?._finishCallback?(result: AsyncResult.success(JAsyncTimerResult()))
        }, duration:duration, leeway:leeway, dispatchQueue:callbacksQueue)
    }
}

public func asyncWithDelay(delay: NSTimeInterval, leeway: NSTimeInterval) -> AsyncTypes<JAsyncTimerResult, NSError>.Async {
    
    assert(NSThread.isMainThread(), "main thread expected")
    return asyncWithDelayWithDispatchQueue(delay, leeway, dispatch_get_main_queue())
}

func asyncWithDelayWithDispatchQueue(
    delay         : NSTimeInterval,
    leeway        : NSTimeInterval,
    callbacksQueue: dispatch_queue_t) -> AsyncTypes<JAsyncTimerResult, NSError>.Async
{
    let factory = { () -> JAsyncScheduler in
        
        let asyncObject = JAsyncScheduler(duration: delay, leeway: leeway, callbacksQueue: callbacksQueue)
        return asyncObject
    }
    return JAsyncBuilder.buildWithAdapterFactoryWithDispatchQueue(factory, callbacksQueue: callbacksQueue)
}

public func asyncAfterDelay<Value, Error: ErrorType>(
    delay : NSTimeInterval,
    leeway: NSTimeInterval,
    loader: AsyncTypes<JAsyncTimerResult, NSError>.Async) -> AsyncTypes<JAsyncTimerResult, NSError>.Async
{
    assert(NSThread.isMainThread())
    return asyncAfterDelayWithDispatchQueue(
        delay,
        leeway,
        loader,
        dispatch_get_main_queue())
}

func asyncAfterDelayWithDispatchQueue(
    delay : NSTimeInterval,
    leeway: NSTimeInterval,
    loader: AsyncTypes<JAsyncTimerResult, NSError>.Async,
    callbacksQueue: dispatch_queue_t) -> AsyncTypes<JAsyncTimerResult, NSError>.Async
{
    let timerLoader = asyncWithDelayWithDispatchQueue(delay, leeway, callbacksQueue)
    let delayedLoader = bindSequenceOfAsyncs(timerLoader, { (result: JAsyncTimerResult) -> AsyncTypes<JAsyncTimerResult, NSError>.Async in
        return asyncWithValue(result)
    })
    
    return sequenceOfAsyncs(delayedLoader, loader)
}

enum JRepeatAsyncTypes<Value, Error: ErrorType> {
    
    typealias JContinueLoaderWithResult = (result: AsyncResult<Value, Error>) -> AsyncTypes<Value, Error>.Async?
}

public func repeatAsync<Value, Error: ErrorType>(
    nativeLoader: AsyncTypes<Value, Error>.Async,
    continueLoaderBuilder: JRepeatAsyncTypes<Value, Error>.JContinueLoaderWithResult,
    maxRepeatCount: Int/*remove redundent parameter*/) -> AsyncTypes<Value, Error>.Async
{
    return { (
        progressCallback: AsyncProgressCallback?,
        stateCallback   : AsyncChangeStateCallback?,
        finishCallback  : AsyncTypes<Value, Error>.JDidFinishAsyncCallback?) -> JAsyncHandler in
        
        var currentLoaderHandlerHolder: JAsyncHandler?
        
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
        let doneCallbackkWrapper = { (result: AsyncResult<Value, Error>) -> () in
            
            if let finishCallback = finishCallbackHolder {
                finishCallbackHolder = nil
                finishCallback(result: result)
            }
        }
        
        var currentLeftCount = maxRepeatCount
        
        let clearCallbacks = { () -> () in
            progressCallbackHolder = nil
            stateCallbackHolder    = nil
            finishCallbackHolder   = nil
        }
        
        var finishHookHolder: AsyncTypes2<Value, Value, Error>.JDidFinishAsyncHook?
        
        let finishCallbackHook = { (result: AsyncResult<Value, Error>, _: AsyncTypes<Value, Error>.JDidFinishAsyncCallback?) -> () in
            
            let finish = { () -> () in
                
                finishHookHolder = nil
                doneCallbackkWrapper(result)
                
                clearCallbacks()
            }
            
            switch result {
            case .Interrupted:
                finish()
                return
            default:
                break
            }
            
            var newLoader = continueLoaderBuilder(result: result)
            
            if newLoader == nil || currentLeftCount == 0 {
                
                finish()
            } else {
                
                currentLeftCount = currentLeftCount > 0
                    ?currentLeftCount - 1
                    :currentLeftCount
                
                let loader = asyncWithFinishHookBlock(newLoader!, finishHookHolder!)
                
                currentLoaderHandlerHolder = loader(
                    progressCallback: progressCallbackWrapper,
                    stateCallback   : stateCallbackWrapper,
                    finishCallback  : doneCallbackkWrapper)
            }
        }
        
        finishHookHolder = finishCallbackHook
        
        let loader = asyncWithFinishHookBlock(nativeLoader, finishCallbackHook)
        
        currentLoaderHandlerHolder = loader(
            progressCallback: progressCallback,
            stateCallback   : stateCallbackWrapper,
            finishCallback  : doneCallbackkWrapper)
        
        return { (task: JAsyncHandlerTask) -> () in
            
            if task == .Cancel {
                finishHookHolder = nil
            }
            
            if let handler = currentLoaderHandlerHolder {
                
                if task == .UnSubscribe {
                    
                    clearCallbacks()
                } else {
                    
                    handler(task: task)
                    
                    if task == .Cancel {
                        currentLoaderHandlerHolder = nil
                    }
                }
            }
        }
    }
}

//TODO add Error template arg
public func repeatAsyncWithDelayLoader<Value>(
    nativeLoader         : AsyncTypes<Value, NSError>.Async,
    continueLoaderBuilder: JRepeatAsyncTypes<Value, NSError>.JContinueLoaderWithResult,
    delay                : NSTimeInterval,
    leeway               : NSTimeInterval,
    maxRepeatCount: Int) -> AsyncTypes<Value, NSError>.Async
{
    let continueLoaderBuilderWrapper = { (result: AsyncResult<Value, NSError>) -> AsyncTypes<Value, NSError>.Async? in
        
        let loaderOption = continueLoaderBuilder(result: result)
        
        if let loader = loaderOption {
            let timerLoader = asyncWithDelay(delay, leeway)
            let delayedLoader = bindSequenceOfAsyncs(timerLoader, { (result: JAsyncTimerResult) -> AsyncTypes<JAsyncTimerResult, NSError>.Async in
                
                return asyncWithValue(result)
            })
            
            return sequenceOfAsyncs(delayedLoader, loader)
        }
        
        return nil
    }
    
    return repeatAsync(nativeLoader, continueLoaderBuilderWrapper, maxRepeatCount)
}
