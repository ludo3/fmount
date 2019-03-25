// Written in the D programming language.

/**
Constants for the `fmount` project.

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
module constvals;

import std.algorithm.searching : minElement;
import std.conv : octal;


/// verbose type
enum VbLevel
{
    /// Print errors.
    None,

    /// Print errors and warnings.
    Warn,

    /// Print errors, warnings and informations.
    Info,

    /// Print more informations in order to check small issues.
    More,

    /// Print as much informations as possible, for debugging purpose.
    Dbug
}


/// The default directory under which mountpoints are created.
enum string DfltMountRoot = "/media";

struct ConfFile
{
    import std.path : sep = dirSeparator;

    string root;

    string dirs;

    string name;

    string toString()
    {
        return root ~ sep ~ dirs ~ sep ~ name;
    }
}

/// The system configuration root, directory and file name.
enum ConfFile SysCfg = { "/etc", "fmount", "fmount.conf" };

/// The user configuration root, directory and file name.
enum ConfFile UsrCfg = { "~", ".fmount", "fmountrc" };


/// The disk-like device categories.
enum Category : string {

    /// The device is removable.
    Removable = "removable",

    /// The device is plugged into an USB port.
    Usb = "usb",

    /// The device is a physical disk.
    Disk = "disk",

    /// The device is a disk partition.
    Part = "part",

    /// The device is a device mapper.
    Dm = "dm",

    /// The device matches any category.
    All = "all"
}

/// The list of available device categories.
static immutable DeviceCategories = [
        Category.Removable,
        Category.Usb,
        Category.Disk,
        Category.Part,
        Category.Dm,
        Category.All,
        ];


/**
 * Explicitly reject the selection of a category.
 * Params:
 *     T   = A string type.
 *     cat = a category to be rejected.
 *
 * Examples:
 * ---
 * assert(nocat(Category.dm) == "nodm");
 * ---
 */
string nocat(T : string)(T cat)
{
    return "no" ~ cat;
}


/// The categories separator is a comma ( `,` ).
static enum CategoriesSep = ",";

/// The default device categories.
static immutable DfltCategories = [
        Category.Usb,
        Category.Removable,
        ];

/// The device directories.
enum DevDir : string {
    /// Device root directory.
    Root = "/dev",

    /// Disk root directory.
    Disk = Root ~ "/disk",

    /// Device mapper directory.
    Dm = Root ~ "/mapper",

    /// Device label directory.
    Label = Disk ~ "/by-label",

    /// Device (short) partition UUID directory.
    PartUuid = Disk ~ "/by-partuuid",

    /// Device hwardware path directory.
    Path = Disk ~ "/by-path",

    /// Device (long) UUID directory.
    Uuid = Disk ~ "/by-uuid",
}

/// The device mapper directory used by cryptsetup.
static immutable string DevMapperDir = DevDir.Root ~ "/mapper";


/// The mode for user-only read-write files.
static immutable ushort ModePrivateRW = octal!600;

/// The mode for user-only read-write directories.
static immutable ushort ModePrivateRWX = octal!700;

/// The mode for user-only write directories.
static immutable ushort ModePrivateWX = octal!300;

/// The maximum label length for each supported filesystem.
immutable long[string] MAX_FS_LABEL_LENGTHS;

/**
 * The minimum value from `MaxFsLabelLengths`.
 *
 * As of Dec 2017, still `11` because of `fat` and `jfs`.
 */
static immutable long MinMaxFsLabelLength;

static this()
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

/// Switch (enable or disable) some values
struct With(string InstanceName)
{
    /// The instance name.
    enum string Name = InstanceName;

    /// The instance type.
    alias Type = With!Name;

    /// Disabling value.
    enum Type No = Type(false);

    /// Enabling value.
    enum Type Yes = Type(true);

    /// Constructor.
    this(bool boo)
    {
        _value = boo;
    }

    private bool _value;
}


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


