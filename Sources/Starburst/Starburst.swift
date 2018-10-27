import Foundation

public protocol State {}
public protocol Action {}
public typealias Reducer<S: State, A: Action> = (_ state: inout S, _ action: A, _ context: Context) throws -> Reduction<S>
public typealias SimpleReducer<S: State, A: Action> = (_ state: inout S, _ action: A) throws -> Reduction<S>
public typealias Observer<S: State> = (_ state: S, _ reason: Reason) throws -> Void

public enum Reason {
    case subscribed
    case modified
    case middleware
}

public enum Reduction<S: State> {
    case unmodified
    case modified(newState: S)
    case effect(newState: S, action: Action)
    case effects(newState: S, actions: [Action])
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

public enum Middleware {
    case action((Action) throws -> Void)
    case state((State) throws -> State?)
}

public final class Store {
    public init() { }

    private var weakStates: [() -> StateBox?] = []
    private var weakReducers: [() -> ReducerBox?] = []
    private var weakMiddlewares: [() -> MiddlewareBox?] = []
    private var weakObservers: [() -> ObserverBox?] = []
}

public var mainStore = Store()

public extension Store {

    public var count: Int {
        return states.count + reducers.count + observers.count
    }
    
    public func add<S: State>(state: S) -> Any {
        let box = StateBox(state: state)
        weakStates.append { [weak box] in box }
        observers.forEach { try? $0.apply(state: state) }
        return box
    }

    public func add<S: State, A: Action>(reducer: @escaping SimpleReducer<S, A>) -> Any {
        let box = ReducerBox { state, action, _ in
            return try reducer(&state, action)
        }
        weakReducers.append { [weak box] in box }
        return box
    }

    public func add<S: State, A: Action>(reducer: @escaping Reducer<S, A>) -> Any {
        let box = ReducerBox(reducer: reducer)
        weakReducers.append { [weak box] in box }
        return box
    }

    public func add(middleware: Middleware) -> Any {
        let box = MiddlewareBox(middleware: middleware)
        weakMiddlewares.append { [weak box] in box }
        return box
    }

    public func subscribe<S: State>(priority: Priority = .normal, observer: @escaping Observer<S>) -> Any {
        let box = ObserverBox(priority: priority, observer: observer)
        weakObservers.append { [weak box] in box }
        states.forEach { try? $0.apply(observer: observer) }
        return box
    }

    public func dispatch(_ action: Action, trace: Trace = Trace()) {
        do {
            let context = Context(trace: trace)
            try middlewares.forEach { try $0.apply(action: action) }
            var effects: [Action] = []
            try states.forEach { state in
                effects += try state.apply(action: action, context: context, reducers: reducers, observers: observers, middlewares: middlewares)
            }
            dispatchAll(effects)
        } catch let error {
            dispatch(ErrorActions.append(error))
        }
    }

    public func dispatchAll(_ actions: [Action]) {
        actions.forEach { dispatch($0) }
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
