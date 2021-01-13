lua-linenoise
===========

This project is a combination of the lua-linenoise binding by Rob Hoelz [here](https://github.com/hoelzro/lua-linenoise) and the linenoise version by Steve Bennett [here](https://github.com/msteveb/linenoise) .

## Why?
The original lua-linenoise uses the linenoise version by yhirose from [here](https://github.com/yhirose/linenoise/tree/utf8-support) . It has the disadvantage that it is not so easy to build for Windows. The excellent version by Steve Bennett includes all the functions from the original antirez version including hints. It also adds UTF-8 compatibility and works great on Windows (tested on Win7 and Win10).

## Quickstart

The [releases](https://github.com/muhkuh-sys/com.github.hoelzro-lua-linenoise/releases) have complete examples with a LUA interpreter for Windows and some Ubuntu versions. Download and extract the archive for your platform.

Please note that there are archives for 2 different versions of the LUA interpreter: LUA5.1 and LUA5.4 . The example code in both versions are the same. Pick the interpreter version you are familiar with. If you are in doubt, I recommend the latest and greatest LUA5.4 .

The archive has 2 examples: "mini" and "tool". Start them with...

```sh
./lua5.1 mini.lua
```
or 
```sh
./lua5.1 tool.lua
```

for the LUA5.1 version and

```sh
./lua5.4 mini.lua
```
or 
```sh
./lua5.4 tool.lua
```
for the LUA5.4 version.

## Changes to lua-linenoise

As Steve Bennetts version has a few small API differences to the original linenoise, some changes to lua-linenoise were necessary:

* The completer and hints callbacks got a user data parameter. I decided to keep this internal to lua-linenoise, so the changes have no effect on the LUA API.
* UTF-8 support is activated at compile time. The version from yhirose did this with a function in runtime. To keep things simple, UFT-8 was enabled at compile time and the "enableutf8" function was removed.
* The function "printkeycodes" was not available, so it was also removed.

Apart from these small changes, everything still works as described [here](https://github.com/hoelzro/lua-linenoise#usage) .
