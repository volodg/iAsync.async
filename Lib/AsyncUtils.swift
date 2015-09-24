//
//  AsyncUtils.swift
//  iAsync
//
//  Created by Vladimir Gorbenko on 27.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

private let defaultQueueName = "com.jff.async_operations_library.general_queue"

//TODO remove this class
final private class BlockOperation<Value, Error: ErrorType> {
    
    private var queue = dispatch_queue_create("BlockOperation.finishedOrCanceled", DISPATCH_QUEUE_SERIAL)
    private var finishedOrCanceled: Bool = false
    
    init(
        queueName         : String?,
        jobWithProgress   : AsyncTypes<Value, Error>.SyncOperationWithProgress,
        didLoadDataBlock  : AsyncTypes<Value, Error>.DidFinishAsyncCallback?,
        progressBlock     : AsyncProgressCallback?,
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
        
        dispatch_sync(queue) { self.finishedOrCanceled = true }
    }
    
    private func performBackgroundOperationInQueue(
        queue           : dispatch_queue_t,
        barrier         : Bool,
        currentQueue    : dispatch_queue_t,
        jobWithProgress : AsyncTypes<Value, Error>.SyncOperationWithProgress,
        didLoadDataBlock: AsyncTypes<Value, Error>.DidFinishAsyncCallback?,
        progressBlock   : AsyncProgressCallback?) {
        
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
                
                dispatch_sync(queue) { self.finishedOrCanceled = true }
                
                didLoadDataBlock?(result: result)
            })
        })
    }
}

final private class JAsyncAdapter<Value, Error: ErrorType> : AsyncInterface {
    
    let jobWithProgress: AsyncTypes<Value, Error>.SyncOperationWithProgress
    let queueName      : String?
    let barrier        : Bool
    let currentQueue   : dispatch_queue_t
    let queueAttributes: dispatch_queue_attr_t
    
    init(jobWithProgress: AsyncTypes<Value, Error>.SyncOperationWithProgress,
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
    
    var operation: BlockOperation<Value, Error>? = nil
    
    func asyncWithResultCallback(
        finishCallback  : AsyncTypes<Value, Error>.DidFinishAsyncCallback,
        stateCallback   : AsyncChangeStateCallback,
        progressCallback: AsyncProgressCallback) {
        
        operation = BlockOperation(
            queueName         : queueName,
            jobWithProgress   : jobWithProgress,
            didLoadDataBlock  : finishCallback,
            progressBlock     : progressCallback,
            barrier           : barrier,
            currentQueue      : currentQueue,
            serialOrConcurrent: queueAttributes)
    }
    
    func doTask(task: AsyncHandlerTask) {
        
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
    jobWithProgress jobWithProgress: AsyncTypes<Value, Error>.SyncOperationWithProgress,
    queueName      : String,
    barrier        : Bool,
    currentQueue   : dispatch_queue_t,
    queueAttributes: dispatch_queue_attr_t) -> AsyncTypes<Value, Error>.Async {
    
    let factory = { () -> JAsyncAdapter<Value, Error> in
        
        let asyncObject = JAsyncAdapter(
            jobWithProgress: jobWithProgress,
            queueName      : queueName,
            barrier        : barrier,
            currentQueue   : currentQueue,
            queueAttributes: queueAttributes)
        
        return asyncObject
    }
    return AsyncBuilder.buildWithAdapterFactoryWithDispatchQueue(factory, callbacksQueue: currentQueue)
}

private func async<Value, Error: ErrorType>(
    job job     : AsyncTypes<Value, Error>.SyncOperation,
    queueName   : String,
    barrier     : Bool,
    currentQueue: dispatch_queue_t,
    attributes  : dispatch_queue_attr_t) -> AsyncTypes<Value, Error>.Async
{
    let jobWithProgress = { (progressCallback: AsyncProgressCallback?) -> AsyncResult<Value, Error> in
        return job()
    }
    
    return async(
        jobWithProgress: jobWithProgress,
        queueName      : queueName,
        barrier        : barrier,
        currentQueue   : currentQueue,
        queueAttributes: attributes)
}

public func async<Value, Error: ErrorType>(job job: AsyncTypes<Value, Error>.SyncOperation) -> AsyncTypes<Value, Error>.Async {
    
    return async(job: job, queueName: defaultQueueName)
}

public func async<Value, Error: ErrorType>(job job: AsyncTypes<Value, Error>.SyncOperation, queueName: String) -> AsyncTypes<Value, Error>.Async {
    
    assert(NSThread.isMainThread())
    return async(
        job         : job,
        queueName   : queueName,
        barrier     : false,
        currentQueue: dispatch_get_main_queue(),
        attributes  : DISPATCH_QUEUE_CONCURRENT)
}

func async<Value, Error: ErrorType>(jobWithProgress: AsyncTypes<Value, Error>.SyncOperation, queueName: String, isSerialQueue: Bool) -> AsyncTypes<Value, Error>.Async {
    
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

func barrierAsync<Value, Error: ErrorType>(jobWithProgress: AsyncTypes<Value, Error>.SyncOperation, queueName: String) -> AsyncTypes<Value, Error>.Async {
    
    assert(NSThread.isMainThread())
    return async(
        job         : jobWithProgress,
        queueName   : queueName,
        barrier     : true,
        currentQueue: dispatch_get_main_queue(),
        attributes  : DISPATCH_QUEUE_CONCURRENT)
}

public func async<Value, Error: ErrorType>(jobWithProgress: AsyncTypes<Value, Error>.SyncOperationWithProgress) -> AsyncTypes<Value, Error>.Async {
    
    assert(NSThread.isMainThread())
    return async(
        jobWithProgress: jobWithProgress,
        queueName      : defaultQueueName,
        barrier        : false,
        currentQueue   : dispatch_get_main_queue(),
        queueAttributes: DISPATCH_QUEUE_CONCURRENT)
}
