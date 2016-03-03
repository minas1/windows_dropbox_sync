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

import std.algorithm;
import std.stdio;
import std.datetime;
import core.thread : Thread;
import std.file;
import std.container.array;
import std.json;
import std.conv;
import std.path;
import std.string : chompPrefix;
import std.experimental.logger;

immutable CONFIG_FILE = "conf.json";

SysTime[string] lastSyncTimes;

shared static this()
{
    MultiLogger logger = new MultiLogger();

    logger.insertLogger("default", new FileLogger(stderr));
    logger.insertLogger("file", new FileLogger("win_dropbox_sync.log"));

    sharedLog = logger;
}

void main()
{
    while (true)
    {
        sync(Clock.currTime(utcTimeZone()));
        Thread.sleep(getNextTimeToRun() - Clock.currTime(utcTimeZone()));
    }
}

auto utcTimeZone()
{

    version (Posix)
    {
        return TimeZone.getTimeZone("UTC");
    }
    version (Windows)
    {
        return TimeZone.getTimeZone("Etc/GMT");
    }
}

SysTime getNextTimeToRun() @safe
{
    auto currentTime = Clock.currTime;

    auto timeToRun = currentTime;

    timeToRun.second = 0;
    timeToRun.minute = (timeToRun.minute + 1) % 60;
    timeToRun.fracSecs = dur!"nsecs"(0);

    return timeToRun;
}

string dropboxDirectory()
{
    import std.file : chdir;
    import std.path : expandTilde;
    import std.exception : enforce;

    version (Posix)
    {
        return expandTilde("~/Dropbox");
    }
    version (Windows)
    {
        import core.sys.windows.windows;

        wchar[64] buffer;
        DWORD len = buffer.sizeof;

        enforce(GetUserName(buffer.ptr, &len) != 0, "Failed to get user name. Error code: " ~ GetLastError().to!string);

        return "C:\\Users\\" ~ buffer[0..len - 1].to!string ~ "\\Dropbox";
    }
}

struct MyDirEntry
{
    auto opCmp(const ref MyDirEntry other) const pure nothrow
    {
        if (fullPath.name < other.fullPath.name)
            return -1;
        else if (fullPath.name == other.fullPath.name)
            return 0;
        return 1;
    }

    alias fullPath this;

    DirEntry fullPath;
    string relPath;
}

auto myDirEntry(DirEntry fullPath, string relPath)
{
    MyDirEntry e;
    e.fullPath = fullPath;
    e.relPath = relPath;
    return e;
}

Array!MyDirEntry getLocalEntries(JSONValue json)
{
    Array!MyDirEntry localEntries;

    foreach (entry; json["directories-to-watch"].array.map!(dir => to!string(dir.str)))
    {
        // local
        if (exists(entry))
        {
            localEntries.insert(myDirEntry(DirEntry(entry), lastDirPart(entry)));

            foreach (dirEntry; dirEntries(entry, SpanMode.depth))
            {
                auto parent = lastDirPart(entry);
                auto entryWithoutPrefix = chompPrefix(dirEntry, entry);
                if (entryWithoutPrefix.startsWith(dirSeparator))
                    entryWithoutPrefix = entryWithoutPrefix[1 .. $];

                localEntries.insert(myDirEntry(dirEntry, parent.buildPath(entryWithoutPrefix)));
            }
        }
    }

    sort(localEntries[]);

    return localEntries;
}

Array!MyDirEntry getRemoteEntries(JSONValue json)
{
    Array!MyDirEntry remoteEntries;

    foreach (entry; json["directories-to-watch"].array.map!(dir => to!string(dir.str)))
    {
        // remote
        auto remotePath = dropboxDirectory().chainPath(lastDirPart(entry));
        if (exists(remotePath))
        {
            remoteEntries.insert(myDirEntry(DirEntry(remotePath.to!string), lastDirPart(entry)));
            foreach (dirEntry; dirEntries(remotePath.to!string, SpanMode.depth))
            {
                auto parent = lastDirPart(entry);
                auto entryWithoutPrefix = chompPrefix(dirEntry.name, remotePath.to!string);
                if (entryWithoutPrefix.startsWith(dirSeparator))
                    entryWithoutPrefix = entryWithoutPrefix[1 .. $];

                auto c = myDirEntry(DirEntry(dirEntry.to!string), lastDirPart(entry).buildPath(entryWithoutPrefix.to!string));
                remoteEntries.insert(myDirEntry(DirEntry(dirEntry.to!string), parent.buildPath(entryWithoutPrefix.to!string)));
            }
        }
    }

    sort(remoteEntries[]);

    return remoteEntries;
}

/**
 * Synchronizes from local entries to remote entries. This synchronizes files that were added (new files)
 * and files that were modified (updated). It does not handle files that were deleted.
 */
void syncNewOrUpdatedEntries(SysTime currentTime, Array!MyDirEntry localEntries, Array!MyDirEntry remoteEntries)
{
    for (size_t i = 0; i < localEntries.length; ++i)
    {
        auto localEntry = localEntries[i];
        auto res = remoteEntries[].map!(e => e.relPath).find(localEntry.relPath);

        // if it does not exist in the remote folder, copy it there
        if (res.empty)
        {
            auto entryToMake = to!string(dropboxDirectory().chainPath(localEntry.relPath));

            if (localEntry.isDir)
                mkdir(entryToMake);
            else
                copy(localEntry.name, entryToMake);

            info("Created ", entryToMake);
            lastSyncTimes[localEntry.relPath] = currentTime;
        }
        else // if it exists in the remote folder
        {
            SysTime accessTime, modificationTime;

            getTimes(localEntry, accessTime, modificationTime);
            modificationTime.timezone = utcTimeZone(); // convert from local time to UTC

            auto lastSyncTime = res.front in lastSyncTimes;

            if (lastSyncTime !is null)
            {
                // If the file was modified since last run (and it's not a directory), check if an update is needed.
                // Directories are modified when their content changes. However, there's no need to do anything here
                // because the files that were deleted will be handled.
                if (modificationTime > *lastSyncTime && localEntry.isFile)
                {
                    auto entryToMake = to!string(dropboxDirectory().chainPath(localEntry.relPath));
                    copy(localEntry.name, entryToMake);
                    info("Updated ", entryToMake);
                }
            }
            else
            {
                if (localEntry.isFile)
                {
                    auto entryToMake = to!string(dropboxDirectory().chainPath(localEntry.relPath));
                    copy(localEntry.name, entryToMake);
                    info("Copied ", localEntry.name);
                }

                // If localEntry is a directory, it means that it already exists in the remote folder.
                // There's nothing to be done in that case.
                // This happens when the application starts and a folder is already there.
            }

            lastSyncTimes[localEntry.relPath] = currentTime;
        }
    }
}

void syncDeleteEntries(SysTime currentTime, Array!MyDirEntry localEntries, Array!MyDirEntry remoteEntries)
{
    for (size_t i = 0; i < remoteEntries.length; ++i)
    {
        auto remoteEntry = remoteEntries[i];
        auto res = localEntries[].map!(e => e.relPath).find(remoteEntry.relPath);

        // if the entry no longer exists
        if (res.empty)
        {
            if (remoteEntry.exists)
            {
                if (remoteEntry.isDir)
                    rmdirRecurse(remoteEntry.name);
                else
                    remove(remoteEntry.name);

                info("Removed ", remoteEntry.name);
            }

            lastSyncTimes.remove(remoteEntry.relPath);
        }
    }
}

void sync(SysTime currentTime)
{
    info("Starting sync at ", currentTime);

    auto conf = getConfiguration();

    auto localEntries = getLocalEntries(conf);
    auto remoteEntries = getRemoteEntries(conf);

    syncNewOrUpdatedEntries(currentTime, localEntries, remoteEntries);
    syncDeleteEntries(currentTime, localEntries, remoteEntries);

    info("Sync finished at ", Clock.currTime(utcTimeZone()));
}

auto lastDirPart(T)(auto ref T t)
{
    import std.path : pathSplitter;
    import std.array : array;

    return pathSplitter(t).array[$ - 1];
}

auto getConfiguration()
{
    import std.json : parseJSON;
    import std.file : readText;

    return parseJSON(readText(CONFIG_FILE));
}
