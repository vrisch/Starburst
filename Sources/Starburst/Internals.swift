import Foundation

struct Box {
    init<T>(value: T) {
        self.value = value
    }
    
    mutating func wrap<T>(value: T) {
        self.value = value
    }
    
    func unwrap<T>() -> T? {
        return value as? T
    }
    
    private var value: Any
}

final class ReducerBox {
    init<A: Action>(reducer: Reducer<A>) {
        box = Box(value: reducer)
    }
    
    func apply<A: Action>(state: inout A.S, action: A, observe: (A.S) throws -> Void) throws -> [A] {
        guard let reducer: Reducer<A> = box.unwrap() else { return [] }
        
        var effects: [A] = []
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
    
    private let box: Box
}

final class StateBox {
    init<S: State>(state: S) {
        box = Box(value: state)
    }
    
    func apply<A: Action>(action: A, reducers: [ReducerBox], observers: [ObserverBox]) throws -> [A] {
        var effects: [A] = []
        for reducer in reducers {
            if var state : A.S = box.unwrap() {
                effects += try reducer.apply(state: &state, action: action) { newState in
                    box.wrap(value: newState)
                    try observers.forEach {
                        try $0.apply(state: newState, reason: .modified)
                    }
                }
            }
        }
        return effects
    }
    
    func apply<S: State>(observer: Observer<S>) throws {
        guard let state: S = box.unwrap() else { return }
        try observer(state, .subscribed)
    }
    
    private var box: Box
}

final class ObserverBox {
    let priority: Priority
    
    init<S: State>(priority: Priority, observer: Observer<S>) {
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
