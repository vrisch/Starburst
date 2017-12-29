import Foundation
import XCTest
import Starburst

struct CounterState: State {
    var counter = 0
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

var mainStore = Store(CounterState())
var disposables: [Any] = []
var globalCounter = 0
var globalObserverCount = 0
var globalReducerCount = 0

class StarburstTests: XCTestCase {
    
    override func setUp() {
        mainStore = Store(CounterState())
        disposables = []

        globalCounter = 0
        globalObserverCount = 0
        globalReducerCount = 0
    }
    
    func testImmutability() throws {
        let state = CounterState()
        disposables += [
            mainStore.add(reducer: counterReducer)
        ]
        XCTAssertEqual(state.counter, 0)
        try mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(state.counter, 0)
        print("\(mainStore)")
    }
    
    func testMutability() throws {
        disposables += [
            mainStore.add(reducer: counterReducer),
            mainStore.subscribe(observer: counterObserver)
        ]
        XCTAssertEqual(mainStore.count, 2)
        XCTAssertEqual(globalCounter, 0)
        try mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(globalCounter, 1)
        try mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(globalCounter, 2)
        try mainStore.dispatch(CounterAction.nothing)
        XCTAssertEqual(globalCounter, 2)
        XCTAssertEqual(globalObserverCount, 3) // Subscribe + 2 .increase actions

        disposables.removeAll()

        try mainStore.dispatch(CounterAction.increase) // Should have no effect since store is reset
        XCTAssertEqual(globalCounter, 2)
        XCTAssertEqual(globalObserverCount, 3)
        
        XCTAssertEqual(globalReducerCount, 3)
    }
    
    func testReorderingRO() throws {
        disposables += [
            mainStore.add(reducer: counterReducer),
            mainStore.subscribe(observer: counterObserver),
        ]
        XCTAssertEqual(globalCounter, 0)
        XCTAssertEqual(globalObserverCount, 1) // Subscription
        try mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(globalCounter, 1)
        
        XCTAssertEqual(globalReducerCount, 1)
    }
    
    func testReorderingOR() throws {
        disposables += [
            mainStore.subscribe(observer: counterObserver),
            mainStore.add(reducer: counterReducer),
        ]
        XCTAssertEqual(globalCounter, 0)
        XCTAssertEqual(globalObserverCount, 1) // Subscription
        try mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(globalCounter, 1)
        
        XCTAssertEqual(globalReducerCount, 1)
    }

    func testExceptions() {
        disposables += [
            mainStore.add(reducer: counterReducer),
            mainStore.subscribe { (state: CounterState, reason: Reason) throws in
                try mainStore.dispatch(CounterAction.disaster)
            },
        ]
        XCTAssertThrowsError(try mainStore.dispatch(CounterAction.increase))
    }
    
    func testCount() {
        disposables += [
            mainStore.add(reducer: counterReducer),
            mainStore.subscribe { (state: CounterState, reason: Reason) throws in
                try mainStore.dispatch(CounterAction.disaster)
            },
        ]
        XCTAssertEqual(mainStore.count, 2)

        disposables.removeAll()
        XCTAssertEqual(mainStore.count, 0)
    }
}
