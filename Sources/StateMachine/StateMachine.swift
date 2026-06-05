//
//  StateMachine.swift
//
//
//  Created by Thibault WITTEMBERG on 25/06/2022.
//

public struct StateMachine<S, E, O>: Sendable
where S: Sendable & DSLCompatible, E: DSLCompatible, O: DSLCompatible {
    public let whenStates: [When<S, E, O>]
    
    private let commandResolver: @Sendable (S) -> [O]
    private let reducer: @Sendable (S, E) async -> S?
    
    public init(@WhensBuilder<S, E, O> whenStates: () -> [When<S, E, O>]) {
        self.init(resolvedWhenStates: whenStates())
    }
    
    public init(whenStates: [When<S, E, O>]) {
        self.init(resolvedWhenStates: whenStates)
    }
    
    init(
        commandResolver: @escaping @Sendable (S) -> [O],
        reducer: @escaping @Sendable (S, E) async -> S?
    ) {
        self.whenStates = []
        self.commandResolver = commandResolver
        self.reducer = reducer
    }
    
    @Sendable
    public func command(for state: S) -> [O] {
        commandResolver(state)
    }
    
    @Sendable
    public func reduce(when state: S, on event: E) async -> S? {
        await reducer(state, event)
    }
    
    private init(resolvedWhenStates states: [When<S, E, O>]) {
        self.whenStates = states
        
        self.commandResolver = { state in
            states
                .filter { $0.predicate(state) }
                .compactMap { $0.output(state) }
        }
        
        self.reducer = { state, event in
            await states
                .filter { $0.predicate(state) }
                .flatMap { $0.transitions(state) }
                .first { $0.predicate(event) }?
                .transition(event)
        }
    }
}

@resultBuilder
public enum WhensBuilder<S, E, O>
where S: DSLCompatible, E: DSLCompatible, O: DSLCompatible {
    public static func buildExpression(
        _ expression: When<S, E, O>
    ) -> When<S, E, O> {
        expression
    }
    
    public static func buildBlock(
        _ components: When<S, E, O>...
    ) -> [When<S, E, O>] {
        components
    }
}
