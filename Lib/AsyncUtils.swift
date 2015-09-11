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
private class BlockOperation<Value, Error: ErrorType> {
    
    //TODO make atomic
    private var finishedOrCanceled = false
    
    init(
        queueName         : String?,
        loadDataBlock     : AsyncTypes<Value, Error>.SyncOperationWithProgress,
        didLoadDataBlock  : AsyncTypes<Value, Error>.DidFinishAsyncCallback?,
        progressBlock     : AsyncProgressCallback?,
        barrier           : Bool,
        currentQueue      : dispatch_queue_t = dispatch_get_main_queue(),
        serialOrConcurrent: dispatch_queue_attr_t = DISPATCH_QUEUE_CONCURRENT) {
        
        //TODO use cStringUsingEncoding(NSUTF8StringEncoding) instead
        let queue: dispatch_queue_t = { () -> dispatch_queue_t in
            
            if let queueName = queueName {
                return dispatch_queue_get_or_create(queueName, serialOrConcurrent)
            }
            
            return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        }()
        
        performBackgroundOperationInQueue(
            queue,
            barrier         : barrier,
            currentQueue    : currentQueue,
            loadDataBlock   : loadDataBlock,
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
        loadDataBlock   : AsyncTypes<Value, Error>.SyncOperationWithProgress,
        didLoadDataBlock: AsyncTypes<Value, Error>.DidFinishAsyncCallback?,
        progressBlock   : AsyncProgressCallback?) {
        
        let dispatchAsyncMethod = barrier
            ?{(dispatch_queue_t queue, dispatch_block_t block) -> () in dispatch_barrier_async(queue, block) }
            :{(dispatch_queue_t queue, dispatch_block_t block) -> () in dispatch_async(queue, block) }
        
        dispatchAsyncMethod(queue, { () -> () in
            
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
            
            let result = loadDataBlock(progressCallback: progressCallback)
            
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

private class JAsyncAdapter<Value, Error: ErrorType> : AsyncInterface {
    
    let loadDataBlock  : AsyncTypes<Value, Error>.SyncOperationWithProgress
    let queueName      : String?
    let barrier        : Bool
    let currentQueue   : dispatch_queue_t
    let queueAttributes: dispatch_queue_attr_t
    
    init(loadDataBlock  : AsyncTypes<Value, Error>.SyncOperationWithProgress,
         queueName      : String?,
         barrier        : Bool,
         currentQueue   : dispatch_queue_t,
         queueAttributes: dispatch_queue_attr_t)
    {
        self.loadDataBlock   = loadDataBlock
        self.queueName       = queueName
        self.barrier         = barrier
        self.currentQueue    = currentQueue
        self.queueAttributes = queueAttributes
    }
    
    var operation: BlockOperation<Value, Error>? = nil
    
    func asyncWithResultCallback(
        finishCallback  : AsyncTypes<Value, Error>.DidFinishAsyncCallback,
        stateCallback   : AsyncChangeStateCallback,
        progressCallback: AsyncProgressCallback)
    {
        operation = BlockOperation(
            queueName         : queueName,
            loadDataBlock     : loadDataBlock,
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

private func asyncWithSyncOperationWithProgressBlockAndQueue<Value, Error: ErrorType>(
    progressLoadDataBlock: AsyncTypes<Value, Error>.SyncOperationWithProgress,
    queueName: String,
    barrier: Bool,
    currentQueue: dispatch_queue_t,
    queueAttributes: dispatch_queue_attr_t) -> AsyncTypes<Value, Error>.Async {
    
    let factory = { () -> JAsyncAdapter<Value, Error> in
        
        let asyncObject = JAsyncAdapter(
            loadDataBlock  : progressLoadDataBlock,
            queueName      : queueName,
            barrier        : barrier,
            currentQueue   : currentQueue,
            queueAttributes: queueAttributes)
        
        return asyncObject
    }
    return AsyncBuilder.buildWithAdapterFactoryWithDispatchQueue(factory, callbacksQueue: currentQueue)
}

private func generalAsyncWithSyncOperationAndQueue<Value, Error: ErrorType>(
    loadDataBlock: AsyncTypes<Value, Error>.SyncOperation,
    queueName: String,
    barrier: Bool,
    currentQueue: dispatch_queue_t,
    attr: dispatch_queue_attr_t) -> AsyncTypes<Value, Error>.Async
{
    let progressLoadDataBlock = { (progressCallback: AsyncProgressCallback?) -> AsyncResult<Value, Error> in
        
        return loadDataBlock()
    }
    
    return asyncWithSyncOperationWithProgressBlockAndQueue(
        progressLoadDataBlock,
        queueName,
        barrier,
        currentQueue,
        attr)
}

public func asyncWithSyncOperation<Value, Error>(loadDataBlock: AsyncTypes<Value, Error>.SyncOperation) -> AsyncTypes<Value, Error>.Async {
    
    return asyncWithSyncOperationAndQueue(loadDataBlock, defaultQueueName)
}

public func asyncWithSyncOperationAndQueue<Value, Error: ErrorType>(loadDataBlock: AsyncTypes<Value, Error>.SyncOperation, queueName: String) -> AsyncTypes<Value, Error>.Async {
    
    assert(NSThread.isMainThread())
    return generalAsyncWithSyncOperationAndQueue(
        loadDataBlock,
        queueName,
        false,
        dispatch_get_main_queue(),
        DISPATCH_QUEUE_CONCURRENT)
}

func asyncWithSyncOperationAndConfigurableQueue<Value, Error: ErrorType>(loadDataBlock: AsyncTypes<Value, Error>.SyncOperation, queueName: String, isSerialQueue: Bool) -> AsyncTypes<Value, Error>.Async {
    
    assert(NSThread.isMainThread())
    let attr: dispatch_queue_attr_t = isSerialQueue
        ?DISPATCH_QUEUE_SERIAL
        :DISPATCH_QUEUE_CONCURRENT
    
    return generalAsyncWithSyncOperationAndQueue(
        loadDataBlock,
        queueName,
        false,
        dispatch_get_main_queue(),
        attr)
}

func barrierAsyncWithSyncOperationAndQueue<Value, Error: ErrorType>(loadDataBlock: AsyncTypes<Value, Error>.SyncOperation, queueName: String) -> AsyncTypes<Value, Error>.Async {
    
    assert(NSThread.isMainThread())
    return generalAsyncWithSyncOperationAndQueue(
        loadDataBlock,
        queueName,
        true,
        dispatch_get_main_queue(),
        DISPATCH_QUEUE_CONCURRENT)
}

public func asyncWithSyncOperationWithProgressBlock<Value, Error: ErrorType>(progressLoadDataBlock: AsyncTypes<Value, Error>.SyncOperationWithProgress) -> AsyncTypes<Value, Error>.Async {
    
    assert(NSThread.isMainThread())
    return asyncWithSyncOperationWithProgressBlockAndQueue(
        progressLoadDataBlock,
        defaultQueueName,
        false,
        dispatch_get_main_queue(),
        DISPATCH_QUEUE_CONCURRENT)
}
