//
//  AsyncTypesTransform.swift
//  iAsync
//
//  Created by Vladimir Gorbenko on 04.10.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

public enum AsyncTypesTransform<Value1, Value2, Error: ErrorType> {
    
    public typealias Async1 = AsyncTypes<Value1, Error>.Async
    public typealias Async2 = AsyncTypes<Value2, Error>.Async
    
    public typealias PackedType = (Value1?, Value2?)
    
    public typealias PackedAsync = AsyncTypes<PackedType, Error>.Async
    
    public typealias AsyncTransformer = (PackedAsync) -> PackedAsync
    
    public static func transformLoadersType1(async1: Async1, transformer: AsyncTransformer) -> Async1 {
        
        let packedLoader = bindSequenceOfAsyncs(async1, { result -> PackedAsync in
            return async(value: (result, nil))
        })
        let transformedLoader = transformer(packedLoader)
        return bindSequenceOfAsyncs(transformedLoader, { result -> Async1 in
            return async(value: result.0!)
        })
    }
    
    public static func transformLoadersType2(async2: Async2, transformer: AsyncTransformer) -> Async2 {
        
        let packedLoader = bindSequenceOfAsyncs(async2, { result -> PackedAsync in
            return async(value: (nil, result))
        })
        let transformedLoader = transformer(packedLoader)
        return bindSequenceOfAsyncs(transformedLoader, { result -> Async2 in
            return async(value: result.1!)
        })
    }
}
