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

import std.conv : text;
import std.exception : basicExceptionCtors;
import std.format : format;
import std.stdio : writeln;
import std.string : fromStringz, toStringz;
import unistd = core.sys.linux.unistd;

import argsutil : VbLevel, verbose;


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


