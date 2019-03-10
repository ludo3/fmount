// Written in the D programming language.

/**
Temporary files removed when leaving their scope.

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
module tempfile;

import std.array : array, join;
import std.conv : to;
import std.file : tempDir;
import std.path : buildNormalizedPath;
import std.random : choice, Random, rndGen, uniform;
import std.range: generate, take;
import std.string : format;
import std.traits;

import file : File;

/// Note: same default prefix as in Python implementation.
private enum DefaultPrefix = "tmp";

private enum string _characters =
    "abcdefghijklmnopqrstuvwxyz0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ";

private char genOneChar()
{
    enum min = size_t(0);
    enum max = _characters.length;
    return _characters[uniform(min, max, rndGen)];
}

// FIXME replace File and NamedTemporaryFile with a struct containing a File
// and a isTemporary property, removing file when reference count becomes zero.

/**
 * A named file which is deleted as soon as it is closed.
 *
 * This file is located in the temporary directory.
 */
class NamedTemporaryFile : File
{
    /**
    Constructor taking the name of the file to open and the open mode.

    Params:
        mode = The opening mode for the file.
        suffix = The suffix to be appended to the generated name.
        prefix = The prefix to be prepended to the generated name.

        If suffix is not empty, the file name will end with that suffix,
        otherwise there will be no suffix. If you need a dot-starting suffix,
        put it at the beginning of suffix.

        If prefix is not empty, the file name will begin with that prefix;
        otherwise, a default prefix is used.

    Throws: `ErrnoException` if the file could not be opened.

    See_Also:
        $(STDFILE).this
    */
    this(string prefix="",
         string suffix="",
         string mode="w+b",
         string dir="")
    {
        super(buildName(dir, prefix, suffix), mode);
    }

    /// ditto
    this(R1, R2, R3, R4)
        (R1 prefix, R2 suffix, R3 mode, R4 dir, bool deleteOnClose=true)
        if (isInputRange!R1 && isSomeChar!(ElementEncodingType!R1) &&
            isInputRange!R2 && isSomeChar!(ElementEncodingType!R2) &&
            isInputRange!R3 && isSomeChar!(ElementEncodingType!R3) &&
            isInputRange!R4 && isSomeChar!(ElementEncodingType!R4) &&
            is(Unqual!(ElementType!(ElementType!R2)) == Unqual!(ElementType!R1))
            &&
            is(Unqual!(ElementType!(ElementType!R3)) == Unqual!(ElementType!R1))
            &&
            is(Unqual!(ElementType!(ElementType!R4)) == Unqual!(ElementType!R1)))
    {
        super(buildName(suffix, prefix, dir), mode);
    }

    private:

        static string buildName(string dir, string prefix, string suffix)
        {
            if (dir is null || dir.length == 0)
                dir = tempDir();

            if (prefix is null)
                prefix = DefaultPrefix;

            if (suffix is null)
                suffix = "";

            // FIXME this does not compile on 2018/08/08.
            //auto base = choice(_characters[0..$], rndGen);
            auto base = generate!(() => genOneChar)().take(12).array;

            return buildNormalizedPath(dir, prefix ~ base ~ suffix);
        }

}
