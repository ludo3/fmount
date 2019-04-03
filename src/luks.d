// Written in the D programming language.

/**
LUKS-encrypted devices handling.

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
module luks;

import core.thread : Thread;
import core.time : msecs;
import std.array : join;
import std.file : exists;
import std.stdio : writeln;
import std.string : format;
import std.traits : hasMember, isSomeString;

import appargs : check_exec_dirs, fake, verbose;
import constvals : DevMapperDir, VbLevel;
import dev : dev_path;
import mountargs : luks_keyfile_args, passphrase_file;
import osutil : CommandFailedException, jn, runCommand;


/**
 * Initialize a LUKS partition and set the initial passphrase.
 * Params:
 *     S      = A string type.
 *     device = The path to a device.
 */
void luksFormat(S)(S device)
if (isSomeString!S)
{
    immutable auto cmdArr = ["/sbin/cryptsetup"]
                          ~ luks_keyfile_args(passphrase_file)
                          ~ ["luksFormat", dev_path(device)];
    immutable S cmd = join(cmdArr, " ");

    try
    {
        runCommand(cmd);
    }
    catch(CommandFailedException ex)
    {
        throw LuksException.luksError(ex);
    }
}


/**
 * Open a LUKS encrypted device.
 * Params:
 *     S             = A string type.
 *     F             = A file-like type with a `name`member, or the `null` type.
 *     device        = The path to a device.
 *     password_file = A `stdio.File` like object with a `name` property.
 *     mapping_name  = The name for the decrypted device.
 *
 * Returns:
 *     A path to a device mapping.
 */
S luksOpen(S, F)(S device, F password_file, S mapping_name)
if (isSomeString!S &&
    (is(F == typeof(null)) || hasMember!(F, "name")))
{
    string password_file_name;
    if (password_file != typeof(password_file).init)
        password_file_name = password_file.name;

    immutable auto openCmdArr = cast(immutable(string[]))
            (["/sbin/cryptsetup"]
           ~ luks_keyfile_args(password_file_name)
           ~ ["luksOpen", dev_path(device), mapping_name]);
    immutable string openCmd = join(openCmdArr, " ");

    try
    {
        runCommand(openCmd);
    }
    catch(CommandFailedException ex)
    {
        throw LuksException.mappingFailed(mapping_name, ex);
    }

    S dmdev = jn(DevMapperDir, mapping_name);

    if (!exists(dmdev) && !fake)
        throw LuksException.mappingFailed(mapping_name);

    return dmdev;
}


/**
 * Close a LUKS encrypted device previously opened with the luksOpen function.
 * Params:
 *     S            = A string type.
 *     mapping_name = The name for the decrypted device.
 */
void luksClose(S)(S mapping_name)
if (isSomeString!S)
{
    auto closeCmdArr = ["/sbin/cryptsetup", "luksClose", mapping_name];
    string closeCmd = join(closeCmdArr, " ");

    // luksClose fails if it is run immediately after a formatting...
    Thread.sleep( msecs( 500 ) );

    try
    {
        runCommand(closeCmd);
    }
    catch(CommandFailedException ex)
    {
        throw LuksException.luksError(mapping_name, ex);
    }
}


/// The exception raised when a LUKS command fails.
class LuksException : Exception
{

    /**
     * Create a LuksException related to a mapping failure (bad password, LUKS
     * internal error, ...) .
     * Params:
     *     mapping_name = The name for the decrypted device.
     *     cause        = The exception raising a `LuksException`.
     */
    static LuksException mappingFailed(string mapping_name,
                                       Exception cause=null)
    {
        string msg = format!"LUKS mapping %s failed."(mapping_name);

        if (cause is null)
            return new LuksException(msg);

        return new LuksException(msg, cause);
    }

    /// Create a LuksException related to a LUKS error.
    static LuksException luksError(string mapping_name, Exception cause=null)
    {
        string msg = format!"LUKS error for mapping %s."(mapping_name);

        if (cause is null)
            return new LuksException(msg);

        return new LuksException(msg, cause);
    }

    /// Create a LuksException related to a LUKS error.
    static LuksException luksError(Exception cause)
    {
        string msg = format!"LUKS error: %s"(cause.message);
        return new LuksException(msg, cause);
    }

    /// Constructor with the error message.
    private this(string message)
    {
        super(message);
    }

    /// Constructor with a causing exception.
    private this(string message, Exception cause)
    {
        super(message, cause);
    }
}

