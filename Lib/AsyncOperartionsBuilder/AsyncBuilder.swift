//
//  AsyncBuilder.swift
//  iAsync
//
//  Created by Vladimir Gorbenko on 25.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

import Dispatch

public protocol AsyncInterface {
    
    typealias ValueT : Any
    typealias ErrorT : ErrorType
    
    func asyncWithResultCallback(
        finishCallback  : AsyncTypes<ValueT, ErrorT>.DidFinishAsyncCallback,
        stateCallback   : AsyncChangeStateCallback,
        progressCallback: AsyncProgressCallback)
    
    func doTask(task: AsyncHandlerTask)
    
    var isForeignThreadResultCallback: Bool { get }
}

public class AsyncBuilder<T: AsyncInterface> {
    
    public typealias AsyncInstanceBuilder = () -> T
    
    public class func buildWithAdapterFactory(factory: AsyncInstanceBuilder) -> AsyncTypes<T.ValueT, T.ErrorT>.Async {
        
        assert(NSThread.isMainThread(), "main thread expected")
        return buildWithAdapterFactoryWithDispatchQueue(factory, callbacksQueue: dispatch_get_main_queue())
    }
    
    public class func buildWithAdapterFactoryWithDispatchQueue(
        factory: AsyncInstanceBuilder,
        callbacksQueue: dispatch_queue_t) -> AsyncTypes<T.ValueT, T.ErrorT>.Async {
            
        return { (
            progressCallback: AsyncProgressCallback?,
            stateCallback   : AsyncChangeStateCallback?,
            finishCallback  : AsyncTypes<T.ValueT, T.ErrorT>.DidFinishAsyncCallback?) -> JAsyncHandler in
            
            var asyncObject: T? = factory()
            
            var progressCallbackHolder = progressCallback
            var stateCallbackHolder    = stateCallback
            
            let currentThread = NSThread.currentThread()
            
            var finishCallbackHolder = finishCallback
            
            let completionHandler = { (result: AsyncResult<T.ValueT, T.ErrorT>) -> () in
                
                if asyncObject == nil {
                    return
                }
                
                if let finishCallback = finishCallbackHolder {
                    finishCallbackHolder = nil
                    finishCallback(result: result)
                }
                
                progressCallbackHolder = nil
                stateCallbackHolder    = nil
                
                asyncObject = nil
            }
            
            let completionHandlerWrapper = { (result: AsyncResult<T.ValueT, T.ErrorT>) -> Void in
                
                if let asyncObject = asyncObject {
                    
                    if asyncObject.isForeignThreadResultCallback {
                        
                        dispatch_async(callbacksQueue, { () -> () in
                            completionHandler(result)
                            return
                        })
                    } else {
                    
                        assert(dispatch_get_main_queue() !== callbacksQueue || currentThread === NSThread.currentThread(), "the same thread expected")
                        completionHandler(result)
                    }
                }
            }
            
            let progressHandlerWrapper = { (progressInfo: AnyObject) -> () in
                
                progressCallbackHolder?(progressInfo: progressInfo)
                return
            }
            
            var stateCallbackCalled = false
            
            let handlerCallbackWrapper = { (state: JAsyncState) -> () in
                
                stateCallbackCalled = true
                if finishCallbackHolder == nil {
                    return
                }
                
                stateCallbackHolder?(state: state)
            }
            
            asyncObject!.asyncWithResultCallback(
                completionHandlerWrapper,
                stateCallback   : handlerCallbackWrapper,
                progressCallback: progressHandlerWrapper)
            
            return { (task: AsyncHandlerTask) -> () in
                
                if let asyncObject = asyncObject {
                    
                    stateCallbackCalled = false
                    asyncObject.doTask(task)
                    
                    let stateCallbackWrapper = { (state: JAsyncState) -> () in
                        
                        stateCallback?(state: state)
                        stateCallbackCalled = false
                    }
                    
                    processHandlerTast(
                        task,
                        stateCallback: stateCallbackCalled ? nil : stateCallbackWrapper,
                        doneCallback : completionHandler)
                }
            }
        }
    }
}
