import Foundation
import XCTest
import Starburst

struct CounterState: State {
    var counter: Int = 0
}

enum CounterAction: Action {
    case increase
    case decrease
    case nothing
    case disaster
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
    case .nothing:
        return .unmodified
    case .disaster:
        throw Error.disaster
    }
}

func counterObserver(state: CounterState, reason: Reason) {
    globalObserverCount += 1
    globalCounter = state.counter
}

var disposables: [Any] = []
var globalCounter = 0
var globalObserverCount = 0
var globalReducerCount = 0
var globalErrorCount = 0

class StarburstTests: XCTestCase {
    
    override func setUp() {
        disposables.removeAll()

        globalCounter = 0
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
                return .action(CounterAction.disaster)
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
                return .action(CounterAction.disaster)
            },
        ]
        XCTAssertEqual(mainStore.count, 3)
        
        disposables.removeAll()
        XCTAssertEqual(mainStore.count, 0)
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
