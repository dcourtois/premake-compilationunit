

--
-- always include _preload so that the module works even when not embedded.
--
include ( "_preload.lua" )


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
-- This method overrides premake.oven.bakeFiles method. We use it to add the compilation units
-- to the project.
--
function premake.extensions.compilationunit.customBakeFiles(base, prj)

	-- if compilation units are disabled for this project, do nothing
	if prj.compilationunitenabled ~= true then
		return base(prj)
	end

	-- check that the folder in which to generate the compilation units is defined
	if prj.compilationunitdir == nil then
		premake.warn("compilationunitdir is not set for this project, compilation units will be disabled.")
		prj.compilationunitenabled = false
		return base(prj)
	end

	local project = premake.project
	local cu = premake.extensions.compilationunit

	for cfg in project.eachconfig(prj) do

		-- initialize the compilation unit structure for this config
		cu.compilationunits[cfg] = {}

		-- store the list of files for a later building of the actual compilation unit files
		table.foreachi(cfg.files, function(filename)
			if cu.isIncludedInCompilationUnit(cfg, filename) == true then
				table.insert(cu.compilationunits[cfg], filename)
			end
		end)

		-- add the compilation units for premake
		for i = 1, cu.numcompilationunits do
			table.insert(cfg.files, path.join(cu.getCompilationUnitDir(cfg), cu.getCompilationUnitName(cfg, i)))
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
	local cu = premake.extensions.compilationunit

	-- do nothing else if the compilation units are not enabled for this project
	if cfg.compilationunitenabled == nil or cu.compilationunits[cfg] == nil then
		return
	end

	-- get the file configuration object
	local config = premake.fileconfig.getconfig(fcfg, cfg)

	-- set the final filename
	local filename = fcfg.abspath

	-- if a file will be included in the compilation units, disable it
	if cu.isIncludedInCompilationUnit(cfg, filename) == true then
		config.flags.ExcludeFromBuild = true
	end

	-- if the file is disabled, remove it from the compilation units list
	-- note: this is done here and not in the previous test to handle files
	-- that were disabled by the user.
	if config.flags.ExcludeFromBuild == true then
		if cu.compilationunits[cfg][filename] ~= nil then
			cu.compilationunits[cfg][filename] = nil
		end
	end

end

--
-- Overrides the premake.oven.bakeConfigs method which happens at the last step of the baking
-- process. I use this to actually generate the compilation units.
--
function premake.extensions.compilationunit.customBakeConfigs(base, sln)

	-- get the addon
	local cu = premake.extensions.compilationunit

	-- loop through the configs
	for config, files in pairs(cu.compilationunits) do

		-- create the units
		local units = {}
		for i = 1, cu.numcompilationunits do
			local filename = path.join(cu.getCompilationUnitDir(config), cu.getCompilationUnitName(config, i))
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
			index = (index % cu.numcompilationunits) + 1
		end

		-- close units
		for _, unit in ipairs(units) do
			unit.file:close()
		end

	end

	-- execute the overriden method
	return base(sln)

end

function premake.extensions.compilationunit.isIncludedInCompilationUnit(cfg, filename)

	-- only handle source files
	if path.iscfile(filename) == false and path.iscppfile(filename) == false then
		return false
	end

	local cu = premake.extensions.compilationunit

	-- ignore PCH files
	if cu.isPCHSource(cfg, filename) == true then
		return false
	end

	-- ignore the compilation units files
	if cu.isCompilationUnit(cfg, filename) == true then
		return false
	end

	-- it's ok !
	return true
end


--
-- Get the compilation unit output directory
--
-- @param cfg
--		The input configuration
--
function premake.extensions.compilationunit.getCompilationUnitDir(cfg)

	-- get the objdir
	local dir = cfg.compilationunitdir

	-- add the platform and build cfg to make it unique
	if cfg.platform then
		dir = path.join(dir, cfg.platform)
	end
	dir = path.join(dir, cfg.buildcfg)
	return path.getabsolute(dir)

end


--
-- Get the name of a compilation unit
--
-- @param cfg
--		The configuration for which we want the compilation unit's filename
-- @param index
--		The index of the compilation unit
-- @return
--		The name of the file.
--
function premake.extensions.compilationunit.getCompilationUnitName(cfg, index, shortName)
	return "__compilation_unit_" .. index .. iif(cfg.language == "C", ".c", ".cpp")
end


--
-- Checks if an absolute filename is a compilation unit..
--
-- @param cfg
--		The current configuration
-- @param absfilename
--		The absolute filename of the file to check
-- @return
-- 		true if the file is a compilation unit, false otherwise
--
function premake.extensions.compilationunit.isCompilationUnit(cfg, absfilename)
	return path.getname(absfilename):startswith("__compilation_unit_")
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
-- If the compilationunit option was used, activate the addon
--
if _OPTIONS["compilationunit"] ~= nil then

	local cu = premake.extensions.compilationunit

	-- store the number of compilation units
	cu.numcompilationunits = tonumber(_OPTIONS["compilationunit"])
	if cu.numcompilationunits == nil then
		error("value for option 'compilationunit' must be a valid number")
	end

	-- setup the overrides
	premake.override(premake.oven, "bakeFiles", cu.customBakeFiles)
	premake.override(premake.fileconfig, "addconfig",  cu.customAddFileConfig)
	premake.override(premake.oven, "bakeConfigs", cu.customBakeConfigs)

end
