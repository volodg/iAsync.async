//
//  JAsyncUtils.swift
//  JAsync
//
//  Created by Vladimir Gorbenko on 27.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

import Result

private let defaultQueueName = "com.jff.async_operations_library.general_queue"

//TODO remove this class
private class JBlockOperation<T> {
    
    //TODO make atomic
    private var finishedOrCanceled = false
    
    init(
        queueName         : String?,
        jobWithProgress   : JAsyncTypes<T>.JSyncOperationWithProgress,
        didLoadDataBlock  : JAsyncTypes<T>.JDidFinishAsyncCallback?,
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
        jobWithProgress : JAsyncTypes<T>.JSyncOperationWithProgress,
        didLoadDataBlock: JAsyncTypes<T>.JDidFinishAsyncCallback?,
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

private class JAsyncAdapter<T> : JAsyncInterface {
    
    let jobWithProgress: JAsyncTypes<T>.JSyncOperationWithProgress
    let queueName      : String?
    let barrier        : Bool
    let currentQueue   : dispatch_queue_t
    let queueAttributes: dispatch_queue_attr_t
    
    init(jobWithProgress: JAsyncTypes<T>.JSyncOperationWithProgress,
         queueName      : String?,
         barrier        : Bool,
         currentQueue   : dispatch_queue_t,
         queueAttributes: dispatch_queue_attr_t)
    {
        self.jobWithProgress = jobWithProgress
        self.queueName       = queueName
        self.barrier         = barrier
        self.currentQueue    = currentQueue
        self.queueAttributes = queueAttributes
    }
    
    var operation: JBlockOperation<T>? = nil
    
    func asyncWithResultCallback(
        finishCallback  : JAsyncTypes<T>.JDidFinishAsyncCallback,
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
        
        assert(task.rawValue <= JAsyncHandlerTask.Cancel.rawValue)
        if task == .Cancel {
            operation?.cancel()
            operation = nil
        }
    }
    
    var isForeignThreadResultCallback: Bool {
        return false
    }
}

private func async<T>(
    jobWithProgress jobWithProgress: JAsyncTypes<T>.JSyncOperationWithProgress,
    queueName      : String,
    barrier        : Bool,
    currentQueue   : dispatch_queue_t,
    queueAttributes: dispatch_queue_attr_t) -> JAsyncTypes<T>.JAsync {
    
    let factory = { () -> JAsyncAdapter<T> in
        
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

private func async<T>(
    job job     : JAsyncTypes<T>.JSyncOperation,
    queueName   : String,
    barrier     : Bool,
    currentQueue: dispatch_queue_t,
    attributes  : dispatch_queue_attr_t) -> JAsyncTypes<T>.JAsync
{
    let jobWithProgress = { (progressCallback: JAsyncProgressCallback?) -> Result<T, NSError> in
        return job()
    }
    
    return async(
        jobWithProgress: jobWithProgress,
        queueName      : queueName,
        barrier        : barrier,
        currentQueue   : currentQueue,
        queueAttributes: attributes)
}

public func async<T>(job job: JAsyncTypes<T>.JSyncOperation) -> JAsyncTypes<T>.JAsync {
    
    return async(job: job, queueName: defaultQueueName)
}

public func async<T>(job job: JAsyncTypes<T>.JSyncOperation, queueName: String) -> JAsyncTypes<T>.JAsync {
    
    assert(NSThread.isMainThread())
    return async(
        job         : job,
        queueName   : queueName,
        barrier     : false,
        currentQueue: dispatch_get_main_queue(),
        attributes  : DISPATCH_QUEUE_CONCURRENT)
}

func async<T>(jobWithProgress: JAsyncTypes<T>.JSyncOperation, queueName: String, isSerialQueue: Bool) -> JAsyncTypes<T>.JAsync {
    
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

func barrierAsync<T>(jobWithProgress: JAsyncTypes<T>.JSyncOperation, queueName: String) -> JAsyncTypes<T>.JAsync {
    
    assert(NSThread.isMainThread())
    return async(
        job         : jobWithProgress,
        queueName   : queueName,
        barrier     : true,
        currentQueue: dispatch_get_main_queue(),
        attributes  : DISPATCH_QUEUE_CONCURRENT)
}

public func async<T>(jobWithProgress: JAsyncTypes<T>.JSyncOperationWithProgress) -> JAsyncTypes<T>.JAsync {
    
    assert(NSThread.isMainThread())
    return async(
        jobWithProgress: jobWithProgress,
        queueName      : defaultQueueName,
        barrier        : false,
        currentQueue   : dispatch_get_main_queue(),
        queueAttributes: DISPATCH_QUEUE_CONCURRENT)
}
