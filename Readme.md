Compilation Unit Addon
======================

Compilation Units is a technique used to speed up compilation of huge projects, by regrouping
compilation unit files (basically the .cpp and .c files) into a few big ones. Basically, instead
of compiling `foo.cpp` and `bar.cpp` you compile a single `foobaz.cpp` one which contains the
following :

	:::cpp
	#include "foo.cpp"
	#include "bar.cpp"

This technique is based on the one known as [Single Compilation Unit](https://en.wikipedia.org/wiki/Single_Compilation_Unit),
but it allows creating `N` big compilation units, where `N` usually is the number of cores of your CPU.
This allows you to take advantage of parallel compilation, while retaining the huge speed up
introduced by the SCU technique.

How to use
==========

First, put the `compilationunit.lua` file somewhere accessible. Then, in your project's premake
script, insert this at the beginning :

	:::lua
	include "compilationunit.lua"

Then in the projects where you want to enable support for compilation units :

	:::lua
	compilationunitdir "somedirectory"

Note : `somedirectory` is the directory where you want the addon to place the generated compilation
units. This should be outside the usual source tree, because if you generate your project again,
the script will include your previously generated compilation unit files as "normal" ones.
There is a basic support for this in the addon code, but in some cases the addon might fail
detecting those special files, and it will do some weird stuff :)

So here is an example of what you should and shouldn't do :

	:::lua
	-- this is ok
	files { "src/**" }
	compilationunitdir "compilation_units/"
	
	-- this is *not* ok !
	-- if you do that once, the addon will generate the files in this folder.
	-- then the next time you run this script, those generated files will be
	-- included by the 'files' command.
	files { "src/**" }
	compilationunitdir "src/compilation_units/"

And finally, just add the option `--compilationunit=x` to your premake command line. This will
generate the project using the technique, using `x` number of compilation unit files. I recommand
using the number of cores of your processor as the number of compilation files.

If you don't specify the option, the project is generated as usual.
