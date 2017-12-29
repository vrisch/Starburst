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

extension Reason: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .subscribed: return "subscribed"
        case .modified: return "modified"
        }
    }
}

extension Store: CustomStringConvertible {

    public var description: String {
        var result = "\(type(of: self)): {\n"
        rootReducers.forEach { result.append("\($0)\n") }
        keyPathReducers.forEach { result.append("\($0)\n") }
        rootObservers.forEach { result.append("\($0)\n") }
        keyPathObservers.forEach { result.append("\($0)\n") }
        result.append("}")
        return result
    }
}
