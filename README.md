# Windows Dropbox Sync

## Description
On Windows, Dropbox [cannot synchronize folders outside the dropbox folder](https://www.dropbox.com/en/help/12).  

The solution recommended by Dropbox is to move your folders _inside_ the dropbox folder and make shortcuts where you want them to be, but for many this is not an acceptable solution.

_Windows Dropbox Sync_ aims to solve this. You can configure folders / files to watch and it will **copy** them to your local dropbox folder. The dropbox service will take care of uploading the data to your dropbox account.

## Build
To build the project from source, you need to have **dub** installed. If you don't, you can install it by following [these instructions](http://minas-mina.com/2015/08/16/installing-dub/).

To build the project, open a terminal inside the project's root directory and execute
```
dub build
```
## Configuration
To configure which files / folders should be monitor edit "conf.json".

For example, with the following configuration, your _downloads_ and _music_ folders will be synchronized.

```
{
  "directories-to-watch": [
    "C:\\Users\\Minas\\Downloads",
    "C:\\Users\\Minas\\Music"
  ]
}
```

##### Note
You need to set the correct paths for your account.

# License
This project uses GPLv3.
