import Foundation

public protocol State {}
public protocol Action {}
public typealias Reducer<S: State, A: Action> = (_ state: inout S, _ action: A, _ context: Context) throws -> Reduction<S>
public typealias Observer<S: State> = (_ state: S, _ reason: Reason) throws -> Effect

public typealias SimpleReducer<S: State, A: Action> = (_ state: inout S, _ action: A) throws -> Reduction<S>
public typealias SimpleObserver<S: State> = (_ state: S, _ reason: Reason) throws -> Void

public enum Reason {
    case subscribed
    case modified
    case middleware
}

public enum Effect {
    case none
    case dispatch(Action)
    case dispatchAll([Action])
    case other(() -> Void)
}

public enum Reduction<S: State> {
    case unmodified
    case effect(Effect)
    case modified(newState: S)
    case sideeffect(newState: S, effect: Effect)
}

public enum Priority: Int {
    case high = 0
    case normal = 20
    case low = 50
}

public struct Trace: Hashable {
    private let id = UUID().uuidString
    public init() {}
}

public struct Context {
    public let trace: Trace
}

public enum Middleware<S: State> {
    case action((Action) throws -> [Effect])
    case state((S) throws -> [Effect])
}

public final class Store {
    public init() { }
    
    private let work = DispatchQueue(label: "Starburst")
    private var weakStates: [() -> StateBox?] = []
    private var weakReducers: [() -> ReducerBox?] = []
    private var weakMiddlewares: [() -> MiddlewareBox?] = []
    private var weakObservers: [() -> ObserverBox?] = []
}

public var mainStore = Store()

public extension Store {
    
    public var count: Int {
        var count = 0
        work.sync {
            count = states.count + reducers.count + observers.count
        }
        return count
    }
    
    public func add<S: State>(state: S) -> Any {
        let box = StateBox(state: state)
        work.sync {
            weakStates.append { [weak box] in box }
        }
        var effects: [Effect] = []
        observers.forEach { observer in
            effects += send { try observer.apply(state: state) }
        }
        process(effects)
        return box
    }
    
    public func add<S: State, A: Action>(reducer: @escaping Reducer<S, A>) -> Any {
        let box = ReducerBox(reducer: reducer)
        work.sync {
            weakReducers.append { [weak box] in box }
        }
        return box
    }

    public func add<S: State, A: Action>(reducer: @escaping SimpleReducer<S, A>) -> Any {
        return add(reducer: { state, action, _ in
            return try reducer(&state, action)
        })
    }

    public func add<S: State>(middleware: Middleware<S>) -> Any {
        let box = MiddlewareBox(middleware: middleware)
        work.sync {
            weakMiddlewares.append { [weak box] in box }
        }
        return box
    }
    
    public func subscribe<S: State>(priority: Priority = .normal, observer: @escaping Observer<S>) -> Any {
        let box = ObserverBox(priority: priority, observer: observer)
        work.sync {
            weakObservers.append { [weak box] in box }
        }
        var effects: [Effect] = []
        states.forEach { state in
            effects += send { try state.apply(observer: observer) }
        }
        process(effects)
        return box
    }
    
    public func subscribe<S: State>(observer: @escaping SimpleObserver<S>) -> Any {
        return subscribe(observer: { (state: S, reason: Reason) throws -> Effect in
            try observer(state, reason)
            return .none
        })
    }

    public func dispatch(_ action: Action, trace: Trace = Trace()) {
        let context = Context(trace: trace)
        var effects: [Effect] = []
        work.sync {
            middlewares.forEach { middleware in
                effects += send { try middleware.apply(action: action) }
            }
            states.forEach { state in
                effects += send {
                    try state.apply(action: action, context: context, reducers: reducers, observers: observers, middlewares: middlewares)
                }
            }
        }
        process(effects)
    }
    
    public func dispatchAll(_ actions: [Action], trace: Trace = Trace()) {
        actions.forEach { dispatch($0, trace: trace) }
    }
}

internal extension Store {
    
    internal var states: [StateBox] {
        return weakStates.map { $0() }.filter { $0 != nil }.map { $0! }
    }
    internal var reducers: [ReducerBox] {
        return weakReducers.map { $0() }.filter { $0 != nil }.map { $0! }
    }
    internal var middlewares: [MiddlewareBox] {
        return weakMiddlewares.map { $0() }.filter { $0 != nil }.map { $0! }
    }
    internal var observers: [ObserverBox] {
        return weakObservers.map { $0() }.filter { $0 != nil }.map { $0! }.sorted(by: { $0.priority.rawValue < $1.priority.rawValue })
    }
}
