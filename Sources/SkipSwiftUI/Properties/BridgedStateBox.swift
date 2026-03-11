// Copyright 2025 Skip
// SPDX-License-Identifier: LGPL-3.0-only WITH LGPL-3.0-linking-exception
import OpenCombine
import OpenCombineDispatch
import SkipBridge
import SkipUI

public final class BridgedStateBox<Value> {
    private let comparator: (Value, Value) -> Bool
    private var cancellable: AnyCancellable?

    init(_ value: Value, comparator: @escaping (Value, Value) -> Bool) {
        self._value = Box(value)
        self.comparator = comparator
    }
    
    init(_ value: Value) where Value: OpenCombine.ObservableObject {
        self._value = Box(value)
        self.comparator = { _, _ in false }
        self.addObserver(to: value)
    }

    var value: Value {
        get {
            Java_stateSupport?.access()
            return _value.value
        }
        set {
            let isUpdate = !comparator(_value.value, newValue)
            _value.value = newValue
            if let observable = newValue as? any OpenCombine.ObservableObject {
                self.addObserver(to: observable)
            }
            if isUpdate {
                Java_stateSupport?.update()
            }
        }
    }
    private var _value: Box<Value>

    private var Java_stateSupport: StateSupport?

    public func Java_initStateSupport() -> StateSupport {
        let ptr = SwiftObjectPointer.pointer(to: _value, retain: true)
        Java_stateSupport = StateSupport(valueHolder: ptr)
        return Java_stateSupport!
    }

    public func Java_syncStateSupport(_ support: StateSupport) {
        let box: Box<Value> = support.valueHolder.pointee()!
        _value = box
        if let observable = box.value as? any OpenCombine.ObservableObject {
            self.addObserver(to: observable)
        }
        Java_stateSupport = support
    }
    
    private func addObserver(to value: some OpenCombine.ObservableObject)  {
        self.cancellable = value.objectWillChange.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.Java_stateSupport?.update()
        }
    }
}

//extension BridgedStateBox : @unchecked Sendable where Value : Sendable {
//}
