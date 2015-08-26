Compilation Unit Addon
======================

Compilation Units is a technique used to speed up compilation of huge projects, by regrouping
compilation unit files (basically the .cpp and .c files) into a few big ones. Basically, instead
of compiling `foo.cpp` and `bar.cpp` you compile a single `foobaz.cpp` one which contains the
following :

```cpp
#include "foo.cpp"
#include "bar.cpp"
```

This technique is based on the one known as [Single Compilation Unit](https://en.wikipedia.org/wiki/Single_Compilation_Unit),
but it allows creating `N` big compilation units, where `N` usually is the number of cores of your CPU.
This allows you to take advantage of parallel compilation, while retaining the huge speed up
introduced by the SCU technique.

How to use
==========

Clone this repository some place where Premake will be able to locate. Then
in your project's Premake script, include the main file like this :

```lua
require( "premake-compilationunit/compilationunit.lua" )
```

Then in the projects where you want to enable support for compilation units :

```lua
compilationunitenabled ( true )
```

The final step is to invoke Premake using the `compilationunit` option:

```
premake5 --compilationunit=8 <action>
```

Here I tell the module to use 8 compilation unit files, for projects where it has
been enabled.

API
===

Most of the API commands of this addon are scoped to the current configuration,
so unless specified otherwise, assume that the documented command only applies
to the current configuration block.

#####compilationunitenabled enabled

Enable or disable the compilation unit generation for the current filter. `enabled`
is a boolean.

#####compilationunitdir "path"

The path where the compilation unit files will be generated. If not specified, the
obj dir will be used. This is a per-project configuration. The addon takes care
of handling the various configurations for you.
