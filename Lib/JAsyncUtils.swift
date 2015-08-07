//
//  JAsyncUtils.swift
//  JAsync
//
//  Created by Vladimir Gorbenko on 27.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

private let defaultQueueName = "com.jff.async_operations_library.general_queue"

//TODO remove this class
private class JBlockOperation<Value, Error: ErrorType> {
    
    //TODO make atomic
    private var finishedOrCanceled = false
    
    init(
        queueName         : String?,
        jobWithProgress   : JAsyncTypes<Value, Error>.JSyncOperationWithProgress,
        didLoadDataBlock  : JAsyncTypes<Value, Error>.JDidFinishAsyncCallback?,
        progressBlock     : JAsyncProgressCallback?,
        barrier           : Bool,
        currentQueue      : dispatch_queue_t = dispatch_get_main_queue(),
        serialOrConcurrent: dispatch_queue_attr_t = DISPATCH_QUEUE_CONCURRENT)
    {
        let queue: dispatch_queue_t
        
        if let queueName = queueName {
            queue = dispatch_queue_get_or_create(label: queueName, attr: serialOrConcurrent)
        } else {
            queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        }
        
        performBackgroundOperationInQueue(
            queue,
            barrier         : barrier,
            currentQueue    : currentQueue,
            jobWithProgress : jobWithProgress,
            didLoadDataBlock: didLoadDataBlock,
            progressBlock   : progressBlock)
    }
    
    func cancel()  {
        
        if finishedOrCanceled {
            return
        }
        
        finishedOrCanceled = true
    }
    
    //TODO make private
    func performBackgroundOperationInQueue(
        queue           : dispatch_queue_t,
        barrier         : Bool,
        currentQueue    : dispatch_queue_t,
        jobWithProgress : JAsyncTypes<Value, Error>.JSyncOperationWithProgress,
        didLoadDataBlock: JAsyncTypes<Value, Error>.JDidFinishAsyncCallback?,
        progressBlock   : JAsyncProgressCallback?) {
        
        let dispatchAsyncMethod = barrier
            ?{(dispatch_queue_t queue, dispatch_block_t block) -> () in dispatch_barrier_async(queue, block) }
            :{(dispatch_queue_t queue, dispatch_block_t block) -> () in dispatch_async(queue, block) }
        
        dispatchAsyncMethod(dispatch_queue_t: queue, dispatch_block_t: { () -> () in
            
            if self.finishedOrCanceled {
                return
            }
            
            let progressCallback = { (info: AnyObject) -> () in
                //TODO to garante that finish will called after progress
                dispatch_async(currentQueue, { () -> () in
                    
                    if self.finishedOrCanceled {
                        return
                    }
                    progressBlock?(progressInfo: info)
                    return
                })
            }
            
            let result = jobWithProgress(progressCallback: progressCallback)
            
            dispatch_async(currentQueue, {
                
                if self.finishedOrCanceled {
                    return
                }
                
                self.finishedOrCanceled = true
                
                didLoadDataBlock?(result: result)
            })
        })
    }
}

private class JAsyncAdapter<Value, Error: ErrorType> : JAsyncInterface {
    
    let jobWithProgress: JAsyncTypes<Value, Error>.JSyncOperationWithProgress
    let queueName      : String?
    let barrier        : Bool
    let currentQueue   : dispatch_queue_t
    let queueAttributes: dispatch_queue_attr_t
    
    init(jobWithProgress: JAsyncTypes<Value, Error>.JSyncOperationWithProgress,
         queueName      : String?,
         barrier        : Bool,
         currentQueue   : dispatch_queue_t,
         queueAttributes: dispatch_queue_attr_t) {
        
        self.jobWithProgress = jobWithProgress
        self.queueName       = queueName
        self.barrier         = barrier
        self.currentQueue    = currentQueue
        self.queueAttributes = queueAttributes
    }
    
    var operation: JBlockOperation<Value, Error>? = nil
    
    func asyncWithResultCallback(
        finishCallback  : JAsyncTypes<Value, Error>.JDidFinishAsyncCallback,
        stateCallback   : JAsyncChangeStateCallback,
        progressCallback: JAsyncProgressCallback) {
            
        operation = JBlockOperation(
            queueName         : queueName,
            jobWithProgress   : jobWithProgress,
            didLoadDataBlock  : finishCallback,
            progressBlock     : progressCallback,
            barrier           : barrier,
            currentQueue      : currentQueue,
            serialOrConcurrent: queueAttributes)
    }
    
    func doTask(task: JAsyncHandlerTask) {
        
        assert(task.unsubscribedOrCanceled)
        if task == .Cancel {
            operation?.cancel()
            operation = nil
        }
    }
    
    var isForeignThreadResultCallback: Bool {
        return false
    }
}

private func async<Value, Error: ErrorType>(
    jobWithProgress jobWithProgress: JAsyncTypes<Value, Error>.JSyncOperationWithProgress,
    queueName      : String,
    barrier        : Bool,
    currentQueue   : dispatch_queue_t,
    queueAttributes: dispatch_queue_attr_t) -> JAsyncTypes<Value, Error>.JAsync {
    
    let factory = { () -> JAsyncAdapter<Value, Error> in
        
        let asyncObject = JAsyncAdapter(
            jobWithProgress: jobWithProgress,
            queueName      : queueName,
            barrier        : barrier,
            currentQueue   : currentQueue,
            queueAttributes: queueAttributes)
        
        return asyncObject
    }
    return JAsyncBuilder.buildWithAdapterFactoryWithDispatchQueue(factory, callbacksQueue: currentQueue)
}

private func async<Value, Error: ErrorType>(
    job job     : JAsyncTypes<Value, Error>.JSyncOperation,
    queueName   : String,
    barrier     : Bool,
    currentQueue: dispatch_queue_t,
    attributes  : dispatch_queue_attr_t) -> JAsyncTypes<Value, Error>.JAsync
{
    let jobWithProgress = { (progressCallback: JAsyncProgressCallback?) -> AsyncResult<Value, Error> in
        return job()
    }
    
    return async(
        jobWithProgress: jobWithProgress,
        queueName      : queueName,
        barrier        : barrier,
        currentQueue   : currentQueue,
        queueAttributes: attributes)
}

public func async<Value, Error: ErrorType>(job job: JAsyncTypes<Value, Error>.JSyncOperation) -> JAsyncTypes<Value, Error>.JAsync {
    
    return async(job: job, queueName: defaultQueueName)
}

public func async<Value, Error: ErrorType>(job job: JAsyncTypes<Value, Error>.JSyncOperation, queueName: String) -> JAsyncTypes<Value, Error>.JAsync {
    
    assert(NSThread.isMainThread())
    return async(
        job         : job,
        queueName   : queueName,
        barrier     : false,
        currentQueue: dispatch_get_main_queue(),
        attributes  : DISPATCH_QUEUE_CONCURRENT)
}

func async<Value, Error: ErrorType>(jobWithProgress: JAsyncTypes<Value, Error>.JSyncOperation, queueName: String, isSerialQueue: Bool) -> JAsyncTypes<Value, Error>.JAsync {
    
    assert(NSThread.isMainThread())
    let attr: dispatch_queue_attr_t = isSerialQueue
        ?DISPATCH_QUEUE_SERIAL
        :DISPATCH_QUEUE_CONCURRENT
    
    return async(
        job         : jobWithProgress,
        queueName   : queueName,
        barrier     : false,
        currentQueue: dispatch_get_main_queue(),
        attributes  : attr)
}

func barrierAsync<Value, Error: ErrorType>(jobWithProgress: JAsyncTypes<Value, Error>.JSyncOperation, queueName: String) -> JAsyncTypes<Value, Error>.JAsync {
    
    assert(NSThread.isMainThread())
    return async(
        job         : jobWithProgress,
        queueName   : queueName,
        barrier     : true,
        currentQueue: dispatch_get_main_queue(),
        attributes  : DISPATCH_QUEUE_CONCURRENT)
}

public func async<Value, Error: ErrorType>(jobWithProgress: JAsyncTypes<Value, Error>.JSyncOperationWithProgress) -> JAsyncTypes<Value, Error>.JAsync {
    
    assert(NSThread.isMainThread())
    return async(
        jobWithProgress: jobWithProgress,
        queueName      : defaultQueueName,
        barrier        : false,
        currentQueue   : dispatch_get_main_queue(),
        queueAttributes: DISPATCH_QUEUE_CONCURRENT)
}
