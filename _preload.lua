
--
-- avoid loading twice this file (see compilationunit.lua)
--
premake.extensions.compilationunit = true


--
-- register our custom option
--
newoption {
	trigger = "compilationunit",
	value = 8,
	description = "Generate a project which uses N compilation units. Defaults to 8 units."
}


--
-- Enable the compilation units for a given configuration
--
premake.api.register {
	name = "compilationunitenabled",
	scope = "config",
	kind = "boolean"
}


--
-- Specify the path, relative to the current script or absolute, where the compilation
-- unit files will be stored. If not specified, the project's obj dir will be used.
--
premake.api.register {
	name = "compilationunitdir",
	scope = "project",
	kind = "path",
	tokens = true
}

-- Compilation unit extensions.
--
-- By default, either .c or .cpp extension are used for generated compilation units.
-- But you can override this extension per-language to let it handle objective-C or
-- any other.
--
-- Here's an example allowing to mix C or C++ files with objective-C:
-- 
-- filter {}
-- 	compilationunitextensions {
--		"C" = ".m",	-- compilation unit extension for C files is .m
--				-- (i.e. objective-C)
--		"C++" = ".mm"	-- compilation unit extension for C++ files is .mm
--				-- (i.e. objective-C++)
--	}
--
premake.api.register {
	name = "compilationunitextensions",
	scope = "config",
	kind = "table"
}

--
-- Tell if the original source files must be removed from the project (true), thus
-- keeping only the the generated compilation units, or if all files are kept (false).
--
-- Default is to keep the original source files.
--
premake.api.register {
	name = "compilationunitsonly",
	scope = "config",
	kind = "boolean"
}

--
-- This command can be used to insert a header text to the beginning of each generated
-- compilation unit.
--
premake.api.register {
	name = "compilationunitheader",
	scope = "config",
	kind = "string"
}

--
-- Always load
--
return function () return true end
