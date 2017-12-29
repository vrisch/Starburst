import Foundation

final class AnyRootReducer<S: State> {
    init<A: Action>(reducer: @escaping Reducer<A, S>) {
        box = { (state, a) in
            guard let action = a as? A else { return .unmodified }
            
            var copy = state
            return try reducer(&copy, action)
        }
    }
    
    func apply<A: Action>(state: S, action: A) throws -> Reduction<S> {
        return try box(state, action)
    }
    
    let box: (_ state: S, _ action: Action) throws -> Reduction<S>
}

final class AnyKeyPathReducer<S: State> {
    init<A: Action, S2>(keyPath: WritableKeyPath<S, S2>, reducer: @escaping Reducer<A, S2>) {
        box = { (state, a, observers) in
            guard let action = a as? A else { return .unmodified }
            
            var copy = state[keyPath: keyPath]
            if case let .modified(newState) = try reducer(&copy, action) {
                var local = state
                local[keyPath: keyPath] = newState
                try observers.forEach { observer in
                    try observer?.apply(keyPath: keyPath, state: newState, reason: .modified)
                }
                return .modified(newState: local)
            }
            return .unmodified
        }
    }
    
    func apply<A: Action>(state: S, action: A, observers: [AnyKeyPathObserver<S>?]) throws -> Reduction<S> {
        return try box(state, action, observers)
    }
    
    let box: (_ state: S, _ action: Action, _ observers: [AnyKeyPathObserver<S>?]) throws -> Reduction<S>
}

final class AnyRootObserver<S: State> {
    init(priority: Priority, observer: @escaping Observer<S>) {
        self.priority = priority
        box = { (state, reason) in
            try observer(state, reason)
        }
    }
    
    func apply(state: S, reason: Reason) throws {
        try box(state, reason)
    }
    
    let priority: Priority
    let box: (_ state: S, _ reason: Reason) throws -> Void
}

final class AnyKeyPathObserver<S: State> {
    init<S2: State>(priority: Priority, keyPath: KeyPath<S, S2>, observer: @escaping Observer<S2>) {
        self.priority = priority
        box = { (keyPath2, s, reason) in
            guard keyPath2 == keyPath else { return }
            guard let state = s as? S2 else { return }
            try observer(state, reason)
        }
    }
    
    func apply<S2: State>(keyPath: AnyKeyPath, state: S2, reason: Reason) throws {
        try box(keyPath, state, reason)
    }
    
    let priority: Priority
    let box: (_ keyPath: AnyKeyPath, _ state: State, _ reason: Reason) throws -> Void
}
