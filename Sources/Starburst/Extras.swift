import Foundation

public extension Reason {
    public var isSubscribed: Bool {
        guard case .subscribed = self else { return false }
        return true
    }
    public var isModified: Bool {
        guard case .modified = self else { return false }
        return true
    }
}

public extension Effect {
    public var actions: [Action] {
        switch self {
        case .none: return []
        case let .action(action): return [action]
        case let .actions(actions): return actions
        }
    }
}

public struct ErrorState: State {
    public var errors: [Error] = []
    public var traceableErrors: [Trace: Error] = [:]

    public init() {}
}

public enum ErrorActions: Action {
    case append(Error)
    case clear
    
    public static func reduce(state: inout ErrorState, action: ErrorActions, context: Context) -> Reduction<ErrorState> {
        switch action {
        case let .append(error):
            state.errors.append(error)
            state.traceableErrors[context.trace] = error
        case .clear:
            state.errors.removeAll()
            state.traceableErrors.removeAll()
        }
        return .modified(newState: state)
    }
}

public extension Store {
    public func trace<S : State, Item>(trace: Trace, keyPath: KeyPath<S, [Trace: Item]>, observer: @escaping (Item) -> Void) -> Any {
        return subscribe { (state: S, reason) in
            guard case reason = Reason.modified else { return }
            if let item = state[keyPath: keyPath][trace] {
                observer(item)
            }
        }
    }
    
    public func dispatchScheduled(_ action: Action, repeating: DispatchTimeInterval, leeway: DispatchTimeInterval =  .seconds(1)) -> Any {
        let timerSource = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timerSource.schedule(deadline: .now(), repeating: repeating, leeway: leeway)
        timerSource.setEventHandler { [weak self] in
            self?.dispatch(action)
        }
        timerSource.resume()
        return timerSource
    }
}

extension Reason: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .subscribed: return "subscribed"
        case .modified: return "modified"
        case .middleware: return "middleware"
        }
    }
}

extension Store: CustomStringConvertible {
    
    public var description: String {
        var result = "\(type(of: self)): {\n"
        states.forEach { result.append("\($0)\n") }
        reducers.forEach { result.append("\($0)\n") }
        observers.forEach { result.append("\($0)\n") }
        result.append("}")
        return result
    }
}
