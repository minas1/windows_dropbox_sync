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
