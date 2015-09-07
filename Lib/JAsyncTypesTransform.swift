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
    
    private typealias Async1 = AsyncTypes<Value1, Error>.Async
    private typealias Async2 = AsyncTypes<Value2, Error>.Async
    
    public typealias PackedType = (Value1?, Value2?)
    
    private typealias PackedAsync = AsyncTypes<PackedType, Error>.Async
    
    public typealias AsyncTransformer = (PackedAsync) -> PackedAsync
    
    public static func transformLoadersType1(async: Async1, transformer: AsyncTransformer) -> Async1 {
        
        let packedLoader = bindSequenceOfAsyncs(async, { result -> PackedAsync in
            return asyncWithValue((result, nil))
        })
        let transformedLoader = transformer(packedLoader)
        return bindSequenceOfAsyncs(transformedLoader, { result -> Async1 in
            return asyncWithValue(result.0!)
        })
    }
    
    public static func transformLoadersType2(async: Async2, transformer: AsyncTransformer) -> Async2 {
        
        let packedLoader = bindSequenceOfAsyncs(async, { result -> PackedAsync in
            return asyncWithValue((nil, result))
        })
        let transformedLoader = transformer(packedLoader)
        return bindSequenceOfAsyncs(transformedLoader, { result -> Async2 in
            return asyncWithValue(result.1!)
        })
    }
}
