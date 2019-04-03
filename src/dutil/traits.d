// Written in the D programming language.

/**
Compile-time checks.

Copyright: Copyright Ludovic Dordet 2018.
License:   $(HTTP www.gnu.org/licenses/gpl-3.0.md,
             GNU GENERAL PUBLIC LICENSE 3.0).
Authors:   Ludovic Dordet
*/
/*
         Copyright Ludovic Dordet 2018.
Distributed under the GNU GENERAL PUBLIC LICENSE, Version 3.0.
   (See accompanying file LICENSE.md or copy at
         http://www.gnu.org/licenses/gpl-3.0.md)
*/
module dutil.traits;


/// Check whether type `T` is a structured type: struct, union or class.
template isStructured(T)
{
    enum bool isStructured =
        is(T == struct) ||
        is(T == union) ||
        is(T == class);
}


/**
   Check whether a structured type `T` has a field of type `F` named `name`.
 */
template hasTypedField(T, F, string name)
//FIXME fails with Tuple : why? ==> if (isStructured!T)
{
    import std.traits: Fields, FieldNameTuple, isAssignable;

    static assert(isStructured!T, T.stringof ~ " is not a structured type.");

    enum bool hasTypedField = {
        static foreach(i, ft; Fields!T)
        {
            if (FieldNameTuple!T[i] == name)
            {
                // Found field `name`
                return isAssignable!(F, ft);
            }
        }

        return false;
    }();
}


/**
   Check whether a structured type has the expected field types and names.

   Each field type is expected to be followed by its name.
 */
template hasTypedFields(T, TypedNames...)
{
    import std.format : _f=format;
    import std.meta : Stride;
    import std.traits: isExpressions, isSomeString, isTypeTuple;

    static assert(isTypeTuple!(Stride!(2, TypedNames)),
        _f!"Expected a list of types instead of '%s'.\nPlease check '%s'."
           (Stride!(2, TypedNames).stringof,
            Stride!(2, TypedNames).stringof));

    enum bool hasTypedFields = {
        bool htf = true;

        foreach (i, ft; Stride!(2, TypedNames))
        {
            static assert(is(ft),
                _f!"Expected a type instead of '%s'."(ft.stringof));

            static assert(isExpressions!(TypedNames[2*i+1])
                      && isSomeString!(typeof(TypedNames[2*i+1])),
                _f!"Expected a field name instead of '%s'."
                   (TypedNames[2*i+1].stringof));

            if (!(hasTypedField!(T, ft, TypedNames[2*i+1])))
            {
                htf = false;
                break;
            }
        }

        return htf;
    }();
}

/// `hasTypedFields`
unittest
{
    struct S
    {
        int i1;
        long L2;
        int[] arr;
    }

    class C
    {
        string len;
        size_t sz;
    }

    assert(hasTypedField!(S, int[], "arr"));
    assert(hasTypedFields!(S, long, "L2", int, "i1"));

    assert(hasTypedField!(C, string, "len"));
    assert(hasTypedFields!(C, string, "len", size_t, "sz"));
}


