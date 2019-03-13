// Written in the D programming language.

/**
Functions common to mount, unmount and/or format commands.

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
module mnt.common;

import core.stdc.errno : ENOENT, ENOTDIR, EPERM;
import std.algorithm : canFind, map, startsWith;
import std.array : array, split;
import std.conv : to;
import std.file : dirEntries, exists, FileException, isDir, mkdir, readText,
                  remove, rmdir, SpanMode, write;
import std.path : bn=baseName, dn=dirName, isAbsolute;
import std.process : ProcessException;
import std.regex : matchFirst, regex;
import std.stdio : stderr;
import std.string : format;
import std.traits : isSomeString;

import appconfig;
import argsutil : fake, VbLevel, verbose;
import constvals : how_to_run_as_root;
import dev : dev_path, dev_link_paths, get_dm_and_raw_dev, is_removable, is_usb;
import dutil : printThChain;
import osutil : assertDirExists, jn;
import ui : dbug, dbugf, error, errorf, info_, trace, tracef, warning,
            WithPrefix;


// TODO use args.get_conf_dir(verbose, test), create a config file .fmountrc,
//      put default_options into it

/// The default hardcoded mount options.
enum default_options = "noatime,noexec";


/**
 * Retrieve the expected path to the mount directory for device `dev`.
 * Params:
 *     S         = A string type.
 *     dev       = A path to a block device.
 *     mountname = The name of the directory where the device will be mounted.
 */
S get_expected_mountpoint(S)(S dev, S mountname)
if (isSomeString!S)
{
    if (isAbsolute(mountname))
        return mountname;

    S root = get_mountroot();
    return jn(root, mountname);
}


/**
 * The names for files used to mark automatically created directories.
 *
 * Such markup files are used for automatic deletion when the directories are
 * not needed any more.
 */
private enum CreatedBy : string
{
    /// The directory has been created by fmount.
    Fmount = ".created_by_fmount",

    /// The directory has been created by pmount (for compatibility).
    Pmount = ".created_by_pmount"
}


/**
 * Ensure that a directory exists. The parent directory must exist.
 *
 * If the directory is created automatically then it is marked with an empty
 * file named `CreatedBy.Fmount`.
 *
 * Params:
 *     S    = A string type.
 *     path = The path to a directory to be checked or created.
 */
void ensure_mntdir_exists(S)(S path)
if (isSomeString!S)
{
    assertDirExists(dn(path));

    if ( !exists(path) )
    {
        trace("Creating directory ", path);
        if (!fake)
            mkdir(path);

        auto autocreated_file = jn(path, CreatedBy.Fmount);
        dbug("Creating file ", autocreated_file);
        if (!fake)
            autocreated_file.write("");
    }
    else if ( !isDir(path) )
    {
        throw new FileException(path, ENOTDIR);
    }
}


/**
 * Remove an automatically created directory.
 *
 * The directory is removed if it only contains one of the empty files
 * `CreatedBy.Fmount` or `CreatedBy.Pmount`.
 */
void remove_automatically_created_dir(S)(S path)
if (isSomeString!S)
{
    auto autocreated = false;
    string[] entries;
    if (exists(path) && isDir(path))
    {
        try
        {
            entries = map!("a.name")(dirEntries(path, SpanMode.shallow)).array;
        }
        catch(Exception ex)
        {
            if (verbose >= VbLevel.More)
                printThChain(ex);
        }
    }

    if ((entries !is null) && entries.length == 1)
    {
        auto entryName = bn(entries[0]);
        if (entryName == CreatedBy.Fmount
            || entryName == CreatedBy.Pmount)
        {
            autocreated = true;
            auto autocreated_file = entries[0];

            dbug("Removing ", autocreated_file);
            if (!fake)
            {
                try
                {
                    remove(autocreated_file);
                }
                catch(FileException)
                {
                    // removal silently failed.
                }
            }
        }
    }

    if (autocreated)
    {
        trace("Removing directory ", path);
        if (!fake)
            rmdir(path);
    }
}


/// Matches one `mountpoint` line in `/proc/mounts` .
private immutable _MpRx =
    regex(`^(?P<dev>\S+)\s+(?P<mp>\S+)\s+(?P<fs>\S+)\s+.*$`);

/**
 * Check whether a device is mounted and return the associated matcher.
 */
private auto
_get_mountpoint_match(string device, string mountpoints_path="/proc/mounts")
{
    // Regex note : cannot create static captures.
    /// Unmatching `mountpoint` line.
    auto _NoMpMatch = "".matchFirst(_MpRx);

    // Check whether the device is a mounted dmcrypt partition.
    device = get_dm_and_raw_dev(device)[0];

    immutable devpaths = ([dev_path(device)] ~ dev_link_paths(device)).idup;

    string mountpoints = readText(mountpoints_path);
    foreach (string line; mountpoints.split("\n"))
    {
        foreach (string dp; devpaths)
        {
            if (startsWith(line, dp))
            {
                auto match = line.matchFirst(_MpRx);
                if (!match.empty)
                    return match;

                // no match
                return _NoMpMatch;
            }
        }
    }

    // no match
    return _NoMpMatch;
}


/**
 * Retrieve a named capture from an `_MpRx` `matchFirst`.
 */
private string _get_procmounts_namedCap(string name,
                                        string device,
                                        string dflt = "")
{
    assert(canFind(["dev", "mp", "fs"], name),
                   format!"Invalid mountpoint attribute '%s'."(name));

    if (device is null || device.length == 0)
        return dflt;

    auto match =  _get_mountpoint_match(device);
    if (!match.empty)
        return match[name];

    return dflt;
}

/**
 * Find the filesystem of a mounted device, if any.
 *
 * If the device is encrypted then the mountpoint is found through the device
 * mapper.
 *
 * Params:
 *     device = The path to a block device.
 *     dflt   = the default filesystem value to be returned.
 */
string get_filesystem(string device, string dflt = "")
{
    return _get_procmounts_namedCap("fs", device, dflt);
}


/**
 * Find the mountpoint of the device, if any.
 *
 * If the device is encrypted then the mountpoint is found through the device
 * mapper.
 *
 * Params:
 *     device = The path to a block device.
 *     dflt   = the default filesystem value to be returned.
 */
string find_mountpoint(string device, string dflt="")
{
    return _get_procmounts_namedCap("mp", device, dflt);
}


/**
 * Check that the program is run as root, either from sudo or super, or with
 * setuid bit set.
 *
 * Params:
 *     S      = A string type.
 *     device = A path to a block device.
 *     prog   = The program name.
 */
void check_user(S)(S device, S prog)
if (isSomeString!S)
{
    import core.sys.posix.unistd : geteuid;
    import std.process : environment;

    import osutil : getRealUserAndGroup;

    auto euid = geteuid();

    //FIXME to be tested with sudo and super.
    auto real_user = getRealUserAndGroup();

    if (euid == 0)
    {
        string sudoCmd = environment.get("SUDO_COMMAND");
        string superCmd = environment.get("SUPERCMD");

        if (sudoCmd)
            tracef("Running sudo command '%s'.", sudoCmd);
        else if (superCmd)
            tracef("Running super command '%s'.", superCmd);

        bool removable = is_removable(device);
        bool usb = is_usb(device);

        if (removable || usb)
        {
            if (verbose >= VbLevel.More)
            {
                auto r_or_u = "";
                auto op_permitted =
                    ("%s device %s: "
                   ~ "Operation permitted for real_user='%s' as "
                   ~ "effective_user='root'.");
                if (usb)
                    r_or_u = "usb";
                if (removable)
                {
                    if (r_or_u.length > 0)
                        r_or_u ~= " ";
                    r_or_u ~= "removable";
                }
                tracef(op_permitted, r_or_u, device, real_user);
            }

            return;
        }
        else
        {
            // TODO check configuration : allow or disallow fixed devices
            //                            at system level.

            // if the user is really root, only warn about fixed device;
            // otherwise the action is forbidden.
            warning("The device ", device, " is not removable.");
            if (real_user == "root:root")
                return;
        }
    }
    else
    {
        errorf("%s cannot be run as '%s'.", prog, real_user);
        error!(WithPrefix.No)(how_to_run_as_root);
    }

    throw ProcessException.newFromErrno(EPERM);
}

