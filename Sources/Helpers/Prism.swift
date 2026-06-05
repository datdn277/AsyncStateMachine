//
//  Prism.swift
//  AsyncStateMachine
//
//  Created by MAC M1 on 5/27/26.
//

import Foundation

public struct Prism<Whole, Part>: Sendable {

    /// Thử extract Part từ Whole. Trả nil nếu Whole không phải case chứa Part.
    public let extract: @Sendable (Whole) -> Part?

    /// Tạo Whole từ Part (embed Part vào case tương ứng của Whole)
    public let embed: @Sendable (Part) -> Whole

    public init(
        extract: @escaping @Sendable (Whole) -> Part?,
        embed: @escaping @Sendable (Part) -> Whole
    ) {
        self.extract = extract
        self.embed = embed
    }
}

// MARK: - Prism composition
extension Prism {
    /// Compose prism: Prism<A, B> + Prism<B, C> = Prism<A, C>
    public func appending<SubPart>(
        _ other: Prism<Part, SubPart>
    ) -> Prism<Whole, SubPart> {
        Prism<Whole, SubPart>(
            extract: { whole in
                guard let part = self.extract(whole) else { return nil }
                return other.extract(part)
            },
            embed: { subPart in
                self.embed(other.embed(subPart))
            }
        )
    }
}
