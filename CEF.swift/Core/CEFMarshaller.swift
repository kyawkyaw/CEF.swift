//
//  CEFMarshaller.swift
//  CEF.swift
//
//  Created by Tamas Lustyik on 2015. 07. 24..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation


public protocol DefaultInitializable {
    init()
}

protocol CEFCallbackMarshalling {
    mutating func marshalCallbacks()
}


class CEFMarshallerBase {
    static var _registryLock: Lock = CEFMarshallerBase.createLock()
    static var _registry = Dictionary<UnsafeMutablePointer<cef_base_t>, CEFMarshallerBase>()
    
    static func register(ptr: UnsafeMutablePointer<cef_base_t>, forObject obj: CEFMarshallerBase) {
        _registryLock.lock()
        defer { _registryLock.unlock() }
        
        _registry[ptr] = obj
    }
    
    static func deregister(ptr: UnsafeMutablePointer<cef_base_t>) {
        _registryLock.lock()
        defer { _registryLock.unlock() }
        
        _registry.removeValueForKey(ptr)
    }

    static func lookup(ptr: UnsafeMutablePointer<cef_base_t>) -> CEFMarshallerBase? {
        _registryLock.lock()
        defer { _registryLock.unlock() }
        
        return _registry[ptr]
    }
    
    static func createLock() -> Lock {
        var mutex = pthread_mutex_t()
        pthread_mutex_init(&mutex, nil)
        return mutex
    }
    
    static func destroyLock(lock: Lock) {
        guard var mutex = lock as? pthread_mutex_t else {
            return
        }
        pthread_mutex_destroy(&mutex)
    }
}

class CEFMarshaller<TClass, TStruct where TStruct : CEFObject, TStruct : CEFCallbackMarshalling>: CEFMarshallerBase, CEFRefCounting {
    typealias InstanceType = CEFMarshaller<TClass, TStruct>
    
    var cefStruct: TStruct
    var swiftObj: TClass
    
    static func get(ptr: UnsafeMutablePointer<TStruct>) -> TClass? {
        let basePtr = UnsafeMutablePointer<cef_base_t>(ptr)
        guard let marshaller = lookup(basePtr) as? InstanceType else {
            return nil
        }
        return marshaller.swiftObj
    }
    
    static func take(ptr: UnsafeMutablePointer<TStruct>) -> TClass? {
        let basePtr = UnsafeMutablePointer<cef_base_t>(ptr)
        guard let marshaller = lookup(basePtr) as? InstanceType else {
            return nil
        }
        marshaller.release()
        return marshaller.swiftObj
    }
    
    static func pass(obj: TClass) -> UnsafeMutablePointer<TStruct> {
        let marshaller = CEFMarshaller(obj: obj)
        marshaller.addRef()
        
        return UnsafeMutablePointer<TStruct>(getBasePtr(marshaller))
    }
    
    static func getBasePtr(marshaller: CEFMarshaller) -> UnsafeMutablePointer<cef_base_t> {
        let unmanaged = Unmanaged<AnyObject>.passUnretained(marshaller)
        let marshallerPtr = UnsafeMutablePointer<Int8>(unmanaged.toOpaque())
        let structPtr = marshallerPtr.advancedBy(16)
        return UnsafeMutablePointer<cef_base_t>(structPtr)
    }
    
    required init(obj: TClass) {
        pthread_mutex_init(&_refCountMutex, nil)
        
        swiftObj = obj
        cefStruct = TStruct()

        cefStruct.base.size = sizeof(TStruct.self)
        cefStruct.base.add_ref = CEFMarshaller_addRef
        cefStruct.base.release = CEFMarshaller_release
        cefStruct.base.has_one_ref = CEFMarshaller_hasOneRef

        cefStruct.marshalCallbacks()
    }
    
    deinit {
        pthread_mutex_destroy(&_refCountMutex)
    }
    
    // reference counting
    
    func addRef() {
        _refCountMutex.lock()
        defer { _refCountMutex.unlock() }
        ++_refCount
        if _refCount == 1 {
            let basePtr = CEFMarshaller.getBasePtr(self)
            CEFMarshaller.register(basePtr, forObject: self)
        }
        _self = self
    }
    
    func release() -> Bool {
        _refCountMutex.lock()
        defer { _refCountMutex.unlock() }
        --_refCount
        let shouldRelease = _refCount == 0
        if shouldRelease {
            _self = nil
            let basePtr = CEFMarshaller.getBasePtr(self)
            CEFMarshaller.deregister(basePtr)
        }
        return shouldRelease
    }
    
    func hasOneRef() -> Bool {
        _refCountMutex.lock()
        defer { _refCountMutex.unlock() }
        return _refCount == 1
    }
    
    var _refCount: Int = 0
    var _refCountMutex = pthread_mutex_t()
    var _self: InstanceType? = nil
}

func CEFMarshaller_addRef(ptr: UnsafeMutablePointer<cef_base_t>) {
    guard let marshaller = CEFMarshallerBase.lookup(ptr) as? CEFRefCounting else {
        return
    }
    marshaller.addRef()
}

func CEFMarshaller_release(ptr: UnsafeMutablePointer<cef_base_t>) -> Int32 {
    guard let marshaller = CEFMarshallerBase.lookup(ptr) as? CEFRefCounting else {
        return 0
    }
    return marshaller.release() ? 1 : 0
}

func CEFMarshaller_hasOneRef(ptr: UnsafeMutablePointer<cef_base_t>) -> Int32 {
    guard let marshaller = CEFMarshallerBase.lookup(ptr) as? CEFRefCounting else {
        return 0
    }
    return marshaller.hasOneRef() ? 1 : 0
}