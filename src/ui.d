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
import std.format : format;
import std.range.primitives : ElementType, isInputRange;
import std.stdio : stderr, stdout, writeln;
import std.string : fromStringz, toStringz;
import std.traits : isSomeChar, isSomeString;
import unistd = core.sys.linux.unistd;

import argsutil : passphrase_file, VbLevel, verbose;
import dev : dev_descr, dev_display, is_encrypted;
import file : File;
import tempfile : NamedTemporaryFile;


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
    string pwd = text(_getpass(format!prompt1(reason)));

    if (confirm)
    {
        immutable prompt2 = "Please confirm passwd for %s: ";
        immutable string chk = text(_getpass(format!prompt2(reason)));

        if (chk == pwd)
            return pwd;

        throw new PasswordException("Password confirmation mismatch");
    }

    if (pwd !is null || pwd.length == 0)
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
        show_warning(messages.join("\n"));
}


/**
 * Display a warning on the console.
 */
void show_warning(String)(String message)
if (isSomeString!String ||
    (isInputRange!String &&
     isSomeChar!(ElementType!String)))
{
    if (verbose >= VbLevel.Warn)
        stderr.writeln(message);
}

private enum vbPrefix(VbLevel) = "";
private enum vbPrefix(VbLevel : VbLevel.None) = "Error: ";
private enum vbPrefix(VbLevel : VbLevel.Warn) = "Warning: ";
private enum vbPrefix(VbLevel : VbLevel.More) = "Trace: ";
private enum vbPrefix(VbLevel : VbLevel.Dbug) = "Debug: ";

/**
   This template provides the output functions with the `VbLevel` encoded in the
   function name.

   For further information see the the two vbImpl functions defined inside.

   The aliases following this template create the public names of these output
   functions.
*/
template vbFuns(VbLevel vl)
{
    static if (vl == VbLevel.Info)
        alias output = stdout;
    else
        alias output = stderr;

    /**
       This function outputs data to the standard error, or to the standard
       output for the `info` level, if the `verbose` program argument is at
       least `vl`.

       Params:
         A    = The argument types.
         args = The data that should be logged.

       Example:
       --------------------
       error(486, "is an integer number");
       warn(486, "is an integer number");
       info(486, "is an integer number");
       trace(486, "is an integer number");
       debug(486, "is an integer number");
       --------------------
    */
    void vbImpl(A...)(lazy A args)
        if (args.length == 0 || (args.length > 0 && !is(A[0] : bool)))
    {
        if (verbose >= vl)
        {
            output.write(vbPrefix!vl);
            output.writeln(args);
        }
    }

    /**
       This function outputs data to the standard error, or to the standard
       output for the `info` level, if the `verbose` program argument is at
       least `vl`, and if the additional condition is `true`.

       Params:
         A    = The argument types.
         condition = The condition must be `true` for the data to be written.
         args = The data that should be logged.

       Example:
       --------------------
       error(true, 486, "is an integer number");
       warn(true, 789, "is an integer number");
       info(false, 123, "is an integer number");
       trace(false, 543, "is an integer number");
       debug(false, 876, "is an integer number");
       --------------------
    */
    void vbImpl(A...)(lazy bool condition, lazy A args)
    {
        if (verbose >= vl && condition)
        {
            output.write(vbPrefix!vl);
            output.writeln(args);
        }
    }

    /**
       This function outputs data in a `printf`-style manner.

       The data are put to the standard error, or to the standard
       output for the `info` level, if the `verbose` program argument is at
       least `vl`.

       Params:
         A    = The argument types.
         args = The data that should be logged.

       Example:
       --------------------
       errorf("%d is an integer number", 486);
       warnf("%d is an integer number", 789);
       infof("%d is an integer number", 123);
       tracef("%d is an integer number", 543);
       debugf("%d is an integer number", 876);
       --------------------
    */
    void vbImplf(A...)(lazy string msg, lazy A args)
    {
        if (verbose >= vl)
        {
            output.write(vbPrefix!vl);
            output.writefln(msg, args);
        }
    }

    /**
       This function outputs data in a `printf`-style manner.

       The data are put to the standard error, or to the standard
       output for the `info` level, if the `verbose` program argument is at
       least `vl`, and if the additional condition is `true`.

       Params:
         A    = The argument types.
         condition = The condition must be `true` for the data to be written.
         args = The data that should be logged.

       Example:
       --------------------
       errorf(true, "%d is an integer number", 486);
       warnf(true, "%d is an integer number", 789);
       infof(false, "%d is an integer number", 123);
       tracef(false, "%d is an integer number", 543);
       debugf(false, "%d is an integer number", 876);
       --------------------
    */
    void vbImplf(A...)(lazy bool condition, lazy string msg, lazy A args)
    {
        if (verbose >= vl && condition)
        {
            output.write(vbPrefix!vl);
            output.writefln(msg, args);
        }
    }

}

/// Ditto
alias trace = vbFuns!(VbLevel.More).vbImpl;
/// Ditto
alias tracef = vbFuns!(VbLevel.More).vbImplf;
/// Ditto
alias info = vbFuns!(VbLevel.Info).vbImpl;
/// Ditto
alias infof = vbFuns!(VbLevel.Info).vbImplf;
/// Ditto
alias warning = vbFuns!(VbLevel.Warn).vbImpl;
/// Ditto
alias warningf = vbFuns!(VbLevel.Warn).vbImplf;
/// Ditto
alias error = vbFuns!(VbLevel.None).vbImpl;
/// Ditto
alias errorf = vbFuns!(VbLevel.None).vbImplf;

