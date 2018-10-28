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
        perform = { box, state, action, context, observe in
            guard let reducer: Reducer<S, A> = box.unwrap() else { return [] }
            guard var state = state as? S else { return [] }
            guard let action = action as? A else { return [] }
            
            var actions: [Action] = []
            switch try reducer(&state, action, context) {
            case .unmodified:
                break
            case let .modified(newState):
                try observe(newState)
            case let .sideeffect(newState, effect):
                try observe(newState)
                actions += effect.actions
            case let .effect(effect):
                actions += effect.actions
            }
            return actions
        }
    }
    
    func apply(state: State, action: Action, context: Context, observe: (State) throws -> Void) throws -> [Action] {
        return try perform(box, state, action, context, observe)
    }
    
    private let box: Box
    private let perform: (Box, State, Action, Context, (State) throws -> Void) throws -> [Action]
}

final class StateBox {
    init<S: State>(state: S) {
        box = Box(value: state)
        perform = { box, action, context, reducers, observers, middlewares in
            guard let state: S = box.unwrap() else { return [] }
            
            var actions: [Action] = []
            for reducer in reducers {
                actions += try reducer.apply(state: state, action: action, context: context) { newState in
                    guard var newState = newState as? S else { return }
                    
                    // State has changed
                    box.wrap(value: newState)
                    
                    // Notify observers
                    try observers.forEach {
                        actions += try $0.apply(state: newState, reason: .modified)
                    }
                    
                    // Notify middlewares
                    var changes = false
                    try middlewares.forEach {
                        if let state = try $0.apply(state: newState) as? S {
                            // State has changed again
                            box.wrap(value: state)
                            newState = state
                            changes = true
                        }
                    }
                    
                    if changes {
                        // Notify observers
                        try observers.forEach {
                            actions += try $0.apply(state: newState, reason: .middleware)
                        }
                    }
                }
            }
            return actions
        }
    }

    func apply(action: Action, context: Context, reducers: [ReducerBox], observers: [ObserverBox], middlewares: [MiddlewareBox]) throws -> [Action] {
        return try perform(box, action, context, reducers, observers, middlewares)
    }

    func apply<S: State>(observer: Observer<S>) throws -> [Action] {
        guard let state: S = box.unwrap() else { return [] }
        return try observer(state, .subscribed).actions
    }
    
    private var box: Box
    private var perform: (Box, Action, Context, [ReducerBox], [ObserverBox], [MiddlewareBox]) throws -> [Action]
}

final class MiddlewareBox {
    init(middleware: Middleware) {
        box = Box(value: middleware)
    }
    
    func apply(action: Action) throws -> [Action] {
        guard let middleware: Middleware = box.unwrap() else { return [] }
        if case let .action(f) = middleware {
            return try f(action).actions
        }
        return []
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

final class ObserverBox {
    let priority: Priority
    
    init<S: State>(priority: Priority, observer: @escaping Observer<S>) {
        self.priority = priority
        self.box = Box(value: observer)
    }
    
    func apply<S: State>(state: S, reason: Reason) throws -> [Action] {
        guard let observer: Observer<S> = box.unwrap() else { return [] }
        return try observer(state, reason).actions
    }
    
    func apply<S: State>(state: S) throws -> [Action] {
        guard let observer: Observer<S> = box.unwrap() else { return [] }
        return try observer(state, .subscribed).actions
    }
    
    private var box: Box
}

extension Store {
    internal func send(block: () throws -> [Action]) -> [Action] {
        var actions: [Action] = []
        do {
            actions += try block()
        } catch let error {
            actions.append(ErrorActions.append(error))
        }
        return actions
    }
}
