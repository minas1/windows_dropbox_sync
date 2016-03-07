/*
"Windows Dropbox Sync" Copyright (C) 2016 Minas Mina

This file is part of "Windows Dropbox Sync".

"Windows Dropbox Sync" is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

"Windows Dropbox Sync" is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with "Windows Dropbox Sync".  If not, see <http://www.gnu.org/licenses/>.
*/

import std.path;
import std.array;

immutable APP_DATA_DIRECTORY = "windows-dropbox-sync";

string userHomeDirectory()
{
    version (Posix)
    {
        return expandTilde("~");
    }
    version (Windows)
    {
        import core.sys.windows.windows;
        import std.exception;
        import std.conv;

        wchar[64] buffer;
        DWORD len = buffer.sizeof;

        enforce(GetUserName(buffer.ptr, &len) != 0, "Failed to get user name. Error code: " ~ GetLastError().to!string);

        return "C:\\Users\\" ~ buffer[0..len - 1].to!string;
    }
}

string applicationLocalDirectory()
{
    version (Posix)
    {
        return userHomeDirectory().chainPath(".local/share/").chainPath(APP_DATA_DIRECTORY).array;
    }
    version (Windows)
    {
        return userHomeDirectory().chainPath("AppData\\Local\\").chainPath(APP_DATA_DIRECTORY).array;
    }
}

string dropboxDirectory()
{
    return userHomeDirectory().chainPath("Dropbox").array;
}
