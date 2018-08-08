// Written in the D programming language.

/**
Files with methods that can be overriden.

Copyright: Copyright Ludovic Dordet 2018.
License:   $(HTTP www.gnu.org/licenses/gpl-3.0.md,
             GNU GENERAL PUBLIC LICENSE 3.0).
Authors:   Ludovic Dordet

Macros:
  STDFILE = std.stdio.File
*/
/*
         Copyright Ludovic Dordet 2018.
Distributed under the GNU GENERAL PUBLIC LICENSE, Version 3.0.
   (See accompanying file LICENSE.md or copy at
         http://www.gnu.org/licenses/gpl-3.0.md)
*/
module file;

import std.array : join;
import io = std.stdio;
import std.range.primitives : ElementEncodingType, isInputRange;
import std.stdio : _IOFBF, LockType, SEEK_SET, writeln;
import std.string : format;
import std.traits;


/**
 * A `$(STDFILE)` - like object with methods which can be overriden.
 *
 */
class File
{
    /**
    Constructor taking the name of the file to open and the open mode.

    Params:
        name = range or string representing the file _name
        stdioOpenmode = range or string represting the open mode

    Throws: `ErrnoException` if the file could not be opened.

    See_Also:
        $(STDFILE).this
    */
    this(string name, scope const(char)[] stdioOpenmode = "rb")
    {
        this(io.File(name, stdioOpenmode));
    }

    /// ditto
    this(R1, R2)(R1 name)
        if (isInputRange!R1 && isSomeChar!(ElementEncodingType!R1))
    {
        this(io.File(name));
    }

    /// ditto
    this(R1, R2)(R1 name, R2 mode)
        if (isInputRange!R1 && isSomeChar!(ElementEncodingType!R1) &&
            isInputRange!R2 && isSomeChar!(ElementEncodingType!R2))
    {
        this(io.File(name, mode));
    }

    /**
     * Constructor with an `$(STDFILE)` implementation.
     */
    this(io.File impl)
    {
        _file = impl;
    }

    /**
     * Copy constructor. Please remind that the `$(STDFILE)` implements
     * reference counting on the underlying `FILE*` .
     */
    this(File other)
    {
        this(other.file);
    }

    /// Destructor forcing to dereference the implementation.
    ~this() @safe
    {
        detach();
        destroy(_file);
    }


    /**
    Assigns a file implementation to another.

    See_Also:
        $(STDFILE).opAssign
    */
    void opAssign(io.File rhs) @safe
    {
        _file.opAssign(rhs);
    }

   /**
    Detaches from the current file (throwing on failure), and then attempts to
    _open file `name` with mode `stdioOpenmode`.

    Throws: `ErrnoException` in case of error.

    See_Also:
        $(STDFILE).open
    */
    void open(string name, scope const(char)[] stdioOpenmode = "rb") @trusted
    {
        _file.open(name, stdioOpenmode);
    }

    /**
    Reuses the `File` object to either open a different file, or change
    the file mode.

    Throws: `ErrnoException` in case of error.

    See_Also:
        $(STDFILE).reopen
    */
    void reopen(string name, scope const(char)[] stdioOpenmode = "rb") @trusted
    {
        _file.reopen(name, stdioOpenmode);
    }

    /**
    Detaches from the current file (throwing on failure), and then runs a
    command.

    Throws: `ErrnoException` in case of error.

    See_Also:
        $(STDFILE).popen
    */
    version(Posix) void popen(string command,
                              scope const(char)[] stdioOpenmode = "r") @safe
    {
        _file.popen(command, stdioOpenmode);
    }

    /**
    First calls `detach` (throwing on failure), and then attempts to
    associate the given file descriptor with the `File`.

    Throws: `ErrnoException` in case of error.

    See_Also:
        $(STDFILE).fdopen
    */
    void fdopen(int fd, scope const(char)[] stdioOpenmode = "rb") @safe
    {
        _file.fdopen(fd, stdioOpenmode);
    }

    /** Returns `true` if the file is opened. */
    @property bool isOpen() const @safe pure nothrow
    {
        return _file.isOpen();
    }

    /**
    Returns `true` if the file is at end.

    Throws: `Exception` if the file is not opened.

    See_Also:
        $(STDFILE).eof
    */
    @property bool eof() const @trusted pure
    {
        return _file.eof();
    }

    /**
    Returns the name of the last opened file, if any.

    See_Also:
        $(STDFILE).name
    */
    @property string name() const @safe pure nothrow
    {
        return _file.name;
    }

    /// Retrieve the `$(STDFILE)` implementation.
    @property io.File file()
    {
        return _file;
    }

    /**
    If the file is not opened, returns `true`. Otherwise, returns
    $(HTTP cplusplus.com/reference/clibrary/cstdio/ferror.html, ferror) for
    the file handle.

    See_Also:
        $(STDFILE).error
    */
    @property bool error() const @trusted pure nothrow
    {
        return _file.error();
    }

    /**
    Detaches from the underlying file. If the sole owner, calls `close`.

    Throws: `ErrnoException` on failure if closing the file.

    See_Also:
        $(STDFILE).detach
    */
    void detach() @trusted
    {
        _file.detach();
    }

    /**
    If the file was unopened, succeeds vacuously. Otherwise closes the
    file.

    Throws: `ErrnoException` on error.

    See_Also:
        $(STDFILE).close
    */
    void close() @trusted
    {
        _file.close();
    }

    /**
    If the file is not opened, succeeds vacuously. Otherwise, returns
    $(HTTP cplusplus.com/reference/clibrary/cstdio/_clearerr.html,
    _clearerr) for the file handle.

    See_Also:
        $(STDFILE).clearerr
    */
    void clearerr() @safe pure nothrow
    {
        _file.clearerr();
    }

    /**
    Flushes the C `FILE` buffers.

    Throws: `Exception` if the file is not opened or if the call to `fflush`
            fails.

    See_Also:
        $(STDFILE).flush
    */
    void flush() @trusted
    {
        _file.flush();
    }

    /**
    Forces any data buffered by the OS to be written to disk.

    Throws: `Exception` if the file is not opened or if the OS call fails.

    See_Also:
        $(STDFILE).sync
    */
    void sync() @trusted
    {
        _file.sync();
    }

    /**
    Calls $(HTTP cplusplus.com/reference/clibrary/cstdio/fread.html, fread) for
    the file handle.

    Throws: `Exception` if `buffer` is empty.
            `ErrnoException` if the file is not opened or the call to `fread`
            fails.

    See_Also:
        $(STDFILE).rawRead
    */
    T[] rawRead(T)(T[] buffer)
    {
        return _file.rawRead(buffer);
    }

    /**
    Calls $(HTTP cplusplus.com/reference/clibrary/cstdio/fwrite.html, fwrite)
    for the file handle.

    Throws: `ErrnoException` if the file is not opened or if the call to `fwrite` fails.

    See_Also:
        $(STDFILE).rawWrite
    */
    void rawWrite(T)(in T[] buffer)
    {
        _file.rawWrite(buffer);
    }

    /**
    Calls $(HTTP cplusplus.com/reference/clibrary/cstdio/fseek.html, fseek)
    for the file handle.

    Throws: `Exception` if the file is not opened.
            `ErrnoException` if the call to `fseek` fails.

    See_Also:
        $(STDFILE).seek
    */
    void seek(long offset, int origin = SEEK_SET) @trusted
    {
        _file.seek(offset, origin);
    }

    /**
    Calls $(HTTP cplusplus.com/reference/clibrary/cstdio/ftell.html, ftell) for
    the managed file handle.

    Throws: `Exception` if the file is not opened.
            `ErrnoException` if the call to `ftell` fails.

    See_Also:
        $(STDFILE).tell
    */
    @property ulong tell() const @trusted
    {
        return _file.tell();
    }

    /**
    Calls $(HTTP cplusplus.com/reference/clibrary/cstdio/_rewind.html, _rewind)
    for the file handle.

    Throws: `Exception` if the file is not opened.

    See_Also:
        $(STDFILE).rewind
    */
    void rewind() @safe
    {
        _file.rewind();
    }

    /**
    Calls $(HTTP cplusplus.com/reference/clibrary/cstdio/_setvbuf.html,
    _setvbuf) for the file handle.

    Throws: `Exception` if the file is not opened.
            `ErrnoException` if the call to `setvbuf` fails.

    See_Also:
        $(STDFILE).setvbuf
    */
    void setvbuf(size_t size, int mode = _IOFBF) @trusted
    {
        _file.setvbuf(size, mode);
    }

    /**
    Calls $(HTTP cplusplus.com/reference/clibrary/cstdio/_setvbuf.html,
    _setvbuf) for the file handle.

    Throws: `Exception` if the file is not opened.
            `ErrnoException` if the call to `setvbuf` fails.

    See_Also:
        $(STDFILE).setvbuf
    */
    void setvbuf(void[] buf, int mode = _IOFBF) @trusted
    {
        _file.setvbuf(buf, mode);
    }

    /**
    Locks the specified file segment.

    See_Also:
        $(STDFILE).lock
    */
    void lock(LockType lockType = LockType.readWrite,
        ulong start = 0, ulong length = 0)
    {
        _file.lock(lockType, start, length);
    }

    /**
    Attempts to lock the specified file segment.

    See_Also:
        $(STDFILE).tryLock
    */
    bool tryLock(LockType lockType = LockType.readWrite,
        ulong start = 0, ulong length = 0)
    {
        return _file.tryLock(lockType, start, length);
    }

    /**
    Removes the lock over the specified file segment.

    See_Also:
        $(STDFILE).unlock
    */
    void unlock(ulong start = 0, ulong length = 0)
    {
        _file.unlock(start, length);
    }

    /**
    Writes its arguments in text format to the file.

    Throws: `Exception` if the file is not opened.
            `ErrnoException` on an error writing to the file.

    See_Also:
        $(STDFILE).write
    */
    void write(S...)(S args)
    {
        _file.write(args);
    }

    /**
    Writes its arguments in text format to the file, followed by a newline.

    Throws: `Exception` if the file is not opened.
            `ErrnoException` on an error writing to the file.

    See_Also:
        $(STDFILE).writeln
    */
    void writeln(S...)(S args)
    {
        _file.writeln(args);
    }

    /**
    Writes its arguments in text format to the file, according to the
    format string fmt.

    Throws: `Exception` if the file is not opened.
            `ErrnoException` on an error writing to the file.

    See_Also:
        $(STDFILE).writef
    */
    void writef(alias fmt, A...)(A args)
    if (isSomeString!(typeof(fmt)))
    {
        _file.writef!fmt(args);
    }

    /// ditto
    void writef(Char, A...)(in Char[] fmt, A args)
    {
        _file.writef(fmt, args);
    }

    /// Equivalent to `file.writef(fmt, args, '\n')`.
    void writefln(alias fmt, A...)(A args)
    if (isSomeString!(typeof(fmt)))
    {
        _file.writefln!fmt(args);
    }

    /// ditto
    void writefln(Char, A...)(in Char[] fmt, A args)
    {
        _file.writefln(fmt, args);
    }

    /**
    Read line from the file handle and return it as a specified type.

    Returns:
        The line that was read, including the line terminator character.

    Throws:
        `StdioException` on I/O error, or `UnicodeException` on Unicode
        conversion error.

    See_Also:
        $(STDFILE).readln
    */
    S readln(S = string)(dchar terminator = '\n')
    if (isSomeString!S)
    {
        return _file.readln!S(terminator);
    }

    /**
    Read line from the file handle and write it to `buf[]`, including
    terminating character.

    Throws: `StdioException` on I/O error, or `UnicodeException` on Unicode
    conversion error.

    See_Also:
        $(STDFILE).readln
    */
    size_t readln(C)(ref C[] buf, dchar terminator = '\n')
    if (isSomeChar!C && is(Unqual!C == C) && !is(C == enum))
    {
        return _file.readln(buf, terminator);
    }

    /// ditto
    size_t readln(C, R)(ref C[] buf, R terminator)
    if (isSomeChar!C && is(Unqual!C == C) && !is(C == enum) &&
        isBidirectionalRange!R && is(typeof(terminator.front == dchar.init)))
    {
        return _file.readln(buf, terminator);
    }

    /**
     * Reads formatted _data from the file using $(REF formattedRead, std,_format).
     *
     * See_Also:
     *  $(STDFILE).readf
     */uint readf(alias format, Data...)(auto ref Data data)
    if (isSomeString!(typeof(format)))
    {
        return _file.readf!format(data);
    }

    /// ditto
    uint readf(Data...)(scope const(char)[] format, auto ref Data data)
    {
        return _file.readf(format, data);
    }

    /**
     * Returns the file number corresponding to this object.
     */
    @property int fileno() const @trusted
    {
        return _file.fileno;
    }

    /**
    Returns an $(REF_ALTTEXT input range, isInputRange, std,range,primitives)
    set up to read from the file handle one line at a time.

    See_Also:
        $(STDFILE).byLine
    */
    auto byLine(Terminator = char, Char = char)
            (io.KeepTerminator keepTerminator = io.No.keepTerminator,
            Terminator terminator = '\n')
    if (isScalarType!Terminator)
    {
        return _file.byLine!(Terminator, Char)(keepTerminator, terminator);
    }

    /// ditto
    auto byLine(Terminator, Char = char)
            (io.KeepTerminator keepTerminator, Terminator terminator)
    if (is(Unqual!(ElementEncodingType!Terminator) == Char))
    {
        return _file.byLine!(Terminator, Char)(keepTerminator, terminator);
    }

    /**
    Returns an $(REF_ALTTEXT input range, isInputRange, std,range,primitives)
    set up to read from the file handle one line
    at a time.

    See_Also:
        $(STDFILE).byLineCopy
    */
    auto byLineCopy(Terminator = char, Char = immutable char)
            (io.KeepTerminator keepTerminator = io.No.keepTerminator,
            Terminator terminator = '\n')
    if (isScalarType!Terminator)
    {
        return _file.byLineCopy!(Terminator, Char)(keepTerminator, terminator);
    }

    /// ditto
    auto byLineCopy(Terminator, Char = immutable char)
            (KeepTerminator keepTerminator, Terminator terminator)
    if (is(Unqual!(ElementEncodingType!Terminator) == Unqual!Char))
    {
        return _file.byLineCopy!(KeepTerminator, Char)(keepTerminator,
                                                       terminator);
    }

    /**
    Returns an $(REF_ALTTEXT input range, isInputRange, std,range,primitives)
    set up to read from the file handle a chunk at a time.

    Throws: If the user-provided size is zero or the user-provided buffer
    is empty, throws an `Exception`. In case of an I/O error throws
    `StdioException`.

    See_Also:
        $(STDFILE).byChunk
    */
    auto byChunk(size_t chunkSize)
    {
        return _file.byChunk(chunkSize);
    }

    /// Ditto
    auto byChunk(ubyte[] buffer)
    {
        return _file.byChunk(buffer);
    }

    /**
     * Output range which locks the file when created, and unlocks the file when
     * it goes out of scope.
     *
     * Throws: $(REF UTFException, std, utf) if the data given is a `char` range
     * and it contains malformed UTF data.
     *
     * See_Also:
     *     $(STDFILE).lockingTextWriter
     */
    auto lockingTextWriter() @safe
    {
        return _file.lockingTextWriter();
    }

    /**
     * Returns an output range that locks the file and allows fast writing to
     * it.
     *
     * See_Also:
     *     $(STDFILE).lockingBinaryWriter
     */
    auto lockingBinaryWriter()
    {
        return _file.lockingBinaryWriter();
    }

    /**
     * Get the size of the file, ulong.max if file is not searchable, but still
     * throws if an actual error occurs.
     */
    @property ulong size() @safe
    {
        return _file.size;
    }

    private:
        /// The implementation from `std.stdio` .
        io.File _file;
}
