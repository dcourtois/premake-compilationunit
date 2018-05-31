
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
-- Always load
--
return function () return true end
