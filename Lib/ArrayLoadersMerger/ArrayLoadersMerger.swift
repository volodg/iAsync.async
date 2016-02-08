//
//  ArrayLoadersMerger.swift
//  iAsync_async
//
//  Created by Vladimir Gorbenko on 11.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils
import iAsync_reactiveKit

final public class ArrayLoadersMerger<Arg: Hashable, Value> {

    public typealias AsyncOpAr = AsyncTypes<[Value], NSError>.Async

    public typealias ArrayOfObjectsLoader = (keys: [Arg]) -> AsyncOpAr

    private var _pendingLoadersCallbacksByKey = [Arg:LoadersCallbacksData<Value>]()
    private let _cachedAsyncOp = MergedAsyncStream<Arg, Value, AnyObject, NSError>()

    private let _arrayLoader: ArrayOfObjectsLoader

    private var activeArrayLoaders = [ActiveArrayLoader<Arg, Value>]()

    private func removeActiveLoader(loader: ActiveArrayLoader<Arg, Value>) {

        for (index, element) in activeArrayLoaders.enumerate() {

            if element === loader {
                self.activeArrayLoaders.removeAtIndex(index)
            }
        }
    }

    public init(arrayLoader: ArrayOfObjectsLoader) {
        _arrayLoader = arrayLoader
    }

    public func oneObjectLoader(key: Arg) -> AsyncTypes<Value, NSError>.Async {

        let loader = { (progressCallback: AsyncProgressCallback?,
                        finishCallback  : AsyncTypes<Value, NSError>.DidFinishAsyncCallback?) -> AsyncHandler in

            if let currentLoader = self.activeLoaderForKey(key) {

                let resultIndex = currentLoader.indexOfKey(key)

                let loader = bindSequenceOfAsyncs(currentLoader.nativeLoader!, { (result: [Value]) -> AsyncTypes<Value, NSError>.Async in

                    if result.count <= resultIndex {
                        //TODO fail
                        return async(result: .Failure(AsyncInterruptedError()))
                    }

                    return async(value: result[resultIndex])
                })

                return loader(
                    progressCallback: progressCallback,
                    finishCallback  : finishCallback)
            }

            let callbacks = LoadersCallbacksData(
                progressCallback: progressCallback,
                doneCallback    : finishCallback)

            self._pendingLoadersCallbacksByKey[key] = callbacks

            dispatch_async(dispatch_get_main_queue(), { [weak self] () -> () in
                self?.runLoadingOfPendingKeys()
            })

            return { (task: AsyncHandlerTask) -> () in

                switch task {
                case .UnSubscribe:
                    let indexOption = self._pendingLoadersCallbacksByKey.indexForKey(key)
                    if let index = indexOption {
                        let (_, callbacks) = self._pendingLoadersCallbacksByKey[index]
                        self._pendingLoadersCallbacksByKey.removeAtIndex(index)
                        callbacks.doneCallback = nil
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
                            finishCallback(result: .Failure(AsyncInterruptedError()))
                        }
                        callbacks.unsubscribe()
                    } else {
                        self.activeLoaderForKey(key)?.cancelLoader()
                    }
                }
            }
        }

        return self._cachedAsyncOp.mergedStream( { asyncToStream(loader) }, key: key).toAsync()
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

    private func activeLoaderForKey(key: Arg) -> ActiveArrayLoader<Arg, Value>? {

        let index = activeArrayLoaders.indexOf( { (activeLoader: ActiveArrayLoader<Arg, Value>) -> Bool in
            return activeLoader.loadersCallbacksByKey[key] != nil
        })

        return index.flatMap { activeArrayLoaders[$0] }
    }
}

final private class LoadersCallbacksData<Value> {

    var progressCallback: AsyncProgressCallback?
    var doneCallback    : AsyncTypes<Value, NSError>.DidFinishAsyncCallback?

    var suspended = false

    init(
        progressCallback: AsyncProgressCallback?,
        doneCallback    : AsyncTypes<Value, NSError>.DidFinishAsyncCallback?) {

        self.progressCallback = progressCallback
        self.doneCallback     = doneCallback
    }

    func unsubscribe() {
        progressCallback = nil
        doneCallback     = nil
    }

    func copy() -> LoadersCallbacksData {
        return LoadersCallbacksData(
            progressCallback: self.progressCallback,
            doneCallback    : self.doneCallback    )
    }
}

final private class ActiveArrayLoader<Arg: Hashable, Value> {

    var loadersCallbacksByKey: [Arg:LoadersCallbacksData<Value>]
    weak var owner: ArrayLoadersMerger<Arg, Value>?
    var keys = KeysType()

    private func indexOfKey(key: Arg) -> Int {

        for (index, currentKey) in keys.enumerate() {
            if currentKey == key {
                return index
            }
        }
        return -1
    }

    var nativeLoader : AsyncTypes<[Value], NSError>.Async? //Should be strong

    private var _nativeHandler: AsyncHandler?

    init(loadersCallbacksByKey: [Arg:LoadersCallbacksData<Value>], owner: ArrayLoadersMerger<Arg, Value>) {
        self.loadersCallbacksByKey = loadersCallbacksByKey
        self.owner                 = owner
    }

    func cancelLoader() {

        guard let block = _nativeHandler else { return }

        _nativeHandler = nil
        block(task: .Cancel)
        self.clearState()
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

        guard let index = loadersCallbacksByKey.indexForKey(key) else { return }

        let callbacks = loadersCallbacksByKey[index]
        callbacks.1.unsubscribe()
        loadersCallbacksByKey.removeAtIndex(index)
    }

    typealias KeysType = HashableArray<Arg>
    let _cachedAsyncOp = MergedAsyncStream<KeysType, [Value], AnyObject, NSError>()

    func runLoader() {

        assert(self.nativeLoader == nil)

        keys.removeAll()
        for (key, _) in loadersCallbacksByKey {
            keys.append(key)
        }

        let arrayLoader = owner!._arrayLoader(keys: Array(keys))

        let loader = { [weak self] (
            progressCallback: AsyncProgressCallback?,
            finishCallback  : AsyncTypes<[Value], NSError>.DidFinishAsyncCallback?) -> AsyncHandler in

            let progressCallbackWrapper = { (progressInfo: AnyObject) -> () in

                if let self_ = self {

                    for (_, value) in self_.loadersCallbacksByKey {
                        value.progressCallback?(progressInfo: progressInfo)
                    }
                }

                progressCallback?(progressInfo: progressInfo)
            }

            let doneCallbackWrapper = { (results: AsyncResult<[Value], NSError>) -> () in

                if let self_ = self {

                    var loadersCallbacksByKey = [Arg:LoadersCallbacksData<Value>]()
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
                finishCallback  : doneCallbackWrapper)
        }

        let nativeLoader: AsyncTypes<[Value], NSError>.Async = _cachedAsyncOp.mergedStream( { asyncToStream(loader) }, key: keys).toAsync()

        self.nativeLoader = nativeLoader

        var finished = false
        let handler = nativeLoader(
            progressCallback: nil,
            finishCallback  : { (result: AsyncResult<[Value], NSError>) -> () in finished = true })

        if !finished {
            _nativeHandler = handler
        }
    }
}
