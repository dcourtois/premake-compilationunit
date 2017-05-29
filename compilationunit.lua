

--
-- always include _preload so that the module works even when not embedded.
--
if premake.extensions == nil or premake.extensions.compilationunit == nil then
	include ( "_preload.lua" )
end


--
-- define the extension
--
premake.extensions.compilationunit = {

	--
	-- these are private, do not touch
	--
	compilationunitname = "__compilation_unit__",
	numcompilationunits = 8,
	compilationunits = {}

}


--
-- This method overrides premake.oven.bakeFiles method. We use it to add the compilation units
-- to the project.
--
function premake.extensions.compilationunit.customBakeFiles(base, prj)

	-- if compilation units are disabled for this project, do nothing
	if prj.compilationunitenabled ~= true or prj.external == true then
		return base(prj)
	end

	local project = premake.project
	local cu = premake.extensions.compilationunit

	for cfg in project.eachconfig(prj) do

		-- initialize the compilation unit structure for this config
		cu.compilationunits[cfg] = {}

		-- remove the previous compilation units
		for i = #cfg.files, 1, -1 do
			if cu.isCompilationUnit(cfg, cfg.files[i]) then
				table.remove(cfg.files, i)
			end
		end

		-- store the list of files for a later building of the actual compilation unit files
		table.foreachi(cfg.files, function(filename)
			if cu.isIncludedInCompilationUnit(cfg, filename) == true then
				table.insert(cu.compilationunits[cfg], filename)
			end
		end)

		-- store the compilation unit folder in the config
		if cfg._compilationUnitDir == nil then
			cfg._compilationUnitDir = cu.getCompilationUnitDir(cfg)
		end

		-- add the compilation units for premake
		for i = 1, cu.numcompilationunits do
			table.insert(cfg.files, path.join(cfg._compilationUnitDir, cu.getCompilationUnitName(cfg, i)))
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
	if cu.isIncludedInCompilationUnit(cfg, filename) == true and cu.isCompilationUnit(cfg, filename) == false then
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
			-- add pch if needed
			local content = ""
			if config.pchheader ~= nil then
				content = content .. "#include \"" .. config.pchheader .. "\"\n\n"
			end

			-- add the unit
			table.insert(units, {
				filename = path.join(config._compilationUnitDir, cu.getCompilationUnitName(config, i)),
				content = content
			})
		end

		-- add files in the cpp unit
		local index = 1
		for _, filename in ipairs(files) do
			-- compute the relative path of the original file, to add the #include statement
			-- in the compilation unit
			local relativefilename = path.getrelative(path.getdirectory(units[index].filename), path.getdirectory(filename))
			relativefilename = path.join(relativefilename, path.getname(filename))
			units[index].content = units[index].content .. "#include \"" .. relativefilename .. "\"\n"
			index = (index % cu.numcompilationunits) + 1
		end

		-- write units
		for _, unit in ipairs(units) do
			-- get the content of the file, if it already exists
			local file = io.open(unit.filename, "r")
			local content = ""
			if file ~= nil then
				content = file:read("*all")
				file:close()
			end

			-- overwrite only if the content changed
			if content ~= unit.content then
				file = io.open(unit.filename, "w")
				file:write(unit.content)
				file:close()
			end
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

	-- in this order:
	--	- check if compilationunitdir is used
	--	- if not, if we have an objdir set, use it
	--	- if not, re-create the obj dir like the default Premake one.

	local dir = ""
	if cfg.compilationunitdir then
		dir = cfg.compilationunitdir
	else
		if cfg.objdir then
			return cfg.objdir
		else
			dir = path.join(cfg.project.location, "obj")
		end
	end

	if cfg.platform then
		dir = path.join(dir, cfg.platform)
	end
	dir = path.join(dir, cfg.buildcfg)
	dir = path.join(dir, cfg.project.name)
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
	return premake.extensions.compilationunit.compilationunitname .. index .. iif(cfg.language == "C", ".c", ".cpp")
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
	return path.getname(absfilename):startswith(premake.extensions.compilationunit.compilationunitname)
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
