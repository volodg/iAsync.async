//
//  CachedAsync.swift
//  iAsync_async
//
//  Created by Vladimir Gorbenko on 12.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

public enum CachedAsyncTypes<Value, Error: ErrorType> {

    public typealias JResultSetter = (value: AsyncResult<Value, Error>) -> ()
    public typealias JResultGetter = () -> AsyncResult<Value, Error>?
}

//TODO20 test immediately cancel
//TODO20 test cancel calback for each observer

final public class CachedAsync<Key: Hashable, Value, Error: ErrorType> {

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

    private func cancelBlock(propertyExtractor: PropertyExtractorType, callbacks: CallbacksBlocksHolder<Value, Error>) -> AsyncHandler {

        return { (task: AsyncHandlerTask) -> () in

            if propertyExtractor.cleared {
                return
            }

            let handlerOption = propertyExtractor.getLoaderHandler()

            guard let handler = handlerOption else { return }

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
                        let state: AsyncState = task == .Resume
                            ?.Resumed
                            :.Suspended
                        onState(state: state)
                    }
                })
            }
        }
    }

    private func doneCallbackBlock(propertyExtractor: PropertyExtractorType) -> AsyncTypes<Value, Error>.DidFinishAsyncCallback {

        return { (result: AsyncResult<Value, Error>) -> () in

            //TODO test this if
            //may happen when cancel
            if propertyExtractor.cacheObject == nil {
                return
            }

            let setter = propertyExtractor.setterOption

            let copyDelegates = propertyExtractor.copyDelegates()
            self.clearDataForPropertyExtractor(propertyExtractor)

            setter?(value: result)

            for callbacks in copyDelegates {
                callbacks.finishCallback?(result: result)
                callbacks.clearCallbacks()
            }
        }
    }

    private func performNativeLoader(
        propertyExtractor: PropertyExtractorType,
        callbacks: CallbacksBlocksHolder<Value, Error>) -> AsyncHandler {

        func progressCallback(progressInfo: AnyObject) {

            propertyExtractor.eachDelegate { delegate -> Void in
                delegate.progressCallback?(progressInfo: progressInfo)
            }
        }

        let doneCallback = doneCallbackBlock(propertyExtractor)

        func stateCallback(state: AsyncState) {

            propertyExtractor.eachDelegate { delegate -> Void in
                delegate.stateCallback?(state: state)
            }
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
            finishCallback  : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> AsyncHandler in

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

final private class ObjectRelatedPropertyData<Value, Error: ErrorType> {

    //var delegates    : mutable.ArrayBuffer[CallbacksBlocksHolder[T]] = null
    var delegates = [CallbacksBlocksHolder<Value, Error>]()

    var loaderHandler: AsyncHandler?
    //var asyncLoader  : Async[T] = null
    var asyncLoader  : AsyncTypes<Value, Error>.Async?

    func copyDelegates() -> [CallbacksBlocksHolder<Value, Error>] {

        let result = delegates.map { callbacks -> CallbacksBlocksHolder<Value, Error> in

            return CallbacksBlocksHolder(
                progressCallback: callbacks.progressCallback,
                stateCallback   : callbacks.stateCallback   ,
                finishCallback  : callbacks.finishCallback)
        }
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
        for (index, callbacks) in delegates.enumerate() {
            if delegate === callbacks {
                delegates.removeAtIndex(index)
                break
            }
        }
    }
}

final private class CallbacksBlocksHolder<Value, Error: ErrorType> {

    var progressCallback: AsyncProgressCallback?
    var stateCallback   : AsyncChangeStateCallback?
    var finishCallback  : AsyncTypes<Value, Error>.DidFinishAsyncCallback?

    init(
        progressCallback: AsyncProgressCallback?,
        stateCallback   : AsyncChangeStateCallback?,
        finishCallback  : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) {

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

final private class PropertyExtractor<KeyT: Hashable, ValueT, ErrorT: ErrorType> {

    var cleared = false

    var setterOption: CachedAsyncTypes<ValueT, ErrorT>.JResultSetter?
    var getterOption: CachedAsyncTypes<ValueT, ErrorT>.JResultGetter?
    var cacheObject : CachedAsync<KeyT, ValueT, ErrorT>?
    var uniqueKey   : KeyT

    init(
        setter     : CachedAsyncTypes<ValueT, ErrorT>.JResultSetter?,
        getter     : CachedAsyncTypes<ValueT, ErrorT>.JResultGetter?,
        cacheObject: CachedAsync<KeyT, ValueT, ErrorT>,
        uniqueKey  : KeyT,
        loader     : AsyncTypes<ValueT, ErrorT>.Async) {

        self.setterOption = setter
        self.getterOption = getter
        self.cacheObject  = cacheObject
        self.uniqueKey    = uniqueKey

        //"clearDataForPropertyExtractor" called here if cancel called of this merged loader on dealloc of previous loader
        setAsyncLoader(loader)
        //so set loader again
        setAsyncLoader(loader)
    }

    //private def getObjectRelatedPropertyData: ObjectRelatedPropertyData[ValueT] = {
    func getObjectRelatedPropertyData() -> ObjectRelatedPropertyData<ValueT, ErrorT> {

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

    func getLoaderHandler() -> AsyncHandler? {
        return getObjectRelatedPropertyData().loaderHandler
    }

    func setLoaderHandler(handler: AsyncHandler?) {
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

        if cleared { return }

        cacheObject!.delegatesByKey.removeValueForKey(uniqueKey)

        setterOption = nil
        getterOption = nil
        cacheObject  = nil

        cleared = true
    }
}