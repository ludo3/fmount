// Written in the D programming language.

/**
User Interface.

This module contains user interface related code when interactivity is needed.

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
module ui;

import std.array : join;
import std.conv : text;
import std.exception : basicExceptionCtors;
import std.format : format, formattedWrite;
import std.range.primitives : ElementType, isInputRange, isOutputRange;
import std.stdio : stderr, stdout, writeln;
import std.string : fromStringz, toStringz;
import std.traits : isSomeChar, isSomeString;
import unistd = core.sys.linux.unistd;

import argsutil : VbLevel, verbose;
import constvals : With;
import dev : dev_descr, dev_display, is_encrypted;
import dutil : unused;
import mountargs : passphrase_file;
import tempfile : NamedTemporaryFile;

version(unittest)
{
    import std.file : deleteme;
}


private string _getpass(const string prompt)
{
    return text(fromStringz(unistd.getpass(toStringz(prompt)))).dup;
}


/**
 * Retrieve a password from the console.
 *
 * Params:
 *     reason  = A description of the need for a password.
 *     confirm = Whether the password should be entered twice (password
 *               creation).
 */
string getpass(string reason, bool confirm = false)
{
    immutable prompt1 = "Please enter password for %s: ";
    string pwd = _getpass(format!prompt1(reason));

    if (confirm)
    {
        immutable prompt2 = "Please confirm passwd for %s: ";
        immutable string chk = text(_getpass(format!prompt2(reason)));

        if (chk == pwd)
            return pwd;

        throw new PasswordException("Password confirmation mismatch");
    }

    if (pwd is null || pwd.length == 0)
        throw new PasswordException("Empty password");

    return pwd;
}


/**
 * An exception thrown when a password error occurs.
 */
class PasswordException : Exception
{
    mixin basicExceptionCtors;
}


/**
 * Retrieve a password from a file or through a console entry.
 *
 * Params:
 *     dev = The path to a device file.
 *     confirm_for_encryption = to be set to `true` when a password is being
 *                              created, i.e. when encrypting a device.
 *
 *
 *
 *
 *
 *
 * Returns:
 *     A `File` object, which is a `tempfile.NamedTemporaryFile` if the
 *     `passphrase_file` option is unset.
 *     If the password is not being created and the device is not encrypted then
 *     a `null` reference is returned.
 */
auto read_password(string dev,
                   bool confirm_for_encryption=false)
{
    import file : File;

    string descr = dev_descr(dev, dev_display(dev));

    if (confirm_for_encryption || is_encrypted(dev))
    {
        if (passphrase_file)
            return new File(passphrase_file, "r");
        else
        {
            auto pwf = new NamedTemporaryFile("fmount", "", "w+b");

                pwf.write(getpass(descr, confirm_for_encryption));
                pwf.flush();
                return pwf;
        }
    }
    else
        return null;
}


/**
 * Display one warning.
 *
 * Params:
 *   minVbLevel = The verbosity level for which the warning is requested.
 *                The message is shown only when `verbose` was set to that
 *                level.
 *   String     = A string type.
 *   message    = A message to be shown.
 */
void show_warnings(VbLevel minVbLevel, String)(String message)
if (isSomeString!String ||
    (isInputRange!String &&
     isSomeChar!(ElementType!String)))
{
    show_warnings(minVbLevel, [message]);
}

/**
 * Display one warning.
 *
 * Params:
 *   String     = A string type.
 *   minVbLevel = The verbosity level for which the warning is requested.
 *                The message is shown only when `verbose` was set to that
 *                level.
 *   message    = A message to be shown.
 */
void show_warnings(String)(VbLevel minVbLevel, String message)
if (isSomeString!String ||
    (isInputRange!String &&
     isSomeChar!(ElementType!String)))
{
    show_warnings(minVbLevel, [message]);
}


/**
 * Display one or more warning(s).
 *
 * Params:
 *   minVbLevel = The verbosity level for which the warning is requested.
 *                The message is shown only when `verbose` was set to that
 *                level.
 *   Strings    = An input range of strings.
 *   messages   = Some messages to be shown.
 */
void show_warnings(VbLevel minVbLevel, Strings)(Strings messages)
if (isInputRange!Strings &&
    (isInputRange!(ElementType!Strings) &&
     isSomeChar!(ElementType!(ElementType!Strings))))
{
    show_warnings(minVbLevel, messages);
}

/**
 * Display one or more warning(s).
 *
 * Params:
 *   Strings    = An input range of strings.
 *   minVbLevel = The verbosity level for which the warning is requested.
 *                The message is shown only when `verbose` was set to that
 *                level.
 *   messages   = Some messages to be shown.
 */
void show_warnings(Strings)(VbLevel minVbLevel, Strings messages)
if (isInputRange!Strings &&
    (isInputRange!(ElementType!Strings) &&
     isSomeChar!(ElementType!(ElementType!Strings))))
{
    if (verbose >= minVbLevel)
        warn(messages.join("\n"));
}


private template vbPrefix(VbLevel vb)
{
    enum vbPrefix = "";
}

private template vbPrefix(VbLevel vb : VbLevel.None)
{
    enum vbPrefix = "Error: ";
}

private template vbPrefix(VbLevel vb : VbLevel.Info)
{
    enum vbPrefix = "";
}

private template vbPrefix(VbLevel vb : VbLevel.Warn)
{
    enum vbPrefix = "Warning: ";
}

private template vbPrefix(VbLevel vb : VbLevel.More)
{
    enum vbPrefix = "Trace: ";
}

private template vbPrefix(VbLevel vb : VbLevel.Dbug)
{
    enum vbPrefix = "Debug: ";
}


/// Enable (`WithPrefix.Yes` or disable (`WithPrefix.No`) `vl` prefixes.
alias WithPrefix = With!"Prefix";

/// Shorthand for `isOutputRange!(T, char)` .
enum bool isOutRChar(T) = isOutputRange!(T, char);

/**
   This template provides the output functions with the `VbLevel` encoded in the
   function name.

   For further information see the the two vbImpl functions defined inside.

   The aliases following this template create the public names of these output
   functions.
*/
template vbFuns(VbLevel vl)
{
    import std.stdio : File;

    static if (vl == VbLevel.Info)
        alias dfltOut = stdout;
    else
        alias dfltOut = stderr;


    /**
       This function outputs data to the standard error, or to the standard
       output for the `info` level, if the `verbose` program argument is at
       least `vl`.

       Params:
         prefix = `WithPrefix.No` if the `vl` prefix must be disabled.
         A      = The argument types.
         output = The file to which the data are written.
         args   = The data that should be logged.

       Example:
       --------------------
       error(486, "is an integer number");
       warn(486, "is an integer number");
       info(486, "is an integer number");
       trace(486, "is an integer number");
       dbug(486, "is an integer number");
       --------------------
    */
    void vbImpl(WithPrefix prefix=WithPrefix.Yes,
                string file=__FILE__, size_t line=__LINE__,
                A...)
               (File output, lazy A args)
    if (args.length > 0 && !is(A[0] == bool))
    {
        if (verbose >= vl)
        {
            auto writer = output.lockingTextWriter();
            alias W = typeof(writer);
            // FIXME should be possible to remove need for typeof(writer)
            doVbImplw!(W, prefix, A)(file, line, writer, args);
        }
    }

    /// Ditto
    void vbImpl(WithPrefix prefix=WithPrefix.Yes,
                string file=__FILE__, size_t line=__LINE__,
                A...)(lazy A args)
    if (args.length > 0 && !is(A[0] == bool) && !is(A[0] == File) &&
        !isOutRChar!(A[0]))
    {
        if (verbose >= vl)
        {
            auto writer = dfltOut.lockingTextWriter();
            alias W = typeof(writer);
            // FIXME should be possible to remove need for typeof(writer)
            doVbImplw!(W, prefix, A)(file, line, writer, args);
        }
    }

    /**
       This function outputs data to an output range, if the `verbose`
       program argument is at least `vl`.

       Params:
         W         = The type of the output range receiving the data.
         prefix = `WithPrefix.No` if the `vl` prefix must be disabled.
         A      = The argument types.
         writer    = The output range receiving the data.
         args   = The data that should be logged.

       Example:
       --------------------
       error(486, "is an integer number");
       warn(486, "is an integer number");
       info(486, "is an integer number");
       trace(486, "is an integer number");
       dbug(486, "is an integer number");
       --------------------
    */
    void vbImplw(W,
                 WithPrefix prefix=WithPrefix.Yes,
                 string file=__FILE__, size_t line=__LINE__,
                 A...)
                (W writer, lazy A args)
    if ((args.length == 0 || (args.length > 0 && !is(A[0] == bool))) &&
        isOutRChar!W)
    {
        if (verbose >= vl)
            doVbImplw!(W, prefix, A)(file, line, writer, args);
    }

    // No verbose test, done before calling this function.
    private void doVbImplw(W, WithPrefix prefix, A...)
                          (string file, size_t line, W writer, lazy A args)
    if (args.length > 0 && !is(A[0] == bool) && isOutRChar!W)
    {
        static if (vl == VbLevel.Dbug)
            formattedWrite!"%s(%d): "(writer, file, line);

        doVbImplw!(W, prefix, A)(writer, args);
    }


    // No verbose test, done before calling this function.
    private void doVbImplw(W, WithPrefix prefix, A...)
                          (W writer, lazy A args)
    if (args.length > 0 && !is(A[0] == bool) && isOutRChar!W)
    {
        if (prefix == WithPrefix.Yes)
            formattedWrite!"%s"(writer, vbPrefix!vl);

        static foreach(arg; args)
            formattedWrite!"%s"(writer, arg);

        writer.put('\n');
    }


    /**
       This function outputs data to the standard error, or to the standard
       output for the `info` level, if the `verbose` program argument is at
       least `vl`, and if the additional condition is `true`.

       Params:
         prefix    = `WithPrefix.No` if the `vl` prefix must be disabled.
         A         = The argument types.
         output    = The file to which the data are written.
         condition = The condition must be `true` for the data to be written.
         args      = The data that should be logged.

       Example:
       --------------------
       error(true, 486, "is an integer number");
       warn(true, 789, "is an integer number");
       info(false, 123, "is an integer number");
       trace(false, 543, "is an integer number");
       dbug(false, 876, "is an integer number");
       --------------------
    */
    void vbImpl(WithPrefix prefix=WithPrefix.Yes,
                string file=__FILE__, size_t line=__LINE__,
                A...)
               (File output, lazy bool condition, lazy A args)
    {
        if (verbose >= vl && condition)
        {
            auto writer = output.lockingTextWriter();
            alias W = typeof(writer);
            // FIXME should be possible to remove need for typeof(writer)
            doVbImplw!(W, prefix, A)(file, line, writer, args);
        }
    }

    /// Ditto
    void vbImpl(WithPrefix prefix=WithPrefix.Yes,
                string file=__FILE__, size_t line=__LINE__,
                A...)
               (lazy bool condition, lazy A args)
    {
        if (verbose >= vl && condition)
        {
            auto writer = dfltOut.lockingTextWriter();
            alias W = typeof(writer);
            doVbImplw!(W, prefix, A)(file, line, writer, args);
        }
    }

    /**
       This function outputs data to an output range, if the `verbose`
       program argument is at least `vl`, and if the additional condition is
       `true`.

       Params:
         W         = The type of the output range receiving the data.
         prefix    = `WithPrefix.No` if the `vl` prefix must be disabled.
         A         = The argument types.
         writer    = The output range receiving the data.
         condition = The condition must be `true` for the data to be written.
         args      = The data that should be logged.

       Example:
       --------------------
       error(486, "is an integer number");
       warn(486, "is an integer number");
       info(486, "is an integer number");
       trace(486, "is an integer number");
       dbug(486, "is an integer number");
       --------------------
    */
    void vbImplw(W, WithPrefix prefix=WithPrefix.Yes,
                 string file=__FILE__, size_t line=__LINE__,
                 A...)
                (W writer, lazy bool condition, lazy A args)
    if ((args.length == 0 || (args.length > 0 && !is(A[0] == bool))) &&
        isOutRChar!W)
    {
        if (verbose >= vl && condition)
            doVbImplw!(W, prefix, A)(file, line, writer, args);
    }

    /**
       This function dumps the stack trace of a caught throwable object to the
       standard error, or to the standard output for the `info` level, if the
       `verbose` program argument is at least `vl`.

       Params:
         prefix    = `WithPrefix.No` if the `vl` prefix must be disabled.
         A         = The argument types.
         output    = The file to which the data are written.
         throwable = The caught throwable to be dumped.

       Example:
       --------------------
       errorStack(theException);
       warnStack(theException);
       infoStack(theException);
       traceStack(theException);
       dbugStack(theException);
       --------------------
    */
    void vbStack(WithPrefix prefix=WithPrefix.Yes)
                (File output, Throwable throwable)
    {
        if (verbose >= vl)
        {
            auto writer = output.lockingTextWriter();
            alias W = typeof(writer);
            vbStackw!(W, prefix)(writer, throwable);
        }
    }

    /// Ditto
    void vbStack(WithPrefix prefix=WithPrefix.Yes)(Throwable throwable)
    {
        if (verbose >= vl)
        {
            auto writer = dfltOut.lockingTextWriter();
            alias W = typeof(writer);
            vbStackw!(W, prefix)(writer, throwable);
        }
    }

    /**
       This function dumps the stack trace of a caught throwable object to an
       output range, if the `verbose` program argument is at least `vl`.

       Params:
         prefix    = `WithPrefix.No` if the `vl` prefix must be disabled.
         writer    = The output range receiving the data.
         throwable = The caught throwable to be dumped.

       Example:
       --------------------
       errorStackw(myFile.lockingTextWriter(), theException);
       warnStackw(myFile.lockingTextWriter(), theException);
       infoStackw(myFile.lockingTextWriter(), theException);
       traceStackw(myFile.lockingTextWriter(), theException);
       dbugStackw(myFile.lockingTextWriter(), theException);
       --------------------
    */
    void vbStackw(W, WithPrefix prefix=WithPrefix.Yes)
                 (W writer, ref Throwable throwable)
    {
        if (verbose >= vl)
        {
            // Note https://tour.dlang.org/tour/en/gems/opdispatch-opapply
            foreach(Throwable inChain; throwable)
                doVbImplw!(W, prefix, Throwable)(writer, inChain);
        }
    }

    /**
       This function outputs data in a `printf`-style manner.

       The data are put to the standard error, or to the standard
       output for the `info` level, if the `verbose` program argument is at
       least `vl`.

       Params:
         prefix = `WithPrefix.No` if the `vl` prefix must be disabled.
         A      = The argument types.
         msg    = The data format.
         output = The file to which the data are written.
         args   = The data that should be logged.

       Example:
       --------------------
       errorf("%d is an integer number", 486);
       warnf("%d is an integer number", 789);
       infof("%d is an integer number", 123);
       tracef("%d is an integer number", 543);
       dbugf("%d is an integer number", 876);
       --------------------
    */
    void vbImplf(WithPrefix prefix=WithPrefix.Yes,
                 string file=__FILE__, size_t line=__LINE__,
                 A...)
                (lazy string msg, File output, lazy A args)
    {
        if (verbose >= vl)
        {
            auto writer = output.lockingTextWriter();
            alias W = typeof(writer);
            doVbImplwf!(W, prefix, A)(file, line, msg, writer, args);
        }
    }

    /// Ditto
    void vbImplf(WithPrefix prefix=WithPrefix.Yes,
                 string file=__FILE__, size_t line=__LINE__,
                 A...)
                (lazy string msg, lazy A args)
    if (A.length > 0 && !is(A[0] == File) && !is(A[0] == bool))
    {
        if (verbose >= vl)
        {
            auto writer = dfltOut.lockingTextWriter();
            alias W = typeof(writer);
            doVbImplwf!(W, prefix, A)(file, line, msg, writer, args);
        }
    }


    /**
       This function outputs data in a `printf`-style manner to an output
       writer, if the `verbose` program argument is at least `vl`.

       Params:
         W         = The type of the output range receiving the data.
         prefix = `WithPrefix.No` if the `vl` prefix must be disabled.
         A      = The argument types.
         msg    = The data format.
         writer    = The output range receiving the data.
         args   = The data that should be logged.

       Example:
       --------------------
       error(486, "is an integer number");
       warn(486, "is an integer number");
       info(486, "is an integer number");
       trace(486, "is an integer number");
       dbug(486, "is an integer number");
       --------------------
    */
    void vbImplwf(W, WithPrefix prefix=WithPrefix.Yes,
                  string file=__FILE__, size_t line=__LINE__,
                  A...)
                 (lazy string msg, W writer, lazy A args)
    if ((args.length == 0 || (args.length > 0 && !is(A[0] == bool))) &&
        isOutRChar!W && !is(W == typeof(dfltOut)))
    {
        if (verbose >= vl)
            doVbImplwf!(W, prefix, A)(file, line, msg, writer, args);
    }

    // No verbose test, done before calling this function.
    private void doVbImplwf(W, WithPrefix prefix, A...)
                           (lazy string file, lazy size_t line,
                            lazy string msg, W writer, lazy A args)
    if ((args.length == 0 || (args.length > 0 && !is(A[0] == bool))) &&
        isOutRChar!W && !is(W == typeof(dfltOut)))
    {
        static if (vl == VbLevel.Dbug)
            formattedWrite!"%s(%d): "(writer, file, line);

        if (prefix == WithPrefix.Yes)
            formattedWrite!"%s"(writer, vbPrefix!vl);

        formattedWrite(writer, msg, args);
        writer.put('\n');
    }


    /**
       This function outputs data in a `printf`-style manner.

       The data are put to the standard error, or to the standard
       output for the `info` level, if the `verbose` program argument is at
       least `vl`, and if the additional condition is `true`.

       Params:
         prefix = `WithPrefix.No` if the `vl` prefix must be disabled.
         A    = The argument types.
         condition = The condition must be `true` for the data to be written.
         msg    = The data format.
         output = The file to which the data are written.
         args   = The data that should be logged.

       Example:
       --------------------
       errorf(true, "%d is an integer number", 486);
       warnf(true, "%d is an integer number", 789);
       infof(false, "%d is an integer number", 123);
       tracef(false, "%d is an integer number", 543);
       dbugf(false, "%d is an integer number", 876);
       --------------------
    */
    void vbImplf(WithPrefix prefix=WithPrefix.Yes,
                 string file=__FILE__, size_t line=__LINE__,
                 A...)
                (lazy bool condition, lazy string msg, File output, lazy A args)
    {
        if (verbose >= vl && condition)
        {
            auto writer = output.lockingTextWriter();
            alias W = typeof(writer);
            doVbImplwf!(W, prefix, A)(file, line, msg, writer, args);
        }
    }

    /// Ditto
    void vbImplf(WithPrefix prefix=WithPrefix.Yes,
                 string file=__FILE__, size_t line=__LINE__,
                 A...)
                (lazy bool condition, lazy string msg, lazy A args)
    if (A.length > 0 && !is(A[0] == File))
    {
        if (verbose >= vl && condition)
        {
            auto writer = dfltOut.lockingTextWriter();
            alias W = typeof(writer);
            doVbImplwf!(W, prefix, A)(file, line, msg, writer, args);
        }
    }

    /**
       This function outputs data in a `printf`-style manner to an output
       writer, if the `verbose` program argument is at least `vl`, and if
       the additional condition is `true`.

       Params:
         W         = The type of the output range receiving the data.
         prefix    = `WithPrefix.No` if the `vl` prefix must be disabled.
         A         = The argument types.
         condition = The condition must be `true` for the data to be written.
         msg       = The data format.
         writer    = The output range receiving the data.
         args      = The data that should be logged.

       Example:
       --------------------
       error(486, "is an integer number");
       warn(486, "is an integer number");
       info(486, "is an integer number");
       trace(486, "is an integer number");
       dbug(486, "is an integer number");
       --------------------
    */
    void vbImplwf(W, WithPrefix prefix=WithPrefix.Yes,
                  string file=__FILE__, size_t line=__LINE__,
                  A...)
                 (lazy bool condition, lazy string msg, W writer, lazy A args)
    if ((args.length == 0 || (args.length > 0 && !is(A[0] == bool))) &&
        isOutRChar!W && !is(W == typeof(dfltOut)))
    {
        if (verbose >= vl && condition)
            doVbImplwf!(W, prefix, A)(file, line, msg, writer, args);
    }
}

/// Ditto
alias dbug = vbFuns!(VbLevel.Dbug).vbImpl;
/// Ditto
alias dbugf = vbFuns!(VbLevel.Dbug).vbImplf;
/// Ditto
alias trace = vbFuns!(VbLevel.More).vbImpl;
/// Ditto
alias tracef = vbFuns!(VbLevel.More).vbImplf;
/// Ditto
alias info_ = vbFuns!(VbLevel.Info).vbImpl;
/// Ditto
alias infof = vbFuns!(VbLevel.Info).vbImplf;
/// Ditto
alias warn = vbFuns!(VbLevel.Warn).vbImpl;
/// Ditto
alias warnf = vbFuns!(VbLevel.Warn).vbImplf;
/// Ditto
alias error = vbFuns!(VbLevel.None).vbImpl;
/// Ditto
alias errorf = vbFuns!(VbLevel.None).vbImplf;

/// Ditto
alias dbugw = vbFuns!(VbLevel.Dbug).vbImplw;
/// Ditto
alias dbugwf = vbFuns!(VbLevel.Dbug).vbImplwf;
/// Ditto
alias tracew = vbFuns!(VbLevel.More).vbImplw;
/// Ditto
alias tracewf = vbFuns!(VbLevel.More).vbImplwf;
/// Ditto
alias infow = vbFuns!(VbLevel.Info).vbImplw;
/// Ditto
alias infowf = vbFuns!(VbLevel.Info).vbImplwf;
/// Ditto
alias warnw = vbFuns!(VbLevel.Warn).vbImplw;
/// Ditto
alias warnwf = vbFuns!(VbLevel.Warn).vbImplwf;
/// Ditto
alias errorw = vbFuns!(VbLevel.None).vbImplw;
/// Ditto
alias errorwf = vbFuns!(VbLevel.None).vbImplwf;

// Stack trace aliases
/// Ditto
alias dbugStack = vbFuns!(VbLevel.Dbug).vbStack;
/// Ditto
alias traceStack = vbFuns!(VbLevel.More).vbStack;
/// Ditto
alias infoStack = vbFuns!(VbLevel.Info).vbStack;
/// Ditto
alias warnStack = vbFuns!(VbLevel.Warn).vbStack;
/// Ditto
alias errorStack = vbFuns!(VbLevel.None).vbStack;
/// Ditto
alias dbugStackw = vbFuns!(VbLevel.Dbug).vbStackw;
/// Ditto
alias traceStackw = vbFuns!(VbLevel.More).vbStackw;
/// Ditto
alias infoStackw = vbFuns!(VbLevel.Info).vbStackw;
/// Ditto
alias warnStackw = vbFuns!(VbLevel.Warn).vbStackw;
/// Ditto
alias errorStackw = vbFuns!(VbLevel.None).vbStackw;

// TODO unittest for vbStack and vbStackw aliases

version(unittest)
{
    import std.conv : to;

    /// Structured type for tests.
    struct StrAndInt
    {
        string str;
        int i;
        string toString() const { return str ~ to!string(i); }
    }
}

/// error unittest
unittest
{
    import std.stdio : File;
    import dutil : bkv, unused;
    import fileutil : getText;
    import osutil : removeIfExists;

    auto stderr0 = bkv(stderr);
    unused(stderr0);
    stderr = File(deleteme ~ ".stderr." ~ __FUNCTION__, "a+");
    scope(exit) removeIfExists(stderr.name);
    File f = File(deleteme ~ ".file." ~ __FUNCTION__, "a+");
    scope(exit) removeIfExists(f.name);

    error!(WithPrefix.Yes)(f, "msg1.0, ", "msg2, ", 3);
    assert(f.getText() == "Error: msg1.0, msg2, 3",
           "getText() == " ~ f.getText());

    error!(WithPrefix.No)(f, "msg1.1, ", "msg2, ", 3);
    assert(f.getText() == "msg1.1, msg2, 3",
           "getText() == " ~ f.getText());

    error("msg1.2, ", "msg2, ", 3);
    assert(stderr.getText() == "Error: msg1.2, msg2, 3",
           "getText() == " ~ stderr.getText());

    error!(WithPrefix.Yes)("msg1.3, ", "msg2, ", 3);
    assert(stderr.getText() == "Error: msg1.3, msg2, 3",
           "getText() == " ~ stderr.getText());

    error!(WithPrefix.Yes)("msg1.4, ", "msg2, ", 3);
    assert(stderr.getText() == "Error: msg1.4, msg2, 3",
           "getText() == " ~ stderr.getText());

    error!(WithPrefix.Yes)(f, false, "msg1.5, ", "msg2, ", 3);
    // previous message msg1.1 is expected.
    assert(f.getText() == "msg1.1, msg2, 3",
           "getText() == " ~ f.getText());

    error!(WithPrefix.Yes)(f, true, "msg1.5, ", "msg2, ", 3);
    // new message msg1.5 is expected.
    assert(f.getText() == "Error: msg1.5, msg2, 3",
           "getText() == " ~ f.getText());

    error!(WithPrefix.No)(f, false, "msg1.6, ", "msg2, ", 3);
    // previous message msg1.5 is expected.
    assert(f.getText() == "Error: msg1.5, msg2, 3",
           "getText() == " ~ f.getText());

    error!(WithPrefix.No)(f, true, "msg1.6, ", "msg2, ", 3);
    // new message msg1.6 is expected.
    assert(f.getText() == "msg1.6, msg2, 3",
           "getText() == " ~ f.getText());

    error(false, "msg1.7, ", "msg2, ", 3);
    // previous message msg1.4 is expected.
    assert(stderr.getText() == "Error: msg1.4, msg2, 3",
           "getText() == " ~ stderr.getText());

    error(true, "msg1.7, ", "msg2, ", 3);
    // new message msg1.7 is expected.
    assert(stderr.getText() == "Error: msg1.7, msg2, 3",
           "getText() == " ~ stderr.getText());
}


/// errorf unittest
unittest
{
    import std.stdio : File;
    import dutil : bkv, unused;
    import fileutil : getText;
    import osutil : removeIfExists;

    auto stderr0 = bkv(stderr);
    unused(stderr0);
    stderr = File(deleteme ~ ".stderr." ~ __FUNCTION__, "a+");
    scope(exit) removeIfExists(stderr.name);
    File f = File(deleteme ~ ".file." ~ __FUNCTION__, "a+");
    scope(exit) removeIfExists(f.name);

    errorf!(WithPrefix.Yes)("%s, %s: %d", f, "msg1.0", "msg2", 3);
    assert(f.getText() == "Error: msg1.0, msg2: 3",
           "getText() == " ~ f.getText());

    errorf!(WithPrefix.No)("%s; %s | %d", f, "msg1.1", "msg2", 3);
    assert(f.getText() == "msg1.1; msg2 | 3",
           "getText() == " ~ f.getText());

    errorf("%s. %s -%d", f, "msg1.2", "msg2", 3);
    assert(f.getText() == "Error: msg1.2. msg2 -3",
           "getText() == " ~ f.getText());

    errorf!(WithPrefix.Yes)("%s_%s+%d", f, "msg1.3", "msg2", 3);
    assert(f.getText() == "Error: msg1.3_msg2+3",
           "getText() == " ~ f.getText());

    errorf!(WithPrefix.Yes)("%s * %s ^ %d", "msg1.4", "msg2", 3);
    assert(stderr.getText() == "Error: msg1.4 * msg2 ^ 3",
           "getText() == " ~ stderr.getText());

    errorf!(WithPrefix.Yes)(false, "%s~%s..%d...", f, "msg1.5", "msg2", 3);
    // previous message msg1.3 is expected.
    assert(f.getText() == "Error: msg1.3_msg2+3",
           "getText() == " ~ f.getText());

    errorf!(WithPrefix.Yes)(true, "%s~%s..%d ...", f, "msg1.5", "msg2", 3);
    // new message msg1.5 is expected.
    assert(f.getText() == "Error: msg1.5~msg2..3 ...",
           "getText() == " ~ f.getText());

    errorf!(WithPrefix.No)(false, "%s = %s + %d", f, "msg1.6", "msg2", 3);
    // previous message msg1.5 is expected.
    assert(f.getText() == "Error: msg1.5~msg2..3 ...",
           "getText() == " ~ f.getText());

    errorf!(WithPrefix.No)(true, "%s = %s + %d", f, "msg1.6", "msg2", 3);
    // new message msg1.6 is expected.
    assert(f.getText() == "msg1.6 = msg2 + 3",
           "getText() == " ~ f.getText());

    errorf(false, "[%s] %s(%d)", "msg1.7", "msg2", 3);
    // previous message msg1.4 is expected.
    assert(stderr.getText() == "Error: msg1.4 * msg2 ^ 3",
           "getText() == " ~ stderr.getText());

    errorf(true, "[%s] %s(%d)", "msg1.7", "msg2", 3);
    // new message msg1.7 is expected.
    assert(stderr.getText() == "Error: [msg1.7] msg2(3)",
           "getText() == " ~ stderr.getText());
}


/// errorw unittest
unittest
{
    import std.stdio : File;
    import fileutil : getText;
    import osutil : removeIfExists;

    File f = File(deleteme ~ ".stderr." ~ __FUNCTION__, "a+");
    scope(exit)
        removeIfExists(f.name);
    auto w = f.lockingTextWriter();

    errorw!(typeof(w), WithPrefix.Yes)(w, "one arg");
    assert(f.getText() == "Error: one arg", "getText() == " ~ f.getText());

    errorw!(typeof(w), WithPrefix.Yes)(w,
                                       "two args(1), ",
                                       2);
    assert(f.getText() == "Error: two args(1), 2",
           "getText() == " ~ f.getText());

    errorw!(typeof(w), WithPrefix.Yes)(w, 3, " args(2) |", 3);
    assert(f.getText() == "Error: 3 args(2) |3",
           "getText() == " ~ f.getText());

    errorw!(typeof(w), WithPrefix.Yes)(w, "Four args(1);", 2, "; 3, ",
                                       StrAndInt("Four=", 4));
    assert(f.getText() == "Error: Four args(1);2; 3, Four=4",
           "getText() == " ~ f.getText());

    errorw(w, false, "condition: ", 3, " args.");
    // Note: previous message Four args(1) expected.
    assert(f.getText() == "Error: Four args(1);2; 3, Four=4",
           "getText() == " ~ f.getText());

    errorw(w, true, "condition: ", 3, " args.");
    // Note: new message 3 args expected.
    assert(f.getText() == "Error: condition: 3 args.",
           "getText() == " ~ f.getText());

    errorw!(typeof(w), WithPrefix.No)
           (w, false, "condition: Four args(", 2, "); ", 3,
            StrAndInt(", Four=", 4));
    // Note: previous message 3 args expected.
    assert(f.getText() == "Error: condition: 3 args.",
           "getText() == " ~ f.getText());

    errorw!(typeof(w), WithPrefix.No)
           (w, true, "condition: Four args(", 2, "); ", 3,
            StrAndInt(", Four=", 4));
    // Note: new message Four args expected.
    assert(f.getText() == "condition: Four args(2); 3, Four=4",
           "getText() == " ~ f.getText());
}


/// errorwf unittest
unittest
{
    import std.stdio : File;
    import dutil : bkv, unused;
    import fileutil : getText;
    import osutil : removeIfExists;

    auto f = File(deleteme ~ ".stderr." ~ __FUNCTION__, "a+");
    auto w = f.lockingTextWriter();

    errorwf!(typeof(w), WithPrefix.Yes)("one(%d) arg", w, 1);
    assert(f.getText() == "Error: one(1) arg", "getText() == " ~ f.getText());

    errorwf!(typeof(w), WithPrefix.No)("A second (%dnd) arg", w, 2);
    assert(f.getText() == "A second (2nd) arg", "getText() == " ~ f.getText());

    errorwf("A third(%drd) arg", w, 3);
    assert(f.getText() == "Error: A third(3rd) arg",
           "getText() == " ~ f.getText());

    errorwf!(typeof(w), WithPrefix.Yes)("(%dst) two args(%d)", w, 1, 2);
    assert(f.getText() == "Error: (1st) two args(2)",
           "getText() == " ~ f.getText());

    errorwf!(typeof(w), WithPrefix.No)("(%dnd) two args(%d)", w, 2, 2);
    assert(f.getText() == "(2nd) two args(2)",
           "getText() == " ~ f.getText());

    errorwf("(%drd) two args(%d)", w, 3, 2);
    assert(f.getText() == "Error: (3rd) two args(2)",
           "getText() == " ~ f.getText());

    errorwf(false, "condition %d args(%d) => %d", w, 3, 2, 3);
    // Note: previous message 3rd two args expected.
    assert(f.getText() == "Error: (3rd) two args(2)",
           "getText() == " ~ f.getText());

    errorwf(true, "condition %d args(%d) => %d", w, 3, 2, 3);
    // Note: new message 3 args expected.
    assert(f.getText() == "Error: condition 3 args(2) => 3",
           "getText() == " ~ f.getText());

    errorwf(false, "condition %s args(%d);%d; %s, %s", w,
            "Four", 2, "3", StrAndInt("Four=", 4));
    // Note: previous message 3 args expected.
    assert(f.getText() == "Error: condition 3 args(2) => 3",
           "getText() == " ~ f.getText());

    errorwf!(typeof(w), WithPrefix.No)
            (true, "condition Four args(%d);%d; %s, %s", w,
             1, 2, "3", StrAndInt("Four=", 4));
    // Note: new message Four args expected.
    assert(f.getText() == "condition Four args(1);2; 3, Four=4",
           "getText() == " ~ f.getText());
}

