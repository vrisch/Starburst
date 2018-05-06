import Foundation

public protocol State {}
public protocol Action {
    associatedtype S: State
}
public typealias Reducer<A: Action> = (_ state: inout A.S, _ action: A) throws -> Reduction<A.S>
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

public final class Store {

    public init() { }

    private var weakStates: [() -> StateBox?] = []
    private var weakReducers: [() -> ReducerBox?] = []
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
    
    public func add<A: Action>(reducer: @escaping Reducer<A>) -> Any {
        let box = ReducerBox(reducer: reducer)
        weakReducers.append { [weak box] in box }
        return box
    }
    
    public func subscribe<S: State>(priority: Priority = .normal, observer: @escaping Observer<S>) -> Any {
        let box = ObserverBox(priority: priority, observer: observer)
        weakObservers.append { [weak box] in box }
        states.forEach { try? $0.apply(observer: observer) }
        return box
    }

    public func dispatch<A: Action>(_ action: A) throws {
        try? states.forEach {
            try $0.apply(action: action, reducers: reducers, observers: observers)
        }
    }

    public func dispatchAll<A: Action>(_ actions: [A]) throws {
        try actions.forEach { try dispatch($0) }
    }
}

public extension Reduction {
    
    public func map<T>(_ f: @escaping (S) -> T) -> Reduction<T> {
        switch self {
        case let .modified(a):
            return .modified(newState: f(a))
        case .unmodified:
            return .unmodified
        }
    }
}

internal extension Store {
    
    internal var states: [StateBox] {
        return weakStates.map { $0() }.filter { $0 != nil }.map { $0! }
    }
    internal var reducers: [ReducerBox] {
        return weakReducers.map { $0() }.filter { $0 != nil }.map { $0! }
    }
    internal var observers: [ObserverBox] {
        return weakObservers.map { $0() }.filter { $0 != nil }.map { $0! }.sorted(by: { $0.priority.rawValue < $1.priority.rawValue })
    }
}
