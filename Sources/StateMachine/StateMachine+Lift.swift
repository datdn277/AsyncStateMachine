//
//  StateMachine+Lift.swift
//  AsyncStateMachine
//
//  Created by MAC M1 on 6/4/26.
//

import Foundation

extension StateMachine {
    public func lift<T>(state prism: Prism<T, S>) -> StateMachine<T, E, O>
    where T: DSLCompatible & Sendable {
        StateMachine<T, E, O>(
            commandResolver: {[command] parentState in
                guard let childState = prism.extract(parentState) else { return [] }
                return command(childState)
            },
            reducer: {[reduce] parentState, event in
                guard let childState = prism.extract(parentState) else { return nil }
                guard let newChild = await reduce(childState, event) else { return nil }
                return prism.embed(newChild)
            }
        )
    }
    
    public func lift<T>(event prism: Prism<T, E>) -> StateMachine<S, T, O>
    where T: DSLCompatible {
        StateMachine<S, T, O>(
            commandResolver: {[command] in command($0) },
            reducer: {[reduce] state, parentEvent in
                guard let childEvent = prism.extract(parentEvent) else { return nil }
                return await reduce(state, childEvent)
            }
        )
    }
    
    public func lift<T>(command prism: Prism<T, O>) -> StateMachine<S, E, T>
    where T: DSLCompatible {
        StateMachine<S, E, T>(
            commandResolver: {[command] in command($0).map{ prism.embed($0) }},
            reducer: {[reduce] in await reduce($0, $1) }
        )
    }
    
    public func lift<T>(state lens: Lens<T, S>) -> StateMachine<T, E, O>
    where T: Sendable {
        StateMachine<T, E, O>(
            commandResolver: {[command] parentState in command(lens.get(parentState)) },
            reducer: {[reduce] parentState, event in
                guard let newChild = await reduce(lens.get(parentState), event)
                else { return nil }
                return lens.set(parentState, newChild)
            }
        )
    }
    
    public func lift<T>(state lens: Lens<T, S?>) -> StateMachine<T, E, O>
    where T: Sendable {
        StateMachine<T, E, O>(
            commandResolver: {[command] parentState in
                guard let childState = lens.get(parentState) else { return [] }
                return command(childState)
            },
            reducer: {[reduce] parentState, event in
                guard let childState = lens.get(parentState) else { return nil }
                guard let newChild = await reduce(childState, event)
                else { return nil }
                return lens.set(parentState, newChild)
            }
        )
    }
}
