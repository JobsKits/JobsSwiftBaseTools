//
//  weak.swift
//  JobsSwiftBaseConfigDemo
//
//  Created by Mac on 10/30/25.
//

import Foundation

@inlinable
public func jobs_weakify<Owner: AnyObject>(
    _ owner: Owner,
    _ block: @escaping jobsByNonNullTypeBlock<Owner>
) -> jobsByVoidBlock {
    { [weak owner] in
        guard let owner else { return }
        block(owner)
    }
}

@inlinable
public func jobs_weakify<Owner: AnyObject, Arg>(
    _ owner: Owner,
    _ block: @escaping jobsByOwnerArgBlock<Owner, Arg>
) -> jobsByArgBlock<Arg> {
    { [weak owner] arg in
        guard let owner else { return }
        block(owner, arg)
    }
}
// ✅ 有返回值（无参）→ 返回值可选
@inlinable
public func jobs_weakify<Owner: AnyObject, R>(
    _ owner: Owner,
    _ block: @escaping jobsByOwnerRetBlock<Owner, R>
) -> JobsRetOptionalTByVoidBlock<R> {
    { [weak owner] in
        guard let owner else { return nil }
        return block(owner)
    }
}
// ✅ 有返回值（带参）→ 返回值可选
@inlinable
public func jobs_weakify<Owner: AnyObject, Arg, R>(
    _ owner: Owner,
    _ block: @escaping jobsByOwnerArgRetBlock<Owner, Arg, R>
) -> JobsRetOptionalTByArgBlock<Arg, R> {
    { [weak owner] arg in
        guard let owner else { return nil }
        return block(owner, arg)
    }
}
// MARK: - weak + 柯里化
@inlinable
public func jobs_weakify<Owner: AnyObject, R>(
    _ owner: Owner,
    _ function: @escaping jobsByCurriedOwnerRetBlock<Owner, R>
) -> JobsRetOptionalTByVoidBlock<R> {
    { [weak owner] in
        guard let owner else { return nil }
        return function(owner)()
    }
}

@inlinable
public func jobs_weakify<Owner: AnyObject, Arg, R>(
    _ owner: Owner,
    _ function: @escaping jobsByCurriedOwnerArgRetBlock<Owner, Arg, R>
) -> JobsRetOptionalTByArgBlock<Arg, R> {
    { [weak owner] arg in
        guard let owner else { return nil }
        return function(owner)(arg)
    }
}
// MARK: - Unowned
@inlinable
public func jobs_unownedify<Owner: AnyObject>(
    _ owner: Owner,
    _ block: @escaping jobsByNonNullTypeBlock<Owner>
) -> jobsByVoidBlock {
    { [unowned owner] in
        block(owner)
    }
}

@inlinable
public func jobs_unownedify<Owner: AnyObject, Arg>(
    _ owner: Owner,
    _ block: @escaping jobsByOwnerArgBlock<Owner, Arg>
) -> jobsByArgBlock<Arg> {
    { [unowned owner] arg in
        block(owner, arg)
    }
}
// ✅ 有返回值（无参）
@inlinable
public func jobs_unownedify<Owner: AnyObject, R>(
    _ owner: Owner,
    _ block: @escaping jobsByOwnerRetBlock<Owner, R>
) -> JobsRetTByVoidBlock<R> {
    { [unowned owner] in
        block(owner)
    }
}
// ✅ 有返回值（带参）
@inlinable
public func jobs_unownedify<Owner: AnyObject, Arg, R>(
    _ owner: Owner,
    _ block: @escaping jobsByOwnerArgRetBlock<Owner, Arg, R>
) -> (Arg) -> R {
    { [unowned owner] arg in
        block(owner, arg)
    }
}
// MARK: - Unowned + 柯里化
@inlinable
public func jobs_unownedify<Owner: AnyObject, R>(
    _ owner: Owner,
    _ function: @escaping jobsByCurriedOwnerRetBlock<Owner, R>
) -> JobsRetTByVoidBlock<R> {
    { [unowned owner] in
        function(owner)()
    }
}

@inlinable
public func jobs_unownedify<Owner: AnyObject, Arg, R>(
    _ owner: Owner,
    _ function: @escaping jobsByCurriedOwnerArgRetBlock<Owner, Arg, R>
) -> (Arg) -> R {
    { [unowned owner] arg in
        function(owner)(arg)
    }
}
