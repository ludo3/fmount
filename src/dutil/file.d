// Written in the D programming language.

/**
File related utilities.

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
module dutil.file;

import std.array : array, join;
import std.file : tempDir;
import std.path : buildNormalizedPath;
import std.random : rndGen, uniform;
import std.range: generate, take;
import std.stdio : File;
import std.traits : isSomeString;


/**
 * Retrieve the content of a file, if available, i.e. if opened in an append
 * mode.
 *
 * Params:
 *     nbLines = The number of last lines to retrieve. If zero, then the
 *               full content is retrieved.
 *     file    = The file from which the last lines should be retrieved.
 */
string getText(size_t nbLines=1)(File file)
{
    if (file.isOpen)
    {
        file.lock();
        scope(exit)
            file.unlock();

        immutable ulong pos = file.tell();
        file.rewind;

        scope(exit)
        {
            // make sure all read/write modes are correctly handled.
            file.rewind();
            file.seek(pos);
        }

        return file.byLineCopy()
                   .array()
                   .extract(nbLines)
                   .join("\n");
    }

    return "";
}


private S[] extract(S)(S[] data, size_t nb)
if (isSomeString!S)
{
    if (nb == 0 || nb >= data.length)
        return data;
    else
        return data[$-nb .. $];
}


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

/**
 * Encapsulates a temporary file and deletes it when it is not referenced any
 * more.
 *
 * Please note that when the last `MaybeTempFile` instance is destroyed , any
 * external reference to the encapsulated file becomes invalid if `isTemp` is
 * `true`.
 */
struct MaybeTempFile
{
    import std.file : remove;
    import std.typecons : RefCounted;
    alias Count = RefCounted!size_t;

    /**
    Constructor with naming prefix and suffix, and the open mode.

    Params:
        prefix = The prefix to be prepended to the generated name.
        suffix = The suffix to be appended to the generated name.
        mode = The opening mode for the file.

        If suffix is not empty, the file name will end with that suffix,
        otherwise there will be no suffix. If you need a dot-starting suffix,
        put it at the beginning of suffix.

        If prefix is not empty, the file name will begin with that prefix;
        otherwise, a default prefix is used.

    Throws: `ErrnoException` if the file could not be opened.

    See_Also:
        $(STDFILE).this
    */
    this(string prefix,
         string suffix="",
         string mode="w+b",
         string dir="")
    {
        this(File(buildName(dir, prefix, suffix), mode));
        _isTemp = true;
    }

    /// Constructor with an opened file, which is not considered temporary.
    this(File f)
    {
        attach(f);
    }

    /// Destructor
    ~this()
    {
        detach();
    }

    this(this)
    {
        refs += 1;
    }

    /// Detach from current file and attach to the new one.
    ref This opAssign(this This)(ref TempFile other)
    {
        opAssign(other.file);
        refs = other.refs;
        _isTemp = other.isTemp;
        return this;
    }

    /// Detach from current file and attach to the new one.
    private ref This opAssign(this This)(File f)
    {
        detach();
        attach(f);
        return this;
    }

    /// Retrieve the encapsulated file.
    @property ref File file() { return _file; }

    /// Use this object as if it were the encapsulated file.
    alias file this;

    /**
     * Check whether the encapsulated file will be removed when not referenced
     * any more.
     */
    @property bool isTemp() const { return _isTemp; }

private:
    File _file;
    Count _refs;
    bool _isTemp;

    @property ref Count refs() { return _refs; }

    void attach(File f)
    {
        this._file = f;
        this._refs = Count(1);
    }

    void detach()
    {
        if ((refs -= 1) == 0 && file != File.init && file.isOpen)
        {
            file.close;
            file.name.remove;
        }

        _isTemp = false;
    }

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
        auto base = generate!(() => genOneChar)().take(20).array;

        return buildNormalizedPath(dir, prefix ~ base ~ suffix);
    }

}


unittest
{
    // TODO test create a temporary file, check existing, check write, check read, check missing when out of scope
    // TODO test postblit, check existing when first out of scope, check missing when 2nd out of scope
    // TODO test opAssign(otherTempFile), same checks as for postblit
    // TODO test read from another file opening
    // TODO test using TempFile as a std.stdio.File .
}


