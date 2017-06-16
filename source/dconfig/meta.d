module dconfig.meta;

import std.meta;
import std.traits;


enum IgnoreAttr;
alias ignore = IgnoreAttr;

template settableMembers(T) {
    alias settableMembers = filterSettables!(
            T, __traits(allMembers, T));
}

template filterSettables(T, M...) {
    static if (M.length == 0)
        alias filterSettables = AliasSeq!();
    else 
    {
        static if (isSettable!(T, M[0]))
        {
            alias filterSettables = AliasSeq!( 
                    M[0], 
                    filterSettables!(T, M[1..$])
            );
        }
        else
            alias filterSettables = filterSettables!(T, M[1..$]);
    }
}

template isSettable(T, string M) {


    static if (is(AliasSeq!(__traits(getMember, T, M))))
        enum isSettable = false;
    else static if (!is(typeof(__traits(getMember, T, M))))
        enum isSettable = false;
    else static if (isFunction!(__traits(getMember, T, M)))
        enum isSettable = false;
    else static if (hasUDA!(mixin("T." ~ M), IgnoreAttr))
        enum isSettable = false;
    else static if (M[0] == '_')
        enum isSettable = false;
    else
        enum isSettable = true;

    // TODO
}

unittest {
    struct S {
        int x;
        int y;
        struct R { }
        void f() { }
        //alias z = x;
    }

    assert( isSettable!(S, "x") );
    assert( isSettable!(S, "y") );
    assert(!isSettable!(S, "R") );
    assert(!isSettable!(S, "f") );
    // TODO
    //assert( isSettable!(S, "z") );

    alias mems = settableMembers!S;
    assert(AliasSeq!("x", "y") == mems);
}
