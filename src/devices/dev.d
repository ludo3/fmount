// Written in the D programming language.

/**
Device information package.

This module defines functions used to retrieve informations about block
devices.

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
module devices.dev;

import std.algorithm : filter, map;
import std.algorithm.searching : startsWith;
import std.algorithm.sorting : sort;
import std.array : appender, array;
import std.conv : text, to;
import std.file : dirEntries, exists, isDir, isSymlink,
                  readLink, readText, SpanMode;
import std.path : absolutePath, baseName, buildNormalizedPath, dirName,
                  dirSeparator, isAbsolute;
import std.stdio : writeln;
import std.string : endsWith, format, indexOf, join, toLower;
import std.traits : isSomeString;
import std.typecons : tuple;

import devices.constvals : DevDir, DevMapperDir;
import dutil.constvals : VbLevel;
import dutil.os : get_exec_path, jn, readIntFile, runCommand;
import dutil.ui: dbug, dbugf;

alias bn = baseName;
alias dn = dirName;


/**
 * Retrieve the name part of the device path, i.e. 'sda1' for '/dev/sda1'.
 * Params:
 *     S    = A string type.
 *     dev  = A path to a block device.
 */
S dev_name(S)(S dev)
if (isSomeString!S)
{
    return bn(dev_path(dev));
}


/**
 * Build a description of the device, such as "sdb1" or "my_label (sdb1)".
 * Params:
 *     S       = A string type.
 *     dev     = A path to a block device.
 *     display = The default displayed string for the device, which is usually
 *               either the name or a filesystem label.
 */
S dev_descr(S)(S dev, S display = null)
if (isSomeString!S)
{
    S descr = display;

    if (descr is null)
        descr = dev_display(dev);

    S name = dev_name(dev);

    if (descr is null || descr.length == 0)
        descr = name;
    else
        descr ~= format!" (%s)"(name);

    return descr;
}


/**
 *  Build a description of the device.
 *
 *  The '/dev/' prefix is removed from the name, and all links put directly
 *  in /dev are included in order to quickly understand which device is
 *  described.
 *
 *  An available label (in /dev/dksi/by-label) and uuid (/dev/disk/by-uuid or
 *  /dev/disk/by-partuuid) are included as well, if any.
 *
 * Params:
 *     S       = A string type.
 *     dev     = A path to a block device.
 */
S dev_detailed_descr(S)(S dev)
if (isSomeString!S)
{
    S s = dev_name(dev);

    auto links = dev_link_paths(rec, _dev_dir);
    if (links !is null && links.length >= 1)
    {
        s ~= format!" (%s)"(join(links, ", "));
    }

    immutable auto label = dev_label(dev);
    if (label !is null && label.length >= 1)
    {
        s ~= (", label=" ~ label);
    }

    S uuid = dev_uuid(dev);
    if (uuid !is null && uuid.length >= 1)
    {
        s ~= ", uuid=" ~ uuid;
    }

    return s;
}


/** All reached phisical disk directories. */
private static immutable string[] ALL_DISK_DIRS = [
    DevDir.Root.dup,
    DevDir.Uuid.dup,
    DevDir.Label.dup,
    DevDir.PartUuid.dup,
];


private static immutable string[] ALL_DISK_AND_MAPPER_DIRS = [
    DevDir.Root.dup,
    DevDir.Uuid.dup,
    DevDir.Label.dup,
    DevDir.PartUuid.dup,
    DevMapperDir,
];


/**
 * Retrieve the the device path, i.e. '/dev/sda1'.
 * If `dev_or_lnk` contains only a file name and no directory separator,
 * the name is looked up in all usual device directories: `/dev`,
 * `/dev/disk/by-*`, `/dev/mapper`. If more than one path matches a device name,
 * then an exception is raised.
 * Params:
 *     S           = A string type.
 *     dev_or_lnk  = A path to a block device, maybe through a symbolic link.
 */
S search_dev_path(S)(S dev_or_lnk)
if (isSomeString!S)
{
    S path = dev_or_lnk;
    S p;
    if (indexOf(path, dirSeparator[0]) >= 0)
        return dev_path(dev_or_lnk);
    else
    {
        S[] found_paths;

        // find the name or link name that may match.
        S name = path;
        foreach(d; ALL_DISK_AND_MAPPER_DIRS)
        {
            p = jn([text(d), name]);
            if (exists(p))
            {
                found_paths ~= p;
                break;
            }
        }

        if (found_paths.length == 1)
            return dev_path(found_paths[0]);
        else if (found_paths.length == 0)
            throw new NoSuchDeviceException("", dev_or_lnk);
        else
            throw new TooManyDevicesException("", found_paths);
    }
}


/**
 * An exception raised when a device is not found.
 */
class NoSuchDeviceException : Exception
{
    /// Constructor.
    this(const string message, const string device)
    {
        super(buildDescr(message, device));
        this._device = device;
    }

    static private string buildDescr(const string message, const string device)
    {
        string msg = message;
        if (msg !is null && msg.length > 0)
            msg ~= '\n';
        msg ~= "No such device: " ~ device;
        return msg;
    }

    private const string _device;
}


/**
 * An exception raised when more than one device match a device name.
 */
class TooManyDevicesException : Exception
{
    /// Constructor.
    this(const string message, const string[] devices ...)
    {
        super(buildDescr(message, devices));
        this._devices = devices;
    }

    static private string buildDescr(const string message,
                                     const string[] devices)
    {
        string msg = message;
        if (msg is null)
            msg = "";
        if (msg.length)
            msg ~= '\n';

        auto devs = array(devices);
        string[] descrs = array(map!(d => dev_descr(d))(devs));
        string devs_msg = join(descrs, ", ");
        msg ~= format!"Matching devices: %s."(devs_msg);

        return msg;
    }

    private const string[] _devices;
}


/**
 * Retrieve the the device path, i.e. '/dev/sda1'.
 * Params:
 *     S           = A string type.
 *     dev_or_lnk  = A path to a block device, maybe through a symbolic link.
 */
S dev_path(S)(S dev_or_lnk)
if (isSomeString!S)
{
    S path = dev_or_lnk;
    S p;
    if (indexOf(path, dirSeparator[0]) >= 0)
    {
        // find the name or link name that may match.
        S name = path;
        foreach(d; ALL_DISK_DIRS)
        {
            p = jn([text(d), name]);
            if (exists(p))
            {
                path = p;
                break;
            }
        }
    }

    p = absolutePath(path);

    if (isSymlink(p))
    {
        p = readLink(path);
        if (!isAbsolute(p))
        {
            p = absolutePath(jn(dn(path), p));
        }
    }

    return buildNormalizedPath(p);
}


/**
 * Retrieve either a file system label or the device name.
 * Params:
 *     S    = A string type.
 *     dev  = A path to a block device.
 */
S dev_display(S)(S dev)
if (isSomeString!S)
{
    if (isSymlink(dev))
        return bn(dev);

    dbugf("dev_display(%s) : call dev_label", dev);
    S label = dev_label(dev);
    if (label)
        return label;

    dbugf("dev_display(%s) : call dev_name", dev);
    return dev_name(dev);
}


/**
 * Retrieve a device property put at `/dev/disk/by-xxx`.
 * Params:
 *     S        = A string type.
 *     dev      = A path to a block device.
 *     link_dir = A path like `/dev/disk/by-xxx`.
 */
private S _dev_link_name(S)(S dev, S link_dir)
if (isSomeString!S)
{
    immutable S name = dev_name(dev);

    if (exists(link_dir) && isDir(link_dir))
    {
        foreach (S link; dirEntries(link_dir, SpanMode.shallow))
        {
            if (name == bn(readLink(link)))
                return bn(link);
        }
    }

    return "";
}


/**
 * Retrieve the ID_FS_LABEL of the device at /dev/disk/by-label.
 * Params:
 *     S   = A string type.
 *     dev = A path to a block device.
 */
S dev_label(S)(S dev)
if (isSomeString!S)
{
    return _dev_link_name(dev, DevDir.Label);
}


/**
 * Retrieve the ID_FS_UUID of the device at /dev/disk/by-uuid.
 * Params:
 *     S   = A string type.
 *     dev = A path to a block device.
 */
S dev_fsuuid(S)(S dev)
if (isSomeString!S)
{
    return _dev_link_name(dev, DevDir.Uuid);
}


/**
 * Retrieve the ID_PART_TABLE_UUID of the device at /dev/disk/by-partuuid.
 * Params:
 *     S   = A string type.
 *     dev = A path to a block device.
 */
S dev_partuuid(S)(S dev)
if (isSomeString!S)
{
    return _dev_link_name(dev, DevDir.PartUuid);
}


/**
 * Retrieve the DEVPATH of the device at /dev/disk/by-path.
 * Params:
 *     S   = A string type.
 *     dev = A path to a block device.
 */
S dev_hardware_path(S)(S dev)
if (isSomeString!S)
{
    return _dev_link_name(dev, DevDir.Path);
}



/**
 * Retrieve the device mapper name of the device at /dev/mapper.
 * Params:
 *     S   = A string type.
 *     dev = A path to a block device.
 */
S dev_mapper_name(S)(S dev)
if (isSomeString!S)
{
    return _dev_link_name(dev, DevMapperDir);
}


/**
 * Retrieve a blkid value from a device path.
 * Params:
 *     S    = A string type.
 *     dev  = A path to a block device.
 *     attr = A device attribute name.
 */
S _get_blkid_attr(S)(S dev, S attr)
if (isSomeString!S)
{
    S blkid_path = get_exec_path("blkid", ["/usr/local/sbin", "/sbin"]);
    try
    {
        static immutable S fmt = "%s -s '%s' -o value '%s'";
        auto cmd = format!fmt(blkid_path, attr, dev);
        S result = runCommand(cmd);
        return result;
    }
    catch(Exception ex)
    {
        dbug(ex.message);
        return "";
    }
}


/**
 * Retrieve the ID_PARTTABLE_UUID of the device, using /sbin/blkid.
 * Params:
 *     S   = A string type.
 *     dev = A path to a block device.
 */
S dev_parttable_uuid(S)(S dev)
if (isSomeString!S)
{
    return _get_blkid_attr(dev, "PTUUID");
}


/**
 * Retrieve the ID_FS_UUID or ID_PART_UUID or ID_PART_TABLE_UUID of a device.
 * Params:
 *     S   = A string type.
 *     dev = A path to a block device.
 */
S dev_uuid(S)(S dev)
if (isSomeString!S)
{
    immutable auto funs = [ dev_fsuuid, dev_partuuid, dev_parttable_uuid ];
    S res;

    foreach(typeof(dev_fsuuid) fun; funs)
    {
        res = fun(dev);
        if ( res !is null && res.length > 0)
            return res;
    }

    return res;
}


/**
 * Retrieve the link paths to the device, most of them in `/dev/disk/by-*` .
 * Params:
 *     S   = A string type.
 *     dev = A path to a block device.
 *     dirs = The directories in which the links should be looked up.
 */
S[] dev_link_paths(S)(S dev, S[] dirs = [])
if (isSomeString!S)
{
    S path = dev_path(dev);
    if (dirs is null || dirs.length == 0)
        dirs = (ALL_DISK_DIRS ~ [ DevMapperDir ]).dup;

    string[] links;
    auto linksCat = appender(&links);

    foreach (S d; dirs)
    {
        if (endsWith(d, dirSeparator))
            d = d[0..$-1];

        if (exists(d) && isDir(d))
        {
            auto files = dirEntries(d, SpanMode.shallow).array;

            auto lnks = files
                .filter!(f => isSymlink(f.name)
                    && path == absolutePath(buildNormalizedPath(jn(d, readLink(f.name)))))
                .array;
            linksCat ~= lnks;
        }
    }

    return linksCat.data;
}


/**
 * Retrieve the basename of the links to the device.
 * Params:
 *     S   = A string type.
 *     dev = A path to a block device.
 *     dirs = The directories in which the links should be looked up.
 */
S dev_link_names(S)(S dev, S[] dirs)
if (isSomeString!S)
{
    return array(map!(d => bn(d))(dev_link_paths(dev, dirs)));
}


/**
 * Retrieve the first link name of the device, if any.
 * Params:
 *     S   = A string type.
 *     dev = A path to a block device.
 */
S dev_link_name(S)(S dev)
if (isSomeString!S)
{
    auto links = dev_link_paths(dev, DevDir.Root);
    links.sort();
    if (links !is null && links.length > 0)
        return bn(links[0]);

    return "";
}


/**
 * Retrieve the file system of a formatted device.
 * Params:
 *     S    = A string type.
 *     dev  = A path to a block device.
 *     dflt = A default value for the filesystem.
 */
S dev_fs(S)(S dev, S dflt="")
if (isSomeString!S)
{
    S blkid = _get_blkid_attr(dev, "TYPE");
    if (blkid is null || blkid.length == 0)
        blkid = dflt;
    return blkid;
}


/**
 * Retrieve the file system usage of a formatted device.
 * Params:
 *     S    = A string type.
 *     dev  = A path to a block device.
 *     dflt = A default value for the filesystem usage.
 */
S dev_fs_usage(S)(S dev, S dflt="")
if (isSomeString!S)
{
    S fs = dev_fs(dev);

    if (indexOf(fs, "crypto") >= 0)
        return "crypto";

    if (fs !is null && fs.length > 0)
        return "filesystem";

    return dflt;
}


/**
 * Retrieve the device size in bytes.
 * Params:
 *     S   = A string type.
 *     dev = A path to a block device.
 */
size_t dev_bytes(S)(S dev)
if (isSomeString!S)
{
    immutable S size_path = format!"/sys/class/block/%s/size"(dev_name(dev));

    // The size is provided as number of blocks of 512 bytes
    return 512 * readIntFile(size_path);
}


/**
 * Print the information of a `is_xxx` function, for debugging purpose.
 * Params:
 *     S   = A string type.
 *     R   = A result type.
 *     dev = A path to a block device.
 *     ret = The result of the function.
 */
private void _dbg_is_(S, R)(lazy S is_xxx_name, lazy S dev, R ret)
if (isSomeString!S)
{
    dbugf("%s(%s)=%s", is_xxx_name, dev_descr(dev), text(ret));
}


/**
 * Check whether a device is an encrypted device.
 *
 * An encrypted device has dev_fs_usage(dev)=crypto and is not a device mapping.
 *
 * Params:
 *     S   = A string type.
 *     dev = A path to a block device.
 */
bool is_encrypted(S)(S dev)
if (isSomeString!S)
{
    if (dev is null || dev.length == 0)
        return false;

    immutable bool ret = dev_fs_usage(dev) == "crypto" && !is_dm(dev);
    _dbg_is_("is_encrypted", dev, ret);
    return ret;
}


/**
 * Check whether a device block or partition is connected through USB.
 * Params:
 *     S   = A string type.
 *     dev = A path to a block device.
 */
bool is_usb(S)(S dev)
if (isSomeString!S)
{
    immutable bool ret = indexOf(toLower(dev_hardware_path(dev)), "usb") >= 0;
    _dbg_is_("is_usb", dev, ret);
    return ret;
}


/**
 * Retrieve the disk name for a partition.
 * Params:
 *     S   = A string type.
 *     dev = A path to a block device.
 */
S get_disk_name(S)(S dev)
if (isSomeString!S)
{
    immutable S part_name = dev_name(dev);
    immutable S sysroot = "/sys/block";

    if (exists(sysroot) && isDir(sysroot))
    {
        foreach (S sysdir; dirEntries(sysroot, SpanMode.shallow))
        {
            if (exists(sysdir) && isDir(sysdir))
            {
                foreach (S part; dirEntries(sysdir, SpanMode.shallow))
                {
                    if (bn(part) == part_name)
                    {
                        // /sys/block/sdb/sdb1 => sdb
                        return to!S(bn(sysdir));
                    }
                }
            }
        }
    }

    return to!S("");
}


/**
 * Check whether a block device is a CD reader and/or writer.
 * Params:
 *     S   = A string type.
 *     dev = A path to a block device.
 */
bool is_removable(S)(S dev)
if (isSomeString!S)
{
    S hwname = dev_name(dev);
    if (is_partition(dev))
        hwname = get_disk_name(dev);
    immutable S removable_path = format!"/sys/class/block/%s/removable"(hwname);

    immutable bool ret = readIntFile(removable_path) != 0;

    _dbg_is_("is_removable", dev, ret);

    return ret;
}


/**
 * Check whether a device is a disk partition.
 * Params:
 *     S   = A string type.
 *     dev = A path to a block device.
 */
bool is_partition(S)(S dev)
if (isSomeString!S)
{
    S syspart = format!"/sys/class/block/%s/partition"(dev_name(dev));
    immutable bool ret = exists(syspart);

    _dbg_is_("is_partition", dev, ret);

    import dutil.ui:dbug;dbug("is_partition: return ", ret);
    return ret;
}


/**
 * Check whether a device is a device mapper block device.
 * Params:
 *     S   = A string type.
 *     dev = A path to a block device.
 */
bool is_dm(S)(S dev)
if (isSomeString!S)
{
    immutable S name = dev_name(dev);

    bool ret;

    if (exists(DevMapperDir) && isDir(DevMapperDir))
    {
        foreach (S lnk; dirEntries(DevMapperDir, SpanMode.shallow))
        {
            if (isSymlink(lnk))
            {
                if (bn(readLink(lnk)) == name)
                {
                    ret = true;
                    break;
                }
            }
        }
    }

    _dbg_is_("is_dm", dev, ret);

    return ret;
}


/**
 * Check whether a device contains a (maybe encrypted) filesystem.
 * Params:
 *     S   = A string type.
 *     dev = A path to a block device.
 */
bool is_fs(S)(S dev)
if (isSomeString!S)
{
    immutable S usage = dev_fs_usage(dev);
    immutable bool ret = indexOf(["filesystem", "crypto"], usage) >= 0;

    _dbg_is_("is_fs", dev, ret);

    return ret;
}


/**
 * Check whether a device is a disk device.
 * Params:
 *     S   = A string type.
 *     dev = A path to a block device.
 */
bool is_disk(S)(S dev)
if (isSomeString!S)
{
    S name = dev_name(dev);
    S devtype_path = format!"/sys/block/%s/dev"(name);

    bool ret;
    if (exists(devtype_path))
    {
        // 8:0 => disk
        // 11:0 => cd/dvd
        // 254:0 => dm
        ret = readText(devtype_path) == "8:0";
    }

    _dbg_is_("is_disk", dev, ret);

    return ret;
}


/**
 * An exception raised when a device is unexpectedly mounted.
 */
class MountedDeviceException : Exception
{
    /// Constructor.
    this(const string message, const string[] devices ...)
    {
        super(buildDescr(message, devices));
        this._devices = devices;
    }

    static private string buildDescr(const string message,
                                     const string[] devices)
    {
        string msg = message;
        if (msg is null)
            msg = "";
        if (msg.length)
            msg ~= '\n';

        auto devs = array(devices);
        if (devs.length)
            msg ~= "No mounted device.";
        else
        {
            string plural = "";
            if (devs.length > 1)
                plural = "s";
            string[] descrs = array(map!(d => dev_descr(d))(devs));
            string devs_msg = join(descrs, ", ");
            msg ~= format!"Mounted device%s: %s."(plural, devs_msg);
        }

        return msg;
    }

    private const string[] _devices;
}


private S dm_pfx(S)()
{
    S prefix = to!S("_dev_");
    return prefix;
}

/**
 * Build a mapping name for encrypted devices.
 *
 * The name is compatible with pmount 0.9.23 .
 *
 * Params:
 *     S          = A string type.
 *     raw_device = A path to an encrypted block device.
 */
S get_dm_name(S)(S raw_device)
if (isSomeString!S)
{
    // Note: both fmount and pmount use '_dev_sdXN' as mapping label.
    // Example: DM_NAME='_dev_sdc1' for /dev/sdc1 encrypted partition.
    return dm_pfx!S() ~ dev_name(dev_path(raw_device));
}


/**
 *  Retrieve the dmcrypt device for an encrypted device, or the encrypted device
 *  for a dmcrypt device.
 *
 *  Both the dmcrypt and raw device are returned in a tuple
 *  (decrypted_disk, disk), or the (disk, "") tuple is returned.
 *
 * Params:
 *     S    = A string type.
 *     disk = A path to an encrypted block device or to a dmcrypt block device.
 */
S[] get_dm_and_raw_dev(S)(S disk)
if (isSomeString!S)
{
    S encrypted_disk = "";

    if (is_encrypted(disk))
    {
        immutable S dm_name = get_dm_name(disk);
        if (exists(DevMapperDir) && isDir(DevMapperDir))
        {
            foreach(S dm; dirEntries(DevMapperDir, SpanMode.shallow))
            {
                if (bn(dm) == dm_name)
                {
                    encrypted_disk = disk;
                    disk = dm;
                    break;
                }
            }
        }
    }
    else if (is_dm(disk))
    {
        immutable S mapper_name = dev_mapper_name(disk);
        if (exists(DevDir.Root) && isDir(DevDir.Root))
        {
            foreach(S raw; dirEntries(DevDir.Root, SpanMode.shallow))
            {
                if (get_dm_name(raw) == mapper_name)
                    encrypted_disk = raw;
            }
        }
    }

    return [disk, encrypted_disk];
}


