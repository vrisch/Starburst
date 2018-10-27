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

public struct ErrorState: State {
    public var errors: [Error] = []
    
    public init() {}
}

public enum ErrorActions: Action {
    case append(Error)
    case clear

    public static func reduce(state: inout ErrorState, action: ErrorActions) throws -> Reduction<ErrorState> {
        switch action {
        case let .append(error):
            state.errors.append(error)
        case .clear:
            state.errors.removeAll()
        }
        return .modified(newState: state)
    }
}

public extension Store {
    
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
