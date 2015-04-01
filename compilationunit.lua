
--
-- define the extension
--
premake.extensions.compilationunit = {

	--
	-- these are private, do not touch
	--
	numcompilationunits = 8,
	compilationunits = {}

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
-- unit files will be stored. This is mandatory.
--
-- Also please note that it's strongly advised to avoid using a folder which is in your
-- "normal" source tree : if you run premake twice, those unit files will be included
-- in the project, as normal files the second time, which might lead to some "recursive"
-- inclusions.
--
-- So, assuming in you script you have this :
--
--		files { "src/**" }
--
-- It's advised to use something like this for the compilation unit directory :
--
--		compilationunitdir "compilation_units"
--		-- don't do this : compilationunitdir "src/compilation_units" !
--
premake.api.register {
	name = "compilationunitdir",
	scope = "config",
	kind = "path",
	tokens = true
}


--
-- register our custom option
--
newoption {
	trigger = "compilationunit",
	value = 8,
	description = "generate a project which uses N compilation units. Defaults to 8 units."
}


--
-- This method overrides premake.oven.bakeFiles method. We use it to add the compilation units
-- to the project.
--
function premake.extensions.compilationunit.customBakeFiles(base, prj)

	-- check that the folder in which to generate the compilation units is defined
--	if prj.compilationunitdir == nil then
--		premake.warn("compilationunitdir is not set for this project, compilation units will be disabled.")
--		return base(prj)
--	end
	if prj.compilationunitenabled ~= true then
		return base(prj)
	end

	local project = premake.project
	local compilationunit = premake.extensions.compilationunit

	for cfg in project.eachconfig(prj) do

		-- initialize the compilation unit structure for this config
		compilationunit.compilationunits[cfg] = {}

		-- store the list of files for later building of the actual compilation unit files
		table.foreachi(cfg.files, function(filename)
			if compilationunit.isPCHSource(cfg, filename) == false and (path.iscfile(filename) == true or path.iscppfile(filename) == true)then
				table.insert(compilationunit.compilationunits[cfg], filename)
			end
		end)

		-- add the compilation units for premake
		for i = 1, compilationunit.numcompilationunits do
			print("foo")
			table.insert(cfg.files, compilationunit.getCompilationUnitFilename(cfg, i, true))
			print("bar")
		end
	end

	return base(prj)
end


--
-- This method overrides premake.fileconfig.addconfig and adds a file configuration object
-- for each file, on each configuration. We use it to disable compilation of non-compilation
-- units files.
--
function premake.extensions.compilationunit.customAddFileConfig(base, fcfg, cfg)

	-- call the base method to add the file config
	base(fcfg, cfg)

	-- get the addon
	local compilationunit = premake.extensions.compilationunit

	-- do nothing else if the compilation units are not enabled for this project
	if cfg.compilationunitenabled == nil or compilationunit.compilationunits[cfg] == nil then
		return
	end

	-- get the file configuration object
	local config = premake.fileconfig.getconfig(fcfg, cfg)

	-- set the final filename
	local filename = fcfg.abspath
	print(filename)

	-- disable compilation of c/cpp files which are not compilation units, and not the PCH source
	if (path.iscfile(filename) == true or path.iscppfile(filename) == true) and compilationunit.isCompilationUnit(cfg, filename) == false and compilationunit.isPCHSource(cfg, filename) == false then
		config.flags.ExcludeFromBuild = true
	end

	-- if the file is disabled, remove it from the compilation units list
	if config.flags.ExcludeFromBuild == true then
		if compilationunit.compilationunits[cfg][filename] ~= nil then
			compilationunit.compilationunits[cfg][filename] = nil
		end
	end

end

--
-- Overrides the premake.oven.bakeConfigs method which happens at the last step of the baking
-- process. I use this to actually generate the compilation units.
--
function premake.extensions.compilationunit.customBakeConfigs(base, sln)

	-- get the addon
	local compilationunit = premake.extensions.compilationunit

	-- loop through the configs
	for config, files in pairs(compilationunit.compilationunits) do

		-- create the units
		local units = {}
		for i = 1, compilationunit.numcompilationunits do
			local filename = compilationunit.getCompilationUnitFilename(config, i, false)
			local file = io.open(filename, "w")
			table.insert(units, {
				filename = filename,
				file = file
			})

			-- add pch if needed
			if config.pchheader ~= nil then
				file:write("#include \"" .. config.pchheader .. "\"\n\n")
			end
		end

		-- add files in the cpp unit
		local index = 1
		for _, filename in ipairs(files) do
			-- compute the relative path of the original file, to add the #include statement
			-- in the compilation unit
			local relativefilename = path.getrelative(path.getdirectory(units[index].filename), path.getdirectory(filename))
			relativefilename = relativefilename .. "/" .. path.getname(filename)
			units[index].file:write("#include \"" .. relativefilename .. "\"\n")
			index = (index % compilationunit.numcompilationunits) + 1
		end

		-- close units
		for _, unit in ipairs(units) do
			unit.file:close()
		end

	end

	-- execute the overriden method
	return base(sln)

end


--
-- Checks if an absolute filename is a compilation unit. Note that this method is
-- based on the value of `compilationunitdir`. If you change it, the next run won't
-- be able to detect the compilation units with this method. See the doc for the
-- API command `compilationunitdir` for the recommanded use.
--
-- @param cfg
--		The current configuration
-- @param absfilename
--		The absolute filename of the file to check
-- @return
-- 		true if the file is a compilation unit, false otherwise
--
function premake.extensions.compilationunit.isCompilationUnit(cfg, absfilename)
	-- return string.sub(absfilename, 1, string.len(cfg.compilationunitdir)) == cfg.compilationunitdir
	return string.sub(absfilename, 1, string.len("<compilationunitdir>")) == "<compilationunitdir>"
end


--
-- Checks if a file is the PCH source.
--
-- @param cfg
--		The current configuration
-- @param absfilename
--		The absolute filename of the file to check
-- @return
-- 		true if the file is the PCH source, false otherwise
--
function premake.extensions.compilationunit.isPCHSource(cfg, absfilename)
	return cfg.pchsource ~= nil and cfg.pchsource:lower() == absfilename:lower()
end


--
-- Get the full name of a compilation unit
--
-- @param cfg
--		The configuration for which we want the compilation unit's filename
-- @param index
--		The index of the compilation unit
-- @param shortName
--		A boolean. If true, this will return a sort of hash based on the config
--		and the index. This is used to identify a file without have to use the
--		compilationunitdir API, which can contain tokens (those need to be
--		evaluated later)
-- @return
--		The full file name or a sort of hash if shortName was true.
--
function premake.extensions.compilationunit.getCompilationUnitFilename(cfg, index, shortName)
	local ext = iif(cfg.language == "C", ".c", ".cpp")
	if shortName == true then
		return "<compilationunitdir>/" .. cfg.architecture .. "/" .. cfg.buildcfg .. "/compilationunit" .. index .. ext
	else
		return cfg.compilationunitdir .. "/" .. cfg.architecture .. "/" .. cfg.buildcfg .. "/compilationunit" .. index .. ext
	end
end


--
-- If the compilationunit option was used, activate the addon
--
if _OPTIONS["compilationunit"] ~= nil then

	local compilationunit = premake.extensions.compilationunit

	-- store the number of compilation units
	compilationunit.numcompilationunits = tonumber(_OPTIONS["compilationunit"])
	if compilationunit.numcompilationunits == nil then
		error("value for option 'compilationunit' must be a valid number")
	end

	-- setup the overrides
	premake.override(premake.oven, "bakeFiles", compilationunit.customBakeFiles)
	premake.override(premake.fileconfig, "addconfig",  compilationunit.customAddFileConfig)
	premake.override(premake.oven, "bakeConfigs", compilationunit.customBakeConfigs)

end
