//
//  JCachedAsync.swift
//  Async
//
//  Created by Vladimir Gorbenko on 12.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

public enum CachedAsyncTypes<Value, Error: ErrorType>
{
    public typealias JResultSetter = (value: AsyncResult<Value, Error>) -> ()
    public typealias JResultGetter = () -> AsyncResult<Value, Error>?
}

//TODO20 test immediately cancel
//TODO20 test cancel calback for each observer

public class JCachedAsync<Key: Hashable, Value, Error: ErrorType> {
    
    public init() {}
    
    private var delegatesByKey = [Key:ObjectRelatedPropertyData<Value, Error>]()
    
    //type PropertyExtractorType = PropertyExtractor[Key, Value]
    private typealias PropertyExtractorType = PropertyExtractor<Key, Value, Error>
    
    //func clearDelegates(delegates: mutable.ArrayBuffer[CallbacksBlocksHolder[Value]]) {
    private func clearDelegates(delegates: [CallbacksBlocksHolder<Value, Error>]) {
        
        for callbacks in delegates {
            callbacks.clearCallbacks()
        }
    }
    
    private func clearDataForPropertyExtractor(propertyExtractor: PropertyExtractorType) {
        
        if propertyExtractor.cacheObject == nil {
            return
        }
        propertyExtractor.clearDelegates()
        propertyExtractor.setLoaderHandler(nil)
        propertyExtractor.setAsyncLoader  (nil)
        propertyExtractor.clear()
    }
    
    private func cancelBlock(propertyExtractor: PropertyExtractorType, callbacks: CallbacksBlocksHolder<Value, Error>) -> JAsyncHandler {
        
        return { (task: JAsyncHandlerTask) -> () in
            
            if propertyExtractor.cleared {
                return
            }
            
            let handlerOption = propertyExtractor.getLoaderHandler()
            
            if let handler = handlerOption {
                
                switch task {
                case .UnSubscribe:
                    let didLoadDataBlock = callbacks.finishCallback
                    propertyExtractor.removeDelegate(callbacks)
                    callbacks.clearCallbacks()
                    
                    didLoadDataBlock?(result: .Unsubscribed)
                case .Cancel:
                    handler(task: .Cancel)
                    self.clearDataForPropertyExtractor(propertyExtractor)//TODO should be already cleared here in finish callback
                case .Suspend, .Resume:
                    
                    propertyExtractor.eachDelegate({(callback: CallbacksBlocksHolder<Value, Error>) -> () in
                        
                        if let onState = callback.stateCallback {
                            let state = task == .Resume
                                ?JAsyncState.Resumed
                                :JAsyncState.Suspended
                            onState(state: state)
                        }
                    })
                default:
                    fatalError("unsupported type")
                }
            }
        }
    }
    
    private func doneCallbackBlock(propertyExtractor: PropertyExtractorType) -> AsyncTypes<Value, Error>.JDidFinishAsyncCallback {
        
        return { (result: AsyncResult<Value, Error>) -> () in
            
            //TODO test this if
            //may happen when cancel
            if propertyExtractor.cacheObject == nil {
                return
            }
            
            propertyExtractor.setterOption?(value: result)
            
            let copyDelegates = propertyExtractor.copyDelegates()
            
            self.clearDataForPropertyExtractor(propertyExtractor)
            
            for callbacks in copyDelegates {
                callbacks.finishCallback?(result: result)
                callbacks.clearCallbacks()
            }
        }
    }
    
    private func performNativeLoader(
        propertyExtractor: PropertyExtractorType,
        callbacks: CallbacksBlocksHolder<Value, Error>) -> JAsyncHandler
    {
        func progressCallback(progressInfo: AnyObject) {
            
            propertyExtractor.eachDelegate({(delegate: CallbacksBlocksHolder<Value, Error>) -> () in
                delegate.progressCallback?(progressInfo: progressInfo)
                return
            })
        }
        
        let doneCallback = doneCallbackBlock(propertyExtractor)
        
        func stateCallback(state: JAsyncState) {
            
            propertyExtractor.eachDelegate({(delegate: CallbacksBlocksHolder<Value, Error>) -> () in
                delegate.stateCallback?(state: state)
                return
            })
        }
        
        let loader  = propertyExtractor.getAsyncLoader()
        let handler = loader!(
            progressCallback: progressCallback,
            stateCallback   : stateCallback,
            finishCallback  : doneCallback)
        
        if propertyExtractor.cacheObject == nil {
            return jStubHandlerAsyncBlock
        }
        
        propertyExtractor.setLoaderHandler(handler)
        
        return cancelBlock(propertyExtractor, callbacks: callbacks)
    }
    
    public func isLoadingDataForUniqueKey(uniqueKey: Key) -> Bool {
        
        let resultOption = delegatesByKey[uniqueKey]
        return resultOption != nil
    }
    
    public var hasLoadingData: Bool {
        
        return delegatesByKey.count != 0
    }
    
    public func asyncOpMerger(loader: AsyncTypes<Value, Error>.Async, uniqueKey: Key) -> AsyncTypes<Value, Error>.Async {
        
        return asyncOpWithPropertySetter(nil, getter: nil, uniqueKey: uniqueKey, loader: loader)
    }
    
    public func asyncOpWithPropertySetter(
        setter: CachedAsyncTypes<Value, Error>.JResultSetter?,
        getter: CachedAsyncTypes<Value, Error>.JResultGetter?,
        uniqueKey: Key,
        loader: AsyncTypes<Value, Error>.Async) -> AsyncTypes<Value, Error>.Async
    {
        return { (
            progressCallback: AsyncProgressCallback?,
            stateCallback   : AsyncChangeStateCallback?,
            finishCallback  : AsyncTypes<Value, Error>.JDidFinishAsyncCallback?) -> JAsyncHandler in
            
            let propertyExtractor = PropertyExtractorType(
                setter     : setter,
                getter     : getter,
                cacheObject: self,
                uniqueKey  : uniqueKey,
                loader     : loader)
            
            if let result = propertyExtractor.getAsyncResult() {
                
                finishCallback?(result: result)
                
                propertyExtractor.clear()
                return jStubHandlerAsyncBlock
            }
            
            let callbacks = CallbacksBlocksHolder(progressCallback: progressCallback, stateCallback: stateCallback, finishCallback: finishCallback)
            
            let hasDelegates = propertyExtractor.hasDelegates()
            
            propertyExtractor.addDelegate(callbacks)
            
            return hasDelegates
                ?self.cancelBlock(propertyExtractor, callbacks: callbacks)
                :self.performNativeLoader(propertyExtractor, callbacks: callbacks)
        }
    }
}

private class ObjectRelatedPropertyData<Value, Error: ErrorType>
{
    //var delegates    : mutable.ArrayBuffer[CallbacksBlocksHolder[T]] = null
    var delegates = [CallbacksBlocksHolder<Value, Error>]()
    
    var loaderHandler: JAsyncHandler?
    //var asyncLoader  : Async[T] = null
    var asyncLoader  : AsyncTypes<Value, Error>.Async?
    
    func copyDelegates() -> [CallbacksBlocksHolder<Value, Error>] {
        
        let result = delegates.map({ (callbacks: CallbacksBlocksHolder<Value, Error>) -> CallbacksBlocksHolder<Value, Error> in
            
            return CallbacksBlocksHolder(
                progressCallback: callbacks.progressCallback,
                stateCallback   : callbacks.stateCallback   ,
                finishCallback  : callbacks.finishCallback)
        })
        return result
    }
    
    func clearDelegates() {
        for callbacks in delegates {
            callbacks.clearCallbacks()
        }
        delegates.removeAll(keepCapacity: false)
    }
    
    func eachDelegate(block: (obj: CallbacksBlocksHolder<Value, Error>) -> ()) {
        for element in delegates {
            block(obj: element)
        }
    }
    
    func hasDelegates() -> Bool {
        return delegates.count > 0
    }
    
    //func getDelegates: mutable.ArrayBuffer[CallbacksBlocksHolder[ValueT]] = {
    func addDelegate(delegate: CallbacksBlocksHolder<Value, Error>) {
        delegates.append(delegate)
    }
    
    func removeDelegate(delegate: CallbacksBlocksHolder<Value, Error>) {
        for (index, callbacks) in enumerate(delegates) {
            if delegate === callbacks {
                delegates.removeAtIndex(index)
                break
            }
        }
    }
}

private class CallbacksBlocksHolder<Value, Error: ErrorType>
{
    var progressCallback: AsyncProgressCallback?
    var stateCallback   : AsyncChangeStateCallback?
    var finishCallback  : AsyncTypes<Value, Error>.JDidFinishAsyncCallback?
    
    init(
        progressCallback: AsyncProgressCallback?,
        stateCallback   : AsyncChangeStateCallback?,
        finishCallback  : AsyncTypes<Value, Error>.JDidFinishAsyncCallback?)
    {
        self.progressCallback = progressCallback
        self.stateCallback    = stateCallback
        self.finishCallback   = finishCallback
    }
    
    func clearCallbacks() {
        
        progressCallback = nil
        stateCallback    = nil
        finishCallback   = nil
    }
}

private class PropertyExtractor<KeyT: Hashable, ValueT, ErrorT: ErrorType> {
    
    var cleared = false
    
    var setterOption: CachedAsyncTypes<ValueT, ErrorT>.JResultSetter?
    var getterOption: CachedAsyncTypes<ValueT, ErrorT>.JResultGetter?
    var cacheObject : JCachedAsync<KeyT, ValueT, ErrorT>?
    var uniqueKey   : KeyT
    
    init(
        setter     : CachedAsyncTypes<ValueT, ErrorT>.JResultSetter?,
        getter     : CachedAsyncTypes<ValueT, ErrorT>.JResultGetter?,
        cacheObject: JCachedAsync<KeyT, ValueT, ErrorT>,
        uniqueKey  : KeyT,
        loader     : AsyncTypes<ValueT, ErrorT>.Async)
    {
        self.setterOption = setter
        self.getterOption = getter
        self.cacheObject  = cacheObject
        self.uniqueKey    = uniqueKey
        setAsyncLoader(loader)
    }
    
    //private def getObjectRelatedPropertyData: ObjectRelatedPropertyData[ValueT] = {
    func getObjectRelatedPropertyData() -> ObjectRelatedPropertyData<ValueT, ErrorT>
    {
        let resultOption = cacheObject!.delegatesByKey[uniqueKey]
        
        if let result = resultOption {
            return result
        }
        
        let result = ObjectRelatedPropertyData<ValueT, ErrorT>()
        cacheObject!.delegatesByKey[uniqueKey] = result
        return result
    }
    
    func copyDelegates() -> [CallbacksBlocksHolder<ValueT, ErrorT>] {
        return getObjectRelatedPropertyData().copyDelegates()
    }
    
    func eachDelegate(block: (obj: CallbacksBlocksHolder<ValueT, ErrorT>) -> ()) {
        return getObjectRelatedPropertyData().eachDelegate(block)
    }
    
    func hasDelegates() -> Bool {
        return getObjectRelatedPropertyData().hasDelegates()
    }
    
    func clearDelegates() {
        getObjectRelatedPropertyData().clearDelegates()
    }
    
    //func getDelegates: mutable.ArrayBuffer[CallbacksBlocksHolder[ValueT]] = {
    func addDelegate(delegate: CallbacksBlocksHolder<ValueT, ErrorT>) {
        getObjectRelatedPropertyData().addDelegate(delegate)
    }
    
    func removeDelegate(delegate: CallbacksBlocksHolder<ValueT, ErrorT>) {
        getObjectRelatedPropertyData().removeDelegate(delegate)
    }
    
    func getLoaderHandler() -> JAsyncHandler? {
        return getObjectRelatedPropertyData().loaderHandler
    }
    
    func setLoaderHandler(handler: JAsyncHandler?) {
        getObjectRelatedPropertyData().loaderHandler = handler
    }
    
    //def getAsyncLoader: Async[ValueT] =
    func getAsyncLoader() -> AsyncTypes<ValueT, ErrorT>.Async? {
        return getObjectRelatedPropertyData().asyncLoader
    }
    
    //def setAsyncLoader(loader: Async[ValueT])
    func setAsyncLoader(loader: AsyncTypes<ValueT, ErrorT>.Async?) {
        getObjectRelatedPropertyData().asyncLoader = loader
    }
    
    func getAsyncResult() -> AsyncResult<ValueT, ErrorT>? {
        return getterOption?()
    }
    
    func clear() {
        
        if cleared {
            return
        }
        
        cacheObject!.delegatesByKey.removeValueForKey(uniqueKey)
        
        setterOption = nil
        getterOption = nil
        cacheObject  = nil
        
        cleared = true
    }
}
