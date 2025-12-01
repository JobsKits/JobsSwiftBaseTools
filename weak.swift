//
//  weak.swift
//  JobsSwiftBaseConfigDemo
//
//  Created by Mac on 10/30/25.
//

// MARK: - weak
@inlinable
public func jobs_weakify<Owner: AnyObject>(
    _ owner: Owner,
    _ block: @escaping (Owner) -> Void
) -> () -> Void {
    { [weak owner] in
        guard let owner else { return }
        block(owner)
    }
}

@inlinable
public func jobs_weakify<Owner: AnyObject, Arg>(
    _ owner: Owner,
    _ block: @escaping (Owner, Arg) -> Void
) -> (Arg) -> Void {
    { [weak owner] arg in
        guard let owner else { return }
        block(owner, arg)
    }
}
// ✅ 有返回值（无参）→ 返回值可选
@inlinable
public func jobs_weakify<Owner: AnyObject, R>(
    _ owner: Owner,
    _ block: @escaping (Owner) -> R
) -> () -> R? {
    { [weak owner] in
        guard let owner else { return nil }
        return block(owner)
    }
}
// ✅ 有返回值（带参）→ 返回值可选
@inlinable
public func jobs_weakify<Owner: AnyObject, Arg, R>(
    _ owner: Owner,
    _ block: @escaping (Owner, Arg) -> R
) -> (Arg) -> R? {
    { [weak owner] arg in
        guard let owner else { return nil }
        return block(owner, arg)
    }
}
// ---- 可选：平替你原先“柯里化”签名的版本 ----
@inlinable
public func jobs_weakify<Owner: AnyObject, R>(
    _ owner: Owner,
    _ function: @escaping (Owner) -> () -> R
) -> () -> R? {
    { [weak owner] in
        guard let owner else { return nil }
        return function(owner)()
    }
}

@inlinable
public func jobs_weakify<Owner: AnyObject, Arg, R>(
    _ owner: Owner,
    _ function: @escaping (Owner) -> (Arg) -> R
) -> (Arg) -> R? {
    { [weak owner] arg in
        guard let owner else { return nil }
        return function(owner)(arg)
    }
}
// MARK: - Unowned
@inlinable
public func jobs_unownedify<Owner: AnyObject>(
    _ owner: Owner,
    _ block: @escaping (Owner) -> Void
) -> () -> Void {
    { [unowned owner] in
        block(owner)
    }
}

@inlinable
public func jobs_unownedify<Owner: AnyObject, Arg>(
    _ owner: Owner,
    _ block: @escaping (Owner, Arg) -> Void
) -> (Arg) -> Void {
    { [unowned owner] arg in
        block(owner, arg)
    }
}
// ✅ 有返回值（无参）
@inlinable
public func jobs_unownedify<Owner: AnyObject, R>(
    _ owner: Owner,
    _ block: @escaping (Owner) -> R
) -> () -> R {
    { [unowned owner] in
        block(owner)
    }
}
// ✅ 有返回值（带参）
@inlinable
public func jobs_unownedify<Owner: AnyObject, Arg, R>(
    _ owner: Owner,
    _ block: @escaping (Owner, Arg) -> R
) -> (Arg) -> R {
    { [unowned owner] arg in
        block(owner, arg)
    }
}
// ---- 柯里化 unowned 版（与上面 weakifyC 对齐）----
@inlinable
public func jobs_unownedify<Owner: AnyObject, R>(
    _ owner: Owner,
    _ function: @escaping (Owner) -> () -> R
) -> () -> R {
    { [unowned owner] in
        function(owner)()
    }
}

@inlinable
public func jobs_unownedify<Owner: AnyObject, Arg, R>(
    _ owner: Owner,
    _ function: @escaping (Owner) -> (Arg) -> R
) -> (Arg) -> R {
    { [unowned owner] arg in
        function(owner)(arg)
    }
}
