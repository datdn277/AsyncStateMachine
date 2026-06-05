//
//  CancelBag.swift
//  AsyncStateMachine
//
//  Created by MAC M1 on 6/5/26.
//

import Foundation

public final class CancelBag {
  private var tasks: [Task<Void, Never>]

  public init() {
    self.tasks = []
  }

  public func insert(_ task: Task<Void, Never>) {
    self.tasks.append(task)
  }

  public func cancel() {
    self.tasks.forEach { $0.cancel() }
    self.tasks.removeAll()
  }

  deinit {
    self.cancel()
  }
}
