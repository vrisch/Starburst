import Foundation
import XCTest
import Starburst

struct CounterState: State {
    var counter: Int = 0
    var counterCopy: Int = 0
}

struct AnotherState: State {
}

enum CounterAction: Action {
    case increase
    case decrease
    case double
    case nothing
    case disaster
}

struct CounterMiddleware {
    static func doubler(action: CounterAction, context: Context) -> Effect {
        switch action {
        case .increase: return .dispatch(CounterAction.double)
        default: return .none
        }
    }

    static func copier(state: inout CounterState, context: Context) -> Reduction<CounterState> {
        state.counterCopy = state.counter
        return .modified(newState: state)
    }
}

enum Error: Swift.Error {
    case disaster
}

func counterReducer(state: inout CounterState, action: CounterAction) throws -> Reduction<CounterState> {
    globalReducerCount += 1
    switch action {
    case .increase:
        state.counter += 1
        return .modified(newState: state)
    case .decrease:
        state.counter -= 1
        return .modified(newState: state)
    case .double:
        state.counter *= 2
        return .modified(newState: state)
    case .nothing:
        return .unmodified
    case .disaster:
        throw Error.disaster
    }
}

func counterObserver(state: CounterState, reason: Reason) {
    globalObserverCount += 1
    globalCounter = state.counter
    globalCounterCopy = state.counterCopy
}

var disposables: [Any] = []
var globalCounter = 0
var globalCounterCopy = 0
var globalObserverCount = 0
var globalReducerCount = 0
var globalErrorCount = 0

class StarburstTests: XCTestCase {
    
    override func setUp() {
        disposables.removeAll()

        globalCounter = 0
        globalCounterCopy = 0
        globalObserverCount = 0
        globalReducerCount = 0
        globalErrorCount = 0
    }
    
    func testImmutability() throws {
        let state = CounterState()
        disposables += [
            mainStore.add(state: state),
            mainStore.add(reducer: counterReducer)
        ]
        XCTAssertEqual(state.counter, 0)
        mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(state.counter, 0)
        print("\(mainStore)")
    }
    
    func testMutability() throws {
        disposables += [
            mainStore.add(state: CounterState()),
            mainStore.add(reducer: counterReducer),
            mainStore.subscribe(observer: counterObserver)
        ]
        XCTAssertEqual(mainStore.count, 3)
        XCTAssertEqual(globalCounter, 0)
        mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(globalCounter, 1)
        mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(globalCounter, 2)
        mainStore.dispatch(CounterAction.nothing)
        XCTAssertEqual(globalCounter, 2)
        XCTAssertEqual(globalObserverCount, 3) // Subscribe + 2 .increase actions
        
        disposables.removeAll()
        
        mainStore.dispatch(CounterAction.increase) // Should have no effect since store is reset
        XCTAssertEqual(globalCounter, 2)
        XCTAssertEqual(globalObserverCount, 3)
        
        XCTAssertEqual(globalReducerCount, 3)
    }
    
    func testReorderingRSO() throws {
        let state = CounterState()
        disposables += [
            mainStore.add(reducer: counterReducer),
            mainStore.add(state: state),
            mainStore.subscribe(observer: counterObserver),
        ]
        XCTAssertEqual(globalCounter, 0)
        XCTAssertEqual(globalObserverCount, 1) // Subscription
        mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(globalCounter, 1)
        
        XCTAssertEqual(globalReducerCount, 1)
    }
    
    func testReorderingROS() throws {
        let state = CounterState()
        disposables += [
            mainStore.add(reducer: counterReducer),
            mainStore.subscribe(observer: counterObserver),
            mainStore.add(state: state),
        ]
        XCTAssertEqual(globalCounter, 0)
        XCTAssertEqual(globalObserverCount, 1) // Subscription
        mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(globalCounter, 1)
        
        XCTAssertEqual(globalReducerCount, 1)
    }
    
    func testReorderingORS() throws {
        let state = CounterState()
        disposables += [
            mainStore.subscribe(observer: counterObserver),
            mainStore.add(reducer: counterReducer),
            mainStore.add(state: state),
        ]
        XCTAssertEqual(globalCounter, 0)
        XCTAssertEqual(globalObserverCount, 1) // Subscription
        mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(globalCounter, 1)
        
        XCTAssertEqual(globalReducerCount, 1)
    }
    
    func testReorderingOSR() throws {
        let state = CounterState()
        disposables += [
            mainStore.subscribe(observer: counterObserver),
            mainStore.add(state: state),
            mainStore.add(reducer: counterReducer),
        ]
        XCTAssertEqual(globalCounter, 0)
        XCTAssertEqual(globalObserverCount, 1) // Subscription
        mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(globalCounter, 1)
        
        XCTAssertEqual(globalReducerCount, 1)
    }
    
    func testMultipleStates() throws {
        let state1 = CounterState()
        let state2 = CounterState()
        disposables += [
            mainStore.add(reducer: counterReducer),
            mainStore.subscribe(observer: counterObserver),
            mainStore.add(state: state1),
            mainStore.add(state: state2),
        ]
        XCTAssertEqual(globalCounter, 0)
        XCTAssertEqual(globalObserverCount, 2) // Subscriptions
        mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(globalCounter, 1)
        
        XCTAssertEqual(globalReducerCount, 2)
    }
    
    func testErrors() {
        disposables += [
            mainStore.add(state: ErrorState()),
            mainStore.add(reducer: ErrorActions.reduce),
            mainStore.add(state: CounterState()),
            mainStore.add(reducer: counterReducer),
            mainStore.subscribe { (state: ErrorState, reason: Reason) in
                globalErrorCount = state.errors.count
            },
            mainStore.subscribe { (state: CounterState, reason: Reason) -> Effect in
                guard case .modified = reason else { return .none }
                return .dispatch(CounterAction.disaster)
            },
        ]
        mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(globalErrorCount, 1)
    }

    func testCount() {
        disposables += [
            mainStore.add(state: CounterState()),
            mainStore.add(reducer: counterReducer),
            mainStore.subscribe { (state: CounterState, reason: Reason) -> Effect in
                return .other({
                    disposables += [
                        mainStore.add(state: AnotherState())
                    ]
                })
            },
        ]
        XCTAssertEqual(mainStore.count, 4)
        
        disposables.removeAll()
        XCTAssertEqual(mainStore.count, 0)
    }

    func testMiddlewareAction() {
        disposables += [
            mainStore.add(state: CounterState()),
            mainStore.add(reducer: counterReducer),
            mainStore.subscribe(observer: counterObserver),
            mainStore.add(middleware: .action(CounterMiddleware.doubler)),
        ]
        mainStore.dispatch(CounterAction.increase) // 0 + 1 + double = 2
        mainStore.dispatch(CounterAction.increase) // 2 + 1 + double = 6
        XCTAssertEqual(globalCounter, 6)
    }

    func testMiddlewareState() {
        disposables += [
            mainStore.add(state: CounterState()),
            mainStore.add(reducer: counterReducer),
            mainStore.subscribe(observer: counterObserver),
            mainStore.add(middleware: .state(CounterMiddleware.copier)),
        ]
        mainStore.dispatch(CounterAction.increase)
        mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(globalCounter, 2)
        XCTAssertEqual(globalCounterCopy, 2)
    }

    static var allTests = [
        ("testImmutability", testImmutability),
        ("testMutability", testMutability),
        ("testReorderingRSO", testReorderingRSO),
        ("testReorderingROS", testReorderingROS),
        ("testReorderingORS", testReorderingORS),
        ("testReorderingOSR", testReorderingOSR),
        ("testMultipleStates", testMultipleStates),
        ("testExceptions", testErrors),
        ("testCount", testCount),
        ]
}
