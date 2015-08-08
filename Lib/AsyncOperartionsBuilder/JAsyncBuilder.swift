//
//  JAsyncBuilder.swift
//  Async
//
//  Created by Vladimir Gorbenko on 25.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

import Dispatch

public protocol JAsyncInterface {
    
    typealias ValueT : Any
    typealias ErrorT : ErrorType
    
    func asyncWithResultCallback(
        finishCallback  : AsyncTypes<ValueT, ErrorT>.JDidFinishAsyncCallback,
        stateCallback   : AsyncChangeStateCallback,
        progressCallback: AsyncProgressCallback)
    
    func doTask(task: JAsyncHandlerTask)
    
    var isForeignThreadResultCallback: Bool { get }
}

public class JAsyncBuilder<T: JAsyncInterface> {
    
    public typealias JAsyncInstanceBuilder = () -> T
    
    public class func buildWithAdapterFactory(factory: JAsyncInstanceBuilder) -> AsyncTypes<T.ValueT, T.ErrorT>.Async {
        
        assert(NSThread.isMainThread(), "main thread expected")
        return buildWithAdapterFactoryWithDispatchQueue(factory, callbacksQueue: dispatch_get_main_queue())
    }
    
    public class func buildWithAdapterFactoryWithDispatchQueue(
        factory: JAsyncInstanceBuilder,
        callbacksQueue: dispatch_queue_t) -> AsyncTypes<T.ValueT, T.ErrorT>.Async {
            
        return { (
            progressCallback: AsyncProgressCallback?,
            stateCallback   : AsyncChangeStateCallback?,
            finishCallback  : AsyncTypes<T.ValueT, T.ErrorT>.JDidFinishAsyncCallback?) -> JAsyncHandler in
            
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
            
            return { (task: JAsyncHandlerTask) -> () in
                
                if let asyncObject = asyncObject {
                    
                    stateCallbackCalled = false
                    asyncObject.doTask(task)
                    
                    let errorOption: AsyncResult<T.ValueT, T.ErrorT>? = task.buildFinishError()
                    
                    if let error = errorOption {
                        
                        completionHandler(error)
                    } else if !stateCallbackCalled {
                        
                        if let stateCallback = stateCallbackHolder {
                            
                            let state = (task == .Resume)
                                ?JAsyncState.Resumed
                                :JAsyncState.Suspended
                            stateCallback(state: state)
                        }
                        stateCallbackCalled = false
                    }
                }
            }
        }
    }
}
