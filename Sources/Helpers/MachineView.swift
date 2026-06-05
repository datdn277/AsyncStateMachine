//
//  MachineView.swift
//  AsyncStateMachine
//
//  Created by MAC M1 on 6/5/26.
//

import Foundation

#if canImport(SwiftUI)
import SwiftUI

@MainActor
public struct MachineView<V, VS, S, E, O>: View, Identifiable
where V: View,
      VS: Equatable,
      S: Equatable & DSLCompatible,
      E: DSLCompatible,
      O: DSLCompatible {
    
    @ObservedObject private var store: MachineViewStore<VS, S, E, O>
    private let builder: (VS, @escaping (E) -> Void) -> V
    
    public var cancelBag: CancelBag
    
    /// The stable identity of the entity associated with this instance.
    public var id: String
    
    public init(
        asyncStateMachine: AsyncStateMachine<S, E, O>,
        stateToViewState: @escaping @Sendable (S) -> VS,
        builder: @escaping (VS, @escaping (E) -> Void) -> V
    ) {
        self.store = MachineViewStore(
            asyncStateMachine: asyncStateMachine,
            stateToViewState: stateToViewState
        )
        self.builder = builder
        self.cancelBag = CancelBag()
        self.id = String(describing: ObjectIdentifier(asyncStateMachine))
    }
    
    public init(
        asyncStateMachine: AsyncStateMachine<S, E, O>,
        builder: @escaping (VS, @escaping (E) -> Void) -> V
    ) where VS == S {
        self.init(
            asyncStateMachine: asyncStateMachine,
            stateToViewState: { $0 },
            builder: builder
        )
    }
    
    public var body: some View {
        self.builder(self.store.state, { event in
            self.send(event)
        })
        .onAppear { [cancelBag, store] in
            cancelBag.insert(Task {
                await store.start()
            })
        }
        .onDisappear { [cancelBag] in
            cancelBag.cancel()
        }
    }
    
    public func send(_ event: E) {
        self.store.send(event)
    }
    
    public func send(
        _ event: E,
        resumeWhen predicate: @escaping (S) -> Bool
    ) async {
        await self.store.send(event, resumeWhen: predicate)
    }
    
    public func send(
        _ event: E,
        resumeWhen state: S
    ) async {
        await self.store.send(event, resumeWhen: state)
    }
    
    public func start() async {
        await self.store.start()
    }
}

private final class MachineViewStore<VS, S, E, O>: ObservableObject, @unchecked Sendable
where VS: Equatable,
      S: DSLCompatible & Equatable,
      E: DSLCompatible,
      O: DSLCompatible {
    
    private struct SendSuspension {
        let predicate: (S) -> Bool
        let continuation: UnsafeContinuation<Void, Never>
    }
    
    @Published private(set) var state: VS
    
    private let asyncStateMachine: AsyncStateMachine<S, E, O>
    private let stateToViewState: @Sendable (S) -> VS
    private var suspensions: [SendSuspension]
    private var running: Bool
    
    init(
        asyncStateMachine: AsyncStateMachine<S, E, O>,
        stateToViewState: @Sendable @escaping (S) -> VS
    ) {
        self.asyncStateMachine = asyncStateMachine
        self.stateToViewState = stateToViewState
        self.state = stateToViewState(asyncStateMachine.initialState)
        self.suspensions = []
        self.running = false
    }
    
    func send(_ event: E) {
        self.asyncStateMachine.send(event)
    }
    
    func send(
        _ event: E,
        resumeWhen predicate: @escaping (S) -> Bool
    ) async {
        await withUnsafeContinuation { continuation in
            self.suspensions.append(
                SendSuspension(predicate: predicate, continuation: continuation)
            )
            self.asyncStateMachine.send(event)
        }
    }
    
    func send(
        _ event: E,
        resumeWhen state: S
    ) async {
        await self.send(event, resumeWhen: { $0 == state })
    }
    
    func start() async {
        guard !self.running else { return }
        
        self.running = true
        defer { self.running = false }
        
        for await state in self.asyncStateMachine {
            await self.publish(state: state, viewState: self.stateToViewState(state))
        }
    }
    
    @MainActor
    private func publish(state: S, viewState: VS) {
        if viewState != self.state {
            self.state = viewState
        }
        
        var remainingSuspensions: [SendSuspension] = []
        var continuations: [UnsafeContinuation<Void, Never>] = []
        
        for suspension in self.suspensions {
            if suspension.predicate(state) {
                continuations.append(suspension.continuation)
            } else {
                remainingSuspensions.append(suspension)
            }
        }
        
        self.suspensions = remainingSuspensions
        continuations.forEach { $0.resume() }
    }
}
#endif
