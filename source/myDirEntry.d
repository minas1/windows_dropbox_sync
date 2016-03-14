import std.file;

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