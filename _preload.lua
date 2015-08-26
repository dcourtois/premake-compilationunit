
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
-- unit files will be stored. This is mandatory
--
-- Also please note that it's strongly advised to avoid using a folder which is in your
-- "normal" source tree : if you run premake twice, those unit files will be included
-- in the project, as normal files the second time, which might lead to some "recursive"
-- inclusions
--
-- So, assuming in you script you have this :
--
--             files { "src/**" }
--
-- It's advised to use something like this for the compilation unit directory :
--
--             compilationunitdir "compilation_units"
--             -- don't do this : compilationunitdir "src/compilation_units" !
--
premake.api.register {
       name = "compilationunitdir",
       scope = "config",
       kind = "path",
       tokens = true
}


--
-- Always load
--
return true
