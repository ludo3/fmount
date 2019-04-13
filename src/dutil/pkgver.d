// Written in the D programming language.

/**
Version description.

Copyright: Copyright Ludovic Dordet 2018.
License:   $(HTTP www.gnu.org/licenses/gpl-3.0.md,
             GNU GENERAL PUBLIC LICENSE 3.0).
Authors:   Ludovic Dordet
*/
/*
         Copyright Ludovic Dordet 2019.
Distributed under the GNU GENERAL PUBLIC LICENSE, Version 3.0.
   (See accompanying file LICENSE.md or copy at
         http://www.gnu.org/licenses/gpl-3.0.md)
*/
module dutil.pkgver;

import std.conv : to;

private enum char sep = '.';
private enum char pre = '-';
private enum char post = '+';

/// Gather version informations.
struct Version
{
    /// Major version number.
    size_t major;

    /// Minor version number.
    size_t minor;

    /// Patch version number.
    size_t patch;

    /// Version kind.
    VersionKind kind;

    /// Number of iterations for the version kind.
    size_t knum;

    /// Describe the version.
    string toString() const
    {
        import std.array : appender;
        auto w = appender!string;
  
        w.put(major.to!string);
        w.put(sep);
        w.put(minor.to!string);
        w.put(sep);
        w.put(patch.to!string);
  
        if (kind != VersionKind.release)
        {
            if (kind != VersionKind.dev)
            {
                w.put(pre);
                w.put(kind.to!string);
                w.put(knum.to!string);
            }
            else
            {
                w.put(post);
                w.put(kind.to!string);
            }
        }

        return w.data;
    }

}

/// Create a development (post-release) version.
Version development(size_t major, size_t minor, size_t patch)
{
    return Version(major, minor, patch, VersionKind.dev, 0);
}

/// Create a release version.
Version release(size_t major, size_t minor, size_t patch)
{
    return Version(major, minor, patch, VersionKind.release, 0);
}


/// Version unittest
unittest
{
    import std.algorithm.comparison : equal;
    import std.format : _f = format;

    immutable VersionKind[] kinds = [
        VersionKind.alpha,
        VersionKind.beta,
        VersionKind.rc
    ];

    foreach(maj; 0..32)
    {
        foreach(min; 0..12)
        {
            foreach(pat; 0..14)
            {
                foreach(k; kinds)
                {
                    foreach (n; 1..16)
                    {
                        immutable ver = Version(maj, min, pat, k, n);
                        immutable exp = _f!"%d.%d.%d-%s%d"(maj, min, pat, k, n);
                        assert(ver.to!string == exp, ver.to!string);
                    }
                }

                immutable rel = release(maj, min, pat);
                immutable relExp = _f!"%d.%d.%d"(maj, min, pat);
                assert(rel.to!string == relExp, rel.to!string);

                immutable dev = development(maj, min, pat);
                immutable devExp = _f!"%d.%d.%d+dev"(maj, min, pat);
                assert(dev.to!string == devExp, dev.to!string);
            }
        }
    }
}

/// The kind of version
enum VersionKind : string
{
    /// Unreleased build, should only be used for test purpose.
    dev = "dev",

    /// Alpha version, for early user-level testing.
    alpha = "alpha",

    /// Beta version, for many user-level testing.
    beta = "beta",

    /// Release candidate version, for full testing.
    rc = "rc",

    /// Release
    release = "release"
}


/// VersionKind dummy unittest
unittest
{
    import std.algorithm.comparison : equal;

    static assert(equal(VersionKind.dev.to!string, "dev"));
    static assert(equal(VersionKind.alpha.to!string, "alpha"));
    static assert(equal(VersionKind.beta.to!string, "beta"));
    static assert(equal(VersionKind.rc.to!string, "rc"));
    static assert(equal(VersionKind.release.to!string, "release"));
}


