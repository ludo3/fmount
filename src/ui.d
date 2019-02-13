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
import std.stdio : writeln;
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
 *   String     = A string type.
 *   strict     = If `true` then the message is shown on the console, as if
 *                `verbose` was set to `vbmore=3`.
 *   message    = A message to be shown.
 */
void show_warnings(String)(bool strict, String message)
if (isSomeString!String ||
    (isInputRange!String &&
     isSomeChar!(ElementType!String)))
{
    show_warnings(strict, [message]);
}


/**
 * Display one or more warning(s).
 *
 * Params:
 *   strict     = If `true` then the message is shown on the console, as if
 *                `verbose` was set to `vbmore=3`.
 *   Strings    = An input range of strings.
 *   messages   = Some messages to be shown.
 */
void show_warnings(Strings)(bool strict, Strings messages)
if (isInputRange!Strings &&
    (isInputRange!(ElementType!Strings) &&
     isSomeChar!(ElementType!(ElementType!Strings))))
{
    if (strict || verbose >= VbLevel.More)
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
        writeln(message);
}


