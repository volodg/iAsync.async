//
//  ArrayLoadersMerger.swift
//  iAsync
//
//  Created by Vladimir Gorbenko on 11.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

public class JArrayLoadersMerger<Arg: Hashable, Value, Error: ErrorType> {
    
    public typealias JAsyncOpAr = AsyncTypes<[Value], Error>.Async
    
    public typealias JArrayOfObjectsLoader = (keys: [Arg]) -> JAsyncOpAr
    
    private var _pendingLoadersCallbacksByKey = [Arg:JLoadersCallbacksData<Value, Error>]()
    private let _cachedAsyncOp = JCachedAsync<Arg, Value, Error>()
    
    private let _arrayLoader: JArrayOfObjectsLoader
    
    private var activeArrayLoaders = [ActiveArrayLoader<Arg, Value, Error>]()
    
    private func removeActiveLoader(loader: ActiveArrayLoader<Arg, Value, Error>) {
        
        for (index, element) in activeArrayLoaders.enumerate() {
            
            if element === loader {
                self.activeArrayLoaders.removeAtIndex(index)
            }
        }
    }
    
    public init(arrayLoader: JArrayOfObjectsLoader) {
        _arrayLoader = arrayLoader
    }
    
    public func oneObjectLoader(key: Arg) -> AsyncTypes<Value, Error>.Async {
        
        let loader = { (progressCallback: AsyncProgressCallback?,
                        stateCallback   : AsyncChangeStateCallback?,
                        finishCallback  : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> JAsyncHandler in
            
            if let currentLoader = self.activeLoaderForKey(key) {
                
                let resultIndex = currentLoader.indexOfKey(key)
                
                let loader = bindSequenceOfAsyncs(currentLoader.nativeLoader!, { (result: [Value]) -> AsyncTypes<Value, Error>.Async in
                    //TODO check length of result
                    return async(value: result[resultIndex])
                })
                
                return loader(
                    progressCallback: progressCallback,
                    stateCallback   : stateCallback,
                    finishCallback  : finishCallback)
            }
            
            let callbacks = JLoadersCallbacksData(
                progressCallback: progressCallback,
                stateCallback   : stateCallback,
                doneCallback    : finishCallback)
            
            self._pendingLoadersCallbacksByKey[key] = callbacks
            
            dispatch_async(dispatch_get_main_queue(), { [weak self] () -> () in
                self?.runLoadingOfPendingKeys()
            })
            
            return { (task: JAsyncHandlerTask) -> () in
                
                switch task {
                case .UnSubscribe:
                    let indexOption = self._pendingLoadersCallbacksByKey.indexForKey(key)
                    if let index = indexOption {
                        let (_, callbacks) = self._pendingLoadersCallbacksByKey[index]
                        self._pendingLoadersCallbacksByKey.removeAtIndex(index)
                        if let finishCallback = callbacks.doneCallback {
                            callbacks.doneCallback = nil
                            finishCallback(result: .Unsubscribed)
                        }
                        callbacks.unsubscribe()
                    } else {
                        self.activeLoaderForKey(key)?.unsubscribe(key)
                    }
                case .Cancel:
                    let indexOption = self._pendingLoadersCallbacksByKey.indexForKey(key)
                    if let index = indexOption {
                        let (_, callbacks) = self._pendingLoadersCallbacksByKey[index]
                        self._pendingLoadersCallbacksByKey.removeAtIndex(index)
                        if let finishCallback = callbacks.doneCallback {
                            callbacks.doneCallback = nil
                            finishCallback(result: .Interrupted)
                        }
                        callbacks.unsubscribe()
                    } else {
                        self.activeLoaderForKey(key)?.cancelLoader()
                    }
                case .Resume:
                    assert(false, "unsupported parameter: JFFAsyncHandlerTaskResume")
                case .Suspend:
                    assert(false, "unsupported parameter: JFFAsyncHandlerTaskSuspend")
                default:
                    assert(false, "invalid parameter")
                }
            }
        }
        
        return self._cachedAsyncOp.asyncOpWithPropertySetter(nil, getter: nil, uniqueKey: key, loader: loader)
    }
    
    private func runLoadingOfPendingKeys() {
        
        if _pendingLoadersCallbacksByKey.count == 0 {
            return
        }
        
        let loader = ActiveArrayLoader(loadersCallbacksByKey:_pendingLoadersCallbacksByKey, owner: self)
        
        activeArrayLoaders.append(loader)
        
        _pendingLoadersCallbacksByKey.removeAll(keepCapacity: true)
        
        loader.runLoader()
    }
    
    private func activeLoaderForKey(key: Arg) -> ActiveArrayLoader<Arg, Value, Error>? {
        
        let index = activeArrayLoaders.indexOf( { (activeLoader: ActiveArrayLoader<Arg, Value, Error>) -> Bool in
            return activeLoader.loadersCallbacksByKey[key] != nil
        })
        if let index = index {
            return activeArrayLoaders[index]
        }
        return nil
    }
}

private class JLoadersCallbacksData<Value, Error: ErrorType> {
    
    var progressCallback: AsyncProgressCallback?
    var stateCallback   : AsyncChangeStateCallback?
    var doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?
    
    var suspended = false
    
    init(
        progressCallback: AsyncProgressCallback?,
        stateCallback   : AsyncChangeStateCallback?,
        doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?)
    {
        self.progressCallback = progressCallback
        self.stateCallback    = stateCallback
        self.doneCallback     = doneCallback
    }
    
    func unsubscribe() {
        progressCallback = nil
        stateCallback    = nil
        doneCallback     = nil
    }
    
    func copy() -> JLoadersCallbacksData {
        return JLoadersCallbacksData(
            progressCallback: self.progressCallback,
            stateCallback   : self.stateCallback   ,
            doneCallback    : self.doneCallback    )
    }
}

private class ActiveArrayLoader<Arg: Hashable, Value, Error: ErrorType> {
    
    var loadersCallbacksByKey: [Arg:JLoadersCallbacksData<Value, Error>]
    weak var owner: JArrayLoadersMerger<Arg, Value, Error>?
    var keys = KeysType()
    
    private func indexOfKey(key: Arg) -> Int {
        
        for (index, currentKey) in keys.enumerate() {
            if currentKey == key {
                return index
            }
        }
        return -1
    }
    
    var nativeLoader : AsyncTypes<[Value], Error>.Async? //Should be strong
    
    private var _nativeHandler: JAsyncHandler?
    
    init(loadersCallbacksByKey: [Arg:JLoadersCallbacksData<Value, Error>], owner: JArrayLoadersMerger<Arg, Value, Error>) {
        self.loadersCallbacksByKey = loadersCallbacksByKey
        self.owner                 = owner
    }
    
    func cancelLoader() {
        
        if let block = _nativeHandler {
            
            _nativeHandler = nil
            block(task: .Cancel)
            self.clearState()
        }
    }
    
    func clearState() {
        for (_, value) in loadersCallbacksByKey {
            value.unsubscribe()
        }
        loadersCallbacksByKey.removeAll(keepCapacity: false)
        owner?.removeActiveLoader(self)
        _nativeHandler = nil
        nativeLoader   = nil
    }
    
    func unsubscribe(key: Arg) {
        let indexOption = loadersCallbacksByKey.indexForKey(key)
        if let index = indexOption {
            
            let callbacks = loadersCallbacksByKey[index]
            callbacks.1.unsubscribe()
            loadersCallbacksByKey.removeAtIndex(index)
        }
    }
    
    typealias KeysType = HashableArray<Arg>
    let _cachedAsyncOp = JCachedAsync<KeysType,[Value], Error>()
    
    func runLoader() {
        
        assert(self.nativeLoader == nil)
        
        keys.removeAll()
        for (key, _) in loadersCallbacksByKey {
            keys.append(key)
        }
        
        let arrayLoader = owner!._arrayLoader(keys: Array(keys))
        
        let loader = { [weak self] (
            progressCallback: AsyncProgressCallback?,
            stateCallback   : AsyncChangeStateCallback?,
            finishCallback  : AsyncTypes<[Value], Error>.DidFinishAsyncCallback?) -> JAsyncHandler in
            
            let progressCallbackWrapper = { (progressInfo: AnyObject) -> () in
                
                if let self_ = self {
                    
                    for (_, value) in self_.loadersCallbacksByKey {
                        value.progressCallback?(progressInfo: progressInfo)
                    }
                }
                
                progressCallback?(progressInfo: progressInfo)
            }
            
            let stateCallbackWrapper = { (state: JAsyncState) -> () in
                
                if let self_ = self {
                    
                    for (_, value) in self_.loadersCallbacksByKey {
                        value.stateCallback?(state: state)
                    }
                }
                
                stateCallback?(state: state)
            }
            
            let doneCallbackWrapper = { (results: AsyncResult<[Value], Error>) -> () in
                
                if let self_ = self {
                    
                    var loadersCallbacksByKey = [Arg:JLoadersCallbacksData<Value, Error>]()
                    for (key, value) in self_.loadersCallbacksByKey {
                        loadersCallbacksByKey[key] = value.copy()
                    }
                    self_.clearState()
                    
                    for (key, value) in loadersCallbacksByKey {
                        
                        //TODO test not full results array
                        let result = results.map { $0[self_.indexOfKey(key)] }
                        
                        value.doneCallback?(result: result)
                        
                        value.unsubscribe()
                    }
                }
                
                finishCallback?(result: results)
            }
            
            return arrayLoader(
                progressCallback: progressCallbackWrapper,
                stateCallback   : stateCallbackWrapper,
                finishCallback  : doneCallbackWrapper)
        }
        
        let setter: CachedAsyncTypes<[Value], Error>.JResultSetter? = nil
        let getter: CachedAsyncTypes<[Value], Error>.JResultGetter? = nil
        
        let nativeLoader: AsyncTypes<[Value], Error>.Async = _cachedAsyncOp.asyncOpWithPropertySetter(
            setter,
            getter: getter,
            uniqueKey: keys,
            loader: loader)
        
        self.nativeLoader = nativeLoader
        
        var finished = false
        let handler = nativeLoader(
            progressCallback: nil,
            stateCallback   : nil,
            finishCallback  : { (result: AsyncResult<[Value], Error>) -> () in finished = true })
        
        if !finished {
            _nativeHandler = handler
        }
    }
}
