 -------------------------------------
-- vars --------------
-- Emerald Dream/Grobbulus --------

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
function tracked:refreshConfig( changeset )

  local persistence  	= self:getConfig( )
  local updated 		= false
  --self:_geParenttDB( ):ResetDB( )

  if changeset ~= nil then

  for category, category_rows in pairs( persistence ) do
    if changeset[ category ] then
      for i, row in pairs( category_rows ) do
        if changeset[ category ][ i ] then
          local updated_value = changeset[ category ][ i ][ row[ 'command' ] ]
          local current_value = row[ 'value' ]
          local evaluation 		= current_value ~= '' and strlower( tostring( updated_value ) ) ~= strlower( tostring( current_value ) )
          if evaluation then
            persistence[ category ][ i ][ 'value' ] = updated_value
            updated = true
          end
          persistence[ category ][ i ][ 'tracked' ] = evaluation
        end
      end
    end
  end

  end

  return updated, persistence

end

-- queue configuration
--
-- return bool
function tracked:queueConfig( category, var, value )
  
  local changeset = { }
  local persistence = self:getNameSpace( )
  for cat, rows in pairs( self:getConfig( ) ) do
  	if category == cat then
  	  for i, row in pairs( rows ) do
  	  	if row[ 'command' ] == var then
  	  	  changeset[ category ] = { }
  	  	  changeset[ category ][ i ] = { }
  	  	  changeset[ category ][ i ][ var ] = value
  		    tracked:refreshConfig( changeset )
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
function tracked:applyConfig( category )

  local is_tracked    = false
  local tracked_count = 0
  local message       = ''
  local updated       = false
  local known_vars    = self:getConfig( )
  local can_update    = true

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
  local changeset = {
    current_value = nil,
    default_value = nil,
    new_value = nil,
    index = nil,
  }

  -- file changes
  for i, pending in pairs( tracked[ 'queue' ] ) do
    for category, data in pairs( pending ) do
      for j, setting in pairs( data ) do
        for index, value in pairs( setting ) do
          if known_vars[ category ][ j ] then
            changeset[ 'current_value' ] = tostring( GetCVar( index ) )
            changeset[ 'new_value' ] = tostring( value )
            changeset[ 'index' ] = tostring( index )
          end
        end
      end
    end 
  end

  -- do not allow empty changes
  for index, v in pairs( changeset ) do
    if changeset[ index ] == nil then
      can_update = false
    end
  end

  if not can_update then
    message = 'cannot update'
    vars:warn( message )
    return false, tracked_count, message
  end

  -- do not apply changes already applied
  if strlower( changeset[ 'current_value' ] ) == strlower( changeset[ 'new_value' ] ) then
    message = 'already applied'
    vars:warn( message )
    return false, tracked_count, message
  end

  -- do not apply combat protected during combat
  if tContains( vars:getProtected( 'combat' ), changeset[ 'index' ] ) ~= false and InCombatLockdown( ) == true then
    message = changeset[ 'index' ] .. ' can only be modified outside of combat'
    vars:warn( message )
    return false, tracked_count, message
  end

  -- apply changes
  vars:notify( 'updating ' .. changeset[ 'index' ] .. '...' )
  SetCVar( changeset[ 'index' ], changeset[ 'new_value' ] )

  -- check for error
  if GetCVar( changeset[ 'index' ] ) ~= changeset[ 'new_value' ] then
    message = 'failed'
    vars:error( message )
    return false, tracked_count, message
  end

  -- maintenance
  updated = true
  local new_config = { }
  for cat, rows in pairs( self:getConfig( ) ) do
    if category == cat then
      for i, row in pairs( rows ) do
        if row[ 'command' ] == changeset[ 'index' ] then
          new_config[ category ] = { }
          new_config[ category ][ i ] = { }
          new_config[ category ][ i ][ changeset[ 'index' ] ] = changeset[ 'new_value' ]
          is_tracked = row[ 'tracked' ]
          tracked:refreshConfig( new_config )
        end
      end
    end
  end
  changeset[ 'default_value' ] = GetCVarDefault( changeset[ 'index' ] )

  local new_value_not_default = strlower( changeset[ 'new_value' ] ) ~= strlower( tostring( changeset[ 'default_value' ] ) )
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