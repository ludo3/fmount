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
import std.stdio : writeln;
import std.string : format;

import argsutil : check_exec_dirs, luks_keyfile_args, fake, passphrase_file,
                  VbLevel, verbose;
import constvals : DevMapperDir;
import osutil : runCommand;


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

    runCommand(cmd);
}


/**
 * Open a LUKS encrypted device.
 * Params:
 *     S            = A string type.
 *     device       = The path to a device.
 *     mapping_name = The name for the decrypted device.
 */
S luksOpen(S)(S device, S mapping_name)
if (isSomeString!S)
{
    immutable auto openCmdArr = ["/sbin/cryptsetup"]
                              ~ luks_keyfile_args(passphrase_file)
                              ~ ["luksOpen", dev_path(device), mapping_name];
    immutable string openCmd = join(openCmdArr, " ");

    runCommand(openCmd);

    S dmdev = jn(DevMapperDir, mapping_name);

    if (!exists(dmdev) && !fake)
        throw new LuksException(format!"LUKS mapping %s failed."(mapping_name));

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
    closeCmdArr = ["/sbin/cryptsetup", "luksClose", mapping_name];
    string closeCmd = join(closeCmdArr, " ");

    // luksClose fails if it is run immediately after a formatting...
    Thread.sleep( msecs( 500 ) );

    runCommand(closeCmd);
}


/// The exception raised when a LUKS command fails.
class LuksException : Exception
{

    /**
     * Create a LuksException related to a mapping failure (bad password, LUKS
     * internal error, ...) .
     * Params:
     *     mapping_name = The name for the decrypted device.
     */
    static LuksException mappingFailed(string mapping_name)
    {
        string msg = format!"LUKS mapping %s failed."(mapping_name);
        return new LuksException(msg);
    }

    /// Create a LuksException related to a LUKS error.
    static LuksException luksError(string mapping_name)
    {
        string msg = format!"LUKS error for mapping %s."(mapping_name);
        return new LuksException(msg);
    }

    /// Constructor with the error message.
    private this(string message)
    {
        super(message);
    }
}

