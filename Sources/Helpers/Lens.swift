//
//  Lens.swift
//  AsyncStateMachine
//
//  Created by MAC M1 on 5/27/26.
//

import Foundation

public struct Lens<Whole, Part>: Sendable {
    /// Đọc Part từ Whole
    public let get: @Sendable (Whole) -> Part
    
    /// Tạo Whole mới với Part được thay thế (immutable update)
    public let set: @Sendable (Whole, Part) -> Whole
    
    public init(
        get: @escaping @Sendable (Whole) -> Part,
        set: @escaping @Sendable (Whole, Part) -> Whole
    ) {
        self.get = get
        self.set = set
    }
}

// MARK: - Lens composition
extension Lens {
    /// Compose lens: Lens<A, B> + Lens<B, C> = Lens<A, C>
    public func appending<SubPart>(
        _ other: Lens<Part, SubPart>
    ) -> Lens<Whole, SubPart> {
        Lens<Whole, SubPart>(
            get: { other.get(self.get($0)) },
            set: { whole, subPart in
                let oldPart = self.get(whole)
                let newPart = other.set(oldPart, subPart)
                return self.set(whole, newPart)
            }
        )
    }
}

// MARK: - Tiện ích tạo Lens từ KeyPath
extension Lens {
    /// Tạo Lens từ WritableKeyPath cho struct
    public static func keyPath<Root>(
        _ keyPath: WritableKeyPath<Root, Part>
    ) -> Lens<Root, Part> where Whole == Root {
        Lens(
            get: { $0[keyPath: keyPath] },
            set: { root, part in
                var copy = root
                copy[keyPath: keyPath] = part
                return copy
            }
        )
    }
}
