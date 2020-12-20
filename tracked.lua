 -------------------------------------
-- vars --------------
-- jadissa was here --------

-- 
local vars = LibStub( 'AceAddon-3.0' ):GetAddon( 'vars' )
local tracked = vars:NewModule( 'tracked' )

local utility = LibStub:GetLibrary( 'utility' )

-- parent persistence reference
--
-- returns table
function tracked:_geParenttDB( )
  return vars:getDB( )
end

-- persistence namespace
--
-- returns table
function tracked:getNameSpace( )

  return self:_geParenttDB( ):GetNamespace(
  	self:GetName( ) 
  )[ 'profile' ]

end

-- copy configuration
--
-- returns table
function tracked:getConfig( )

  local persistence = self:getNameSpace( )

  -- force initial reset
  local v_hash = vars[ 'build_info' ][ 'tocversion' ] .. '05'
  if persistence[ v_hash ] == nil then
    --vars:wipeDB( )
    persistence[ v_hash ] = true
  end

  -- already built
  if persistence[ 'tracked' ] ~= nil and next( persistence[ 'tracked' ] ) ~= nil then
    return persistence[ 'tracked' ]
  end

  -- needs building
  local known_vars  = vars:buildConfig( )
  persistence[ 'tracked' ] = { }
  for category, category_rows in pairs( known_vars ) do
  	for i, row in pairs( category_rows ) do
      if persistence[ 'tracked' ][ category ] == nil then
        persistence[ 'tracked' ][ category ] = { }
      end
      tinsert( persistence[ 'tracked' ][ category ], { 
        help            = row[ 'help' ],
        command         = row[ 'command' ],
        category        = row[ 'category' ],
        scriptContents  = row[ 'scriptContents' ],
        commandType     = row[ 'commandType' ],
        info            = row[ 'info' ],
        tracked         = row[ 'tracked' ],
        value           = row[ 'value' ],
      } )
    end
  end

  return persistence[ 'tracked' ]

end

-- refresh configuration
-- for a given changeset comprised of category|rowindex|var|value
-- determine if an update is needed within the persistence
--
-- returns bool, table
function tracked:refreshConfig( ui_obj, changeset )

  local persistence  	= self:getConfig( )
  local updated 		= false
  --self:_geParenttDB( ):ResetDB( )

  if changeset ~= nil then

    local default_value = changeset[ 'default_value' ]  -- from changeset
    local updated_value = changeset[ 'new_value' ]      -- from changeset

    local current_value = changeset[ 'current_value' ]  -- from persistence

    local evaluation    = current_value ~= '' and updated_value ~= default_value
    if evaluation then
      persistence[ changeset[ 'category' ] ][ changeset[ 'index' ] ][ 'info'][ 'value' ] = updated_value
      updated = true
    end
    if ui_obj ~= nil then
      -- @todo: tremove() call needed to cause the ui registry a rebuild for this value
      --ui_obj[ 'registry'][ changeset[ 'category' ] .. '|' .. changeset[ 'command' ] ] = nil
    end
    persistence[ changeset[ 'category' ] ][ changeset[ 'index' ] ][ 'tracked' ] = evaluation

  end

  return updated, persistence

end

-- queue configuration
--
-- return bool
function tracked:queueConfig( category, var, value )
  
  local changeset = { }
  for cat, rows in pairs( self:getConfig( ) ) do
  	if category == cat then
  	  for i, row in pairs( rows ) do
  	  	if row[ 'command' ] == var then

          changeset = {
            category = category,
            index = i,
            command = row[ 'command' ],
            default_value = strlower( tostring( row[ 'info' ][ 'defaultValue' ] ) ),
            current_value = strlower( tostring( row[ 'info' ][ 'value' ] ) ),
            new_value = strlower( tostring( value ) ),
          }
		      if not tracked[ 'queue' ] then
		  	    tracked[ 'queue' ] = { }
		      end
  		    tinsert( tracked[ 'queue' ], changeset )
  	  	end
  	  end
  	end
  end

  return changeset ~= nil

end

-- update system
-- CVar and stats application
--
-- returns bool, number, string
function tracked:applyConfig( ui_obj, category )

  local is_tracked    = false
  local tracked_count = 0
  local message       = ''
  local updated       = false
  local known_vars    = self:getConfig( )

  -- determine how many are modified already
  for cat, rows in pairs( known_vars ) do
    if type( rows ) == 'table' then
      for i, row in pairs( rows ) do
        if row[ 'tracked' ] == true then
          tracked_count = tracked_count + 1
        end
      end
    end
  end

  -- initialize changes
  local changeset = tracked[ 'queue' ][ next( tracked[ 'queue' ] ) ]

  -- do not allow empty changes
  if changeset[ 'new_value' ] == nil then
    message = 'cannot update'
    vars:warn( message )
    return false, tracked_count, message
  end

  -- do not apply changes already applied
  if changeset[ 'current_value' ] == changeset[ 'new_value' ] then
    message = 'already applied'
    vars:warn( message )
    return false, tracked_count, message
  end

  -- do not apply combat protected during combat
  if tContains( vars:getProtected( 'combat' ), changeset[ 'command' ] ) ~= false and InCombatLockdown( ) == true then
    message = changeset[ 'command' ] .. ' can only be modified outside of combat'
    vars:warn( message )
    return false, tracked_count, message
  end

  -- apply changes
  vars:notify( 'updating ' .. changeset[ 'command' ] .. '...' )
  SetCVar( changeset[ 'command' ], changeset[ 'new_value' ] )


  -- check for error
  if strlower( tostring( GetCVar( changeset[ 'command' ] ) ) ) ~= changeset[ 'new_value' ] then
    message = 'failed'
    vars:error( message )
    return false, tracked_count, message
  end

  -- maintenance
  updated = true
  tracked:refreshConfig( ui_obj, changeset )

  local new_value_not_default = changeset[ 'new_value' ] ~= changeset[ 'default_value' ]
  if new_value_not_default == true and is_tracked == false then
    tracked_count = tracked_count + 1
  elseif new_value_not_default == false and is_tracked == true then
    tracked_count = tracked_count - 1
  end
  vars:notify( 'updated from: ' .. changeset[ 'current_value' ] .. ' to: ' .. changeset[ 'new_value' ] )
  tracked[ 'queue' ] = { }
  local persistence = self:getNameSpace( )
  if persistence[ 'options' ][ 'reloadgx' ] and updated then 
  	RestartGx( )
  end
  if persistence[ 'options' ][ 'reloadui' ] and updated then 
    ReloadUI( )
  end
  
  return updated, tracked_count, message

end

-- mark config rows as modified/tracked or not
-- 
-- return string
function tracked:indicate( value )
  if value == true then 
    return 'modified' 
  else 
    return 'default' 
  end
end

-- toggle synch to blizz hq
-- 
-- return bool
function tracked:cloudSync( state )

  local current_state = GetCVar( 'synchronizeConfig' )
  if state ~= current_state then
    SetCVar( 'synchronizeConfig', state )
    if GetCVar( 'synchronizeConfig' ) ~= state then
      return false
    else 
      return true
    end
  end

end

-- setup tracking
--
-- return void
function tracked:init( )
  self:getConfig( )
end

-- register persistence
--
-- returns void
function tracked:OnInitialize( )

  local defaults = { }
  defaults[ 'profile' ] = { }
  defaults[ 'profile' ][ 'tracked' ]  = nil
  defaults[ 'profile' ][ 'search' ]   = { }
  defaults[ 'profile' ][ 'options' ]  = { }
  defaults[ 'profile' ][ 'search' ][ 'category_filter' ]  = 'Game'
  defaults[ 'profile' ][ 'search' ][ 'staus_filter' ]     = 'all'
  defaults[ 'profile' ][ 'search' ][ 'text' ]             = nil
  defaults[ 'profile' ][ 'search' ][ 'sort_direction' ]   = 'asc'
  defaults[ 'profile' ][ 'search' ][ 'remember' ]         = true

  defaults[ 'profile' ][ 'options' ]  = { }
  defaults[ 'profile' ][ 'options' ][ 'reloadgx' ]  = true
  defaults[ 'profile' ][ 'options' ][ 'reloadui' ]  = false
  defaults[ 'profile' ][ 'options' ][ 'cloudsync' ] = true
  defaults[ 'profile' ][ 'db' ] = { }
  defaults[ 'profile' ][ 'db' ][ 'was_reset' ] = false

  self:_geParenttDB( ):RegisterNamespace(
  	self:GetName( ), defaults
  )
  self:Enable( )

end

-- activated module handler
--
-- returns void
function tracked:OnEnable( )

  self:init( )
  
end