// Written in the D programming language.

/**
Constants for the main section of the `fmount` project.

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
module fmount.constvals;

import std.algorithm.searching : minElement;


/// The default directory under which mountpoints are created.
enum string DfltMountRoot = "/media";

/// Tell whether directories must be created.
enum CreateDirs : bool
{
    /// Do not create directories.
    NO,

    /// Create directories.
    YES,
}

/// A structure with root directory, subdirectories and file name.
struct ConfFile
{
    import std.path : sep = dirSeparator;

    /// Select automatic directory creation or not.
    CreateDirs createDirs;

    /// The root directory of the configuration file.
    string root;

    /// The subdirectory chain under the root directory.
    string dirs;

    /// The configuration file name with its optional extension.
    string name;

    /// Build the full configuration path.
    string toString() const
    {
        return root ~ sep ~ dirs ~ sep ~ name;
    }
}

/// The system configuration root, directory and file name.
enum ConfFile SYS_CFG = { CreateDirs.NO, "/etc", "fmount", "fmount.conf" };

/// The user configuration root, directory and file name.
enum ConfFile USR_CFG = { CreateDirs.YES, "~", ".fmount", "fmountrc" };


/// The path to the `fstab` file.
enum string FSTAB_PATH = "/etc/fstab";

/**
 * The regular expression pattern matching mass storage attributes in the
 * `fstab` file.
 */
enum string FSTAB_ATTR_PATT = `^(?P<name>[A-Z]+)=(?P<attr>\S+)\s+(?P<mp>/\S+)`;

/**
 * The regular expression pattern matching mass storage paths in the
 * `fstab` file.
 */
enum string FSTAB_DEVPATH_PATT = `^(?P<devPath>/\S+)\s+(?P<mp>/\S+)`;


/// The maximum label length for each supported filesystem.
immutable long[string] MAX_FS_LABEL_LENGTHS;

/**
 * The minimum value from `MaxFsLabelLengths`.
 *
 * As of Dec 2017, still `11` because of `fat` and `jfs`.
 */
static immutable long MinMaxFsLabelLength;

shared static this()
{
    import std.exception : assumeUnique;

    long[string] temp; // mutable buffer
    temp["btrfs"] = 255;
    temp["exfat"]  =  15;
    temp["fat"]    =  11;
    temp["ext2"]   =  16;
    temp["ext3"]   =  16;
    temp["ext4"]   =  16;
    temp["f2fs"]   = 512;
    temp["jfs"]    =  11;
    temp["ntfs"]   =  32;
    temp["xfs"]    =  12;
    temp.rehash; // for faster lookups

    MAX_FS_LABEL_LENGTHS = assumeUnique(temp);
    MinMaxFsLabelLength = minElement(MAX_FS_LABEL_LENGTHS.values);
}


/**
 * The message to be printed if the program is not run with administrator
 * privileges.
 */
static enum how_to_run_as_root = q"TXT
fmount is not being run with enough privileges.
Unlike pmount and mountpy, setuid is not an option.
Like mountpy, There are 2 ways how to make fmount run comfortably with root privileges:
1) install sudo, add this line to /etc/sudoers:
joesmith ALL = NOPASSWD: /usr/bin/fmount /usr/bin/fumount
 or
joesmith ALL = NOPASSWD: /usr/local/bin/fmount /usr/local/bin/fumount
   to allow user joesmith use fmount and fumount.
   If you want to allow all the users use fmount and fumount, change the line into:
ALL ALL = NOPASSWD: /usr/bin/fmount /usr/bin/fumount
 or
ALL ALL = NOPASSWD: /usr/bin/fmount /usr/bin/fumount
   respectively, and then run "sudo fmount" and "sudo fumount".
2) install super, add these lines to /etc/super.tab:
   fmount /usr/bin/fmount joesmith
   fumount /usr/bin/fumount joesmith
   to allow user joesmith to run fmount, or:
fmount /usr/bin/fmount .*
fumount /usr/bin/fumount .*
   to give access to all the users, and run "super fmount"

Be aware that giving all the users rights to execute fmount can be a
security risk, if an exploitable bug is found in fmount.
Therefore, it is recommended to allow only selected users to run fmount,
and use super or sudo if possible.
TXT";

