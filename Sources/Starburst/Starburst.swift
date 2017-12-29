import Foundation

public protocol State {}
public protocol Action {}
public typealias Reducer<A: Action, S: State> = (_ state: inout S, _ action: A) throws -> Reduction<S>
public typealias Observer<S: State> = (_ state: S, _ reason: Reason) throws -> Void

public enum Reason {
    case subscribed
    case modified
}

public enum Reduction<S: State> {
    case unmodified
    case modified(newState: S)
}

public enum Priority: Int {
    case high = 0
    case normal = 20
    case low = 50
}

public final class Store<S: State> {
    
    public var count: Int {
        return rootReducers.count + keyPathReducers.count + rootObservers.count + keyPathObservers.count
    }
    
    public init(_ state: S) {
        self.state = state
    }
    
    public func add<A: Action>(reducer: @escaping Reducer<A, S>) -> Any {
        let red = AnyRootReducer(reducer: reducer)
        weakRootReducers.append { [weak red] in red }
        return red
    }
    
    public func add<A: Action, S2>(keyPath: WritableKeyPath<S, S2>, reducer: @escaping Reducer<A, S2>) -> Any {
        let red = AnyKeyPathReducer(keyPath: keyPath, reducer: reducer)
        weakKeyPathReducers.append { [weak red] in red }
        return red
    }
    
    public func subscribe(priority: Priority = .normal, observer: @escaping Observer<S>) -> Any {
        let obs = AnyRootObserver(priority: priority, observer: observer)
        weakRootObservers.append { [weak obs] in obs }
        try? observer(state, .subscribed)
        return obs
    }
    
    public func subscribe<S2: State>(keyPath: KeyPath<S, S2>, priority: Priority = .normal, observer: @escaping Observer<S2>) -> Any {
        let obs = AnyKeyPathObserver(priority: priority, keyPath: keyPath, observer: observer)
        weakKeyPathObservers.append { [weak obs] in obs }
        try? observer(state[keyPath: keyPath], .subscribed)
        return obs
    }
    
    public func dispatch<A: Action>(_ action: A) throws {
        var changed = false
        try keyPathReducers.forEach { reducer in
            if case let .modified(newState) = try reducer.apply(state: state, action: action, observers: keyPathObservers) {
                state = newState
                changed = true
            }
        }
        try rootReducers.forEach { reducer in
            if case let .modified(newState) = try reducer.apply(state: state, action: action) {
                state = newState
                changed = true
            }
        }
        if changed {
            try rootObservers.forEach { observer in
                try observer.apply(state: state, reason: .modified)
            }
        }
    }
    
    var rootReducers: [AnyRootReducer<S>] {
        return weakRootReducers.map { $0() }.filter { $0 != nil }.map { $0! }
    }
    var keyPathReducers: [AnyKeyPathReducer<S>] {
        return weakKeyPathReducers.map { $0() }.filter { $0 != nil }.map { $0! }
    }
    var rootObservers: [AnyRootObserver<S>] {
        return weakRootObservers.map { $0() }.filter { $0 != nil }.map { $0! }.sorted(by: { $0.priority.rawValue < $1.priority.rawValue })
    }
    var keyPathObservers: [AnyKeyPathObserver<S>] {
        return weakKeyPathObservers.map { $0() }.filter { $0 != nil }.map { $0! }.sorted(by: { $0.priority.rawValue < $1.priority.rawValue })
    }

    private var state: S
    private var weakRootReducers: [() -> AnyRootReducer<S>?] = []
    private var weakKeyPathReducers: [() -> AnyKeyPathReducer<S>?] = []
    private var weakRootObservers: [() -> AnyRootObserver<S>?] = []
    private var weakKeyPathObservers: [() -> AnyKeyPathObserver<S>?] = []
}
