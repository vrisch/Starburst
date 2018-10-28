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
            
            var effects: [Effect] = []
            switch try reducer(&state, action, context) {
            case .unmodified:
                break
            case let .modified(newState):
                try observe(newState)
            case let .sideeffect(newState, effect):
                try observe(newState)
                effects += [effect]
            case let .effect(effect):
                effects += [effect]
            }
            return effects
        }
    }
    
    func apply(state: State, action: Action, context: Context, observe: (State) throws -> Void) throws -> [Effect] {
        return try perform(box, state, action, context, observe)
    }
    
    private let box: Box
    private let perform: (Box, State, Action, Context, (State) throws -> Void) throws -> [Effect]
}

final class StateBox {
    init<S: State>(state: S) {
        box = Box(value: state)
        perform = { box, action, context, reducers, observers, middlewares in
            guard let state: S = box.unwrap() else { return [] }
            
            var effects: [Effect] = []
            for reducer in reducers {
                effects += try reducer.apply(state: state, action: action, context: context) { newState in
                    guard var newState = newState as? S else { return }
                    
                    // State has changed
                    box.wrap(value: newState)
                    
                    // Notify observers
                    try observers.forEach {
                        effects.append(try $0.apply(state: newState, reason: .modified))
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
                            effects.append(try $0.apply(state: newState, reason: .middleware))
                        }
                    }
                }
            }
            return effects
        }
    }

    func apply(action: Action, context: Context, reducers: [ReducerBox], observers: [ObserverBox], middlewares: [MiddlewareBox]) throws -> [Effect] {
        return try perform(box, action, context, reducers, observers, middlewares)
    }

    func apply<S: State>(observer: Observer<S>) throws -> Effect {
        guard let state: S = box.unwrap() else { return .none }
        return try observer(state, .subscribed)
    }
    
    private var box: Box
    private var perform: (Box, Action, Context, [ReducerBox], [ObserverBox], [MiddlewareBox]) throws -> [Effect]
}

final class MiddlewareBox {
    init<S: State>(middleware: Middleware<S>) {
        box = Box(value: middleware)
        perform = { box, action, state in
            guard let middleware: Middleware<S> = box.unwrap() else { return [] }

            var effects: [Effect] = []
            switch middleware {
            case let .action(f):
                guard let action = action else { return [] }
                effects += try f(action)
            case let .state(f):
                guard let state = state as? S else { return [] }
                effects += try f(state)
            }
            return effects
        }
    }
    
    func apply(action: Action) throws -> [Effect] {
        return try perform(box, action, nil)
    }

    func apply(state: State) throws -> [Effect] {
        return try perform(box, nil, state)
    }

    private var box: Box
    private var perform: (Box, Action?, State?) throws -> [Effect]
}

final class ObserverBox {
    let priority: Priority
    
    init<S: State>(priority: Priority, observer: @escaping Observer<S>) {
        self.priority = priority
        self.box = Box(value: observer)
    }
    
    func apply<S: State>(state: S, reason: Reason) throws -> Effect {
        guard let observer: Observer<S> = box.unwrap() else { return .none }
        return try observer(state, reason)
    }
    
    func apply<S: State>(state: S) throws -> Effect {
        guard let observer: Observer<S> = box.unwrap() else { return .none }
        return try observer(state, .subscribed)
    }
    
    private var box: Box
}

extension Store {
    internal func send(block: () throws -> Effect) -> [Effect] {
        return send {
            return [try block()]
        }
    }

    internal func send(block: () throws -> [Effect]) -> [Effect] {
        var effects: [Effect] = []
        do {
            effects += try block()
        } catch let error {
            let effect: Effect = .dispatch(ErrorActions.append(error))
            effects.append(effect)
        }
        return effects
    }
    
    internal func process(_ effects: [Effect]) {
        effects.forEach { effect in
            switch effect {
            case .none:
                break
            case let .dispatch(action):
                mainStore.dispatch(action)
            case let .dispatchAll(actions):
                mainStore.dispatchAll(actions)
            case let .other(block):
                block()
            }
        }
    }
}
