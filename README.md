# Macbit

Macbit aims to solve mac development issues in a bit level.

## Usage
```
make all
./macbit -s __launchd_plist -p helper-Launchd.plist com.example.mac.helper
./macbit -p helper-Info.plist com.example.mac.helper
codesign ...
```
## Options
* `-p PLIST_FILE_PATH`
* `-s SECTNAME`: Specify sectname of the new `__TEXT` segment which will be injected, by default, `__info_plist`
* `-m`: Add a new segment/section instead of just a section

## Why `macbit`
A plist file acts as the declaration of identification, permission, and many other things in modern macos security system.

In order to install a privileged helper for a Mac application (https://developer.apple.com/library/archive/documentation/Security/Conceptual/SecureCodingGuide/Articles/AccessControl.html), the priviledged helper has to include two plist files and be codesigned.

This is OK when you write the privileged helper with swift or have a way to import helper project into XCode and let XCode to do the whole compliation.

However, in many cases, the helper has to be kept standalone, staying away from XCode system for many reaons:
* This project can't be compiled by XCode.
* XCode is slow, keeping the development of the helper standalone largely improves development efficiency.

All of these reasons pushed me to discover a solution to do the work just as XCode and keep the development away from XCode.

It took a long time for my research in the web, but I finally discovered a repo named [GimmeDebugah](https://github.com/gdbinit/gimmedebugah) which hasn't been updated for the past 7 years, but very close to the solution.

After played a while of `GimmeDebugah`, it seems to solve the issue in a basic level but cant' make forward if the program is not reshaped.

This is what `GimmeDebugah` does:
* Find the address right after `__TEXT` and `__DATA`, which is the free space to add sections and data, let's name it `ADDR_B`.
* Find the lowest boundary of the free space (`ADDR_E`).
* Calculate the size of the section and data (equals to the size of section determined by OS platform plus the size of plist) to be added, and compare it with the size of free space (`ADDR_E - ADDR_B`)
* If size is larger than the size of free space, then program terminates, otherwise, it will do injection.

The downside of `GimmeDebugah` is that when you want to inject another plist file again, the lowest bondary become the end address of the last injected data. Thus, the free space size become `0` and the program terminates.

However, what I have encountered is to inject both `info.plist` and `launchd.plist` into a standalone program which will then be codesigned and act as a launch daemon in the privileged tool folder (`/Library/PrivilegedHelperTools`).

The core trick to do muliple injections is to put the injected data at the end of the free space.

Besides that, other fixes has to be made in order to make the injection work perfectly, for example:
* Calculate the exact address of data and put it into the new section.
* Provide more command options.

So I hacked `GimmeDebugah` and made this project named `macbit`, which be actively maintained and will hopefully help developers solve their modern mac development issues.

At the end, great thanks to `GimmeDebugah`, there is no `macbit` without your work done seven years ago.

## Original REAMDE of [GimmeDebugah](https://github.com/gdbinit/gimmedebugah)

This is a small utility to inject a Info.plist into binaries with enough free
 space at the Mach-O header.

The reason for this is that taskgated has a new default setting in Mountain
Lion. Non-privileged binaries that want to execute task_for_pid() for arbitrary
applications must be codesigned and have some the SecTaskAccess key set in Info
.plist SecTaskAccess. This is easy for bundled binaries but not for isolated
binaries.

If target binary is compiled from source code, the Info.plist can be embedded
in the binary using the compiler option `--sectcreate __TEXT __info_plist
path_to/Info.plist`. This is not possible if we only have the a binary
verstion, for example, the default python install.
One possible workaround is to revert taskgated to the old procmod behavior (
man taskgated for details). This is marked as deprecated and who knows when
Apple will remove it for good.

We can fix this by injecting the required section into the binary.
Taskgated binary is linked to the Security framework, which is responsible for
reading the embedded Info.plist.

Code located at libsecurity_codesigning/lib/machorep.cpp (Security-* package
from http://opensource.apple.com)

```c
//
// Extract an embedded Info.plist from the file.
// Returns NULL if none is found.
//
CFDataRef MachORep::infoPlist()
{
        CFRef<CFDataRef> info;
        try {
                auto_ptr<MachO> macho(mainExecutableImage()->architecture());
                if (const section *sect = macho->findSection("__TEXT",
                "__info_plist")) {
                        if (macho->is64()) {
                                const section_64 *sect64 = reinterpret_cast<
                                const section_64 *>(sect);
                                info.take(macho->dataAt(macho->flip(sect64->
                                offset), macho->flip(sect64->size)));
                        } else {
                                info.take(macho->dataAt(macho->flip(sect->
                                offset), macho->flip(sect->size)));
                        }
                }
        } catch (...) {
                secdebug("machorep", "exception reading embedded Info.plist");
        }
        return info.yield();
}
```

The framework lookups the __TEXT segment and __info_plist section and reads it.
One way to deal with this is to inject a new segment command with the same
__TEXT name and with the required section pointing to somewhere in the binary.
My solution is to embedded the Info.plist also in the header free space. The
reason for this is that codesign doesn't seem to like if we add this data to
the end of the binary - it will trigger some check conditions and fail to sign
the binary.

Because the data is added in the header the target binary must be signed
before this util is used. Else the codesign util will see the data located
there and complain there is no free space to add the code signature.
Workflow is:

1. Sign the target binary, if it's not.
2. Run this util against the target binary.
3. Resign the binary to update the header's modifications.

The Info.plist format should be something like this:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple
.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>CFBundleDevelopmentRegion</key>
        <string>English</string>
        <key>CFBundleIdentifier</key>
        <string>com.apple.taskforpid</string>
        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>
        <key>CFBundleName</key>
        <string>taskforpid</string>
        <key>CFBundleVersion</key>
        <string>1.0</string>
        <key>SecTaskAccess</key>
        <array>
          <string>allowed</string>
          <string>debug</string>
        </array>
</dict>
</plist>
```

CFBundleIdentifier and CFBundleName can be modified to target's name although
that's not a requirement.

If you are using a self-signed certificate to do the codesigning you need to
follow this guide from LLDB to create the certificate, else you will run into
annoying problems!
https://llvm.org/svn/llvm-project/lldb/trunk/docs/code-signing.txt

Two modes of operation are available:
- Inject a new segment also called `__TEXT` with the required section.
- Inject only a new section at the existing `__TEXT` segment.

My initial prediction was that the second one wouldn't work but then I decided
to give it a try and works without any problem. It's the default mode since
it is cleaner than mode #1.

Have fun,
fG!

