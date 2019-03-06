// Written in the D programming language.

/**
File related utilities.

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
module fileutil;

import std.array : array, join;
import std.stdio : File;
import std.traits : isSomeString;


/**
 * Retrieve the content of a file, if available, i.e. if opened in an append
 * mode.
 *
 * Params:
 *     nbLines = The number of last lines to retrieve. If zero, then the
 *               full content is retrieved.
 *     file    = The file from which the last lines should be retrieved.
 */
string getText(size_t nbLines=1)(File file)
{
    if (file.isOpen)
    {
        file.lock();
        scope(exit)
            file.unlock();

        immutable ulong pos = file.tell();
        file.rewind;

        scope(exit)
        {
            // make sure all read/write modes are correctly handled.
            file.rewind();
            file.seek(pos);
        }

        return file.byLineCopy()
                   .array()
                   .extract(nbLines)
                   .join("\n");
    }

    return "";
}


private S[] extract(S)(S[] data, size_t nb)
if (isSomeString!S)
{
    if (nb == 0 || nb >= data.length)
        return data;
    else
        return data[$-nb .. $];
}

