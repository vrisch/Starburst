import Foundation

final class Box {
    init<T>(value: T) {
        self.value = value
    }
    
    func wrap<T>(value: T) {
        self.value = value
    }
    
    func unwrap<T>() -> T? {
        return value as? T
    }
    
    private var value: Any
}

final class ReducerBox {
    init<S: State, A: Action>(reducer: @escaping Reducer<S, A>) {
        box = Box(value: reducer)
        perform = { box, state, action, observe in
            guard let reducer: Reducer<S, A> = box.unwrap() else { return [] }
            guard var state = state as? S else { return [] }
            guard let action = action as? A else { return [] }
            
            var effects: [Action] = []
            switch try reducer(&state, action) {
            case .unmodified:
                break
            case let .modified(newState):
                try observe(newState)
            case let .effect(newState, action):
                try observe(newState)
                effects.append(action)
            case let .effects(newState, actions):
                try observe(newState)
                effects += actions
            }
            return effects
        }
    }
    
    func apply(state: State, action: Action, observe: (State) throws -> Void) throws -> [Action] {
        return try perform(box, state, action, observe)
    }
    
    private let box: Box
    private let perform: (Box, State, Action, (State) throws -> Void) throws -> [Action]
}

final class StateBox {
    init<S: State>(state: S) {
        box = Box(value: state)
        perform = { box, action, reducers, observers, middlewares in
            guard let state: S = box.unwrap() else { return [] }
            
            var effects: [Action] = []
            for reducer in reducers {
                effects += try reducer.apply(state: state, action: action) { newState in
                    guard var newState = newState as? S else { return }
                    
                    // State has changed
                    box.wrap(value: newState)
                    
                    // Notify observers
                    try observers.forEach {
                        try $0.apply(state: newState, reason: .modified)
                    }
                    
                    // Notify middlewares
                    var changes = false
                    try middlewares.forEach {
                        if let state = try $0.apply(state: newState) {
                            // State has changed again
                            box.wrap(value: state)
                            newState = state
                            changes = true
                        }
                        effects.append(result.1)
                    }
                    
                    if changes {
                        // Notify observers
                        try observers.forEach {
                            effects.append(try $0.apply(state: newState, reason: .middleware))
                        }
                    }
                }
            }
            return effects
        }
    }

    func apply(action: Action, reducers: [ReducerBox], observers: [ObserverBox], middlewares: [MiddlewareBox]) throws -> [Action] {
        return try perform(box, action, reducers, observers, middlewares)
    }

    func apply<S: State>(observer: Observer<S>) throws {
        guard let state: S = box.unwrap() else { return }
        try observer(state, .subscribed)
    }
    
    private var box: Box
    private var perform: (Box, Action, [ReducerBox], [ObserverBox], [MiddlewareBox]) throws -> [Action]
}
/*
final class MiddlewareBox {
    init(middleware: Middleware) {
        box = Box(value: middleware)
    }
    
    func apply(action: Action) throws {
        guard let middleware: Middleware = box.unwrap() else { return }
        if case let .action(f) = middleware {
            try f(action)
        }
    }
    
    func apply(state: State) throws -> State? {
        guard let middleware: Middleware = box.unwrap() else { return nil }
        if case let .state(f) = middleware {
            return try f(state)
        }
        return nil
    }
    
    private var box: Box
}
*/
final class MiddlewareBox {
    init(_ f: @escaping (Action) throws -> Void) {
        perform = { action, _ in
            guard let action = action else { return nil }
            try f(action)
            return nil
        }
    }
    init<S: State>(_ f: @escaping (inout S) throws -> Reduction<S>) {
        perform = { action, state in
            guard var newState = state as? S else { return nil }
            switch try f(&newState) {
            case .unmodified: return nil
            case let .effect(newState, _): return newState
            case let .modified(newState): return newState
            case let .effects(newState, _): return newState
            }
        }
    }
    
    func apply(action: Action) throws {
        _ = try perform(action, nil)
    }
    
    func apply<S: State>(state: S) throws -> S? {
        let result = try perform(nil, state)
        return result as? S
    }
    
    private var perform: (Action?, State?) throws -> State?
}

final class ObserverBox {
    let priority: Priority
    
    init<S: State>(priority: Priority, observer: @escaping Observer<S>) {
        self.priority = priority
        box = Box(value: observer)
    }
    
    func apply<S: State>(state: S, reason: Reason) throws {
        guard let observer: Observer<S> = box.unwrap() else { return }
        try observer(state, reason)
    }
    
    func apply<S: State>(state: S) throws {
        guard let observer: Observer<S> = box.unwrap() else { return }
        try observer(state, .subscribed)
    }
    
    private var box: Box
}
