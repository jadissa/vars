 -------------------------------------
-- vars --------------
-- Emerald Dream/Grobbulus --------
 
-- 
local altered = false
local vars = LibStub( 'AceAddon-3.0' ):GetAddon( 'vars' )
local ui = vars:NewModule( 'ui', 'AceConsole-3.0' )
local tracked = vars:GetModule( 'tracked' )
local frame = nil
local list = { } 

local utility = LibStub:GetLibrary( 'utility' )

-- setup addon
--
-- returns void
function ui:init( )
  self:RegisterChatCommand( 'vc', 'toggle' )
  vars:notify( 'activated. /vc to use')
  self[ 'registry'] = { }
end

-- toggle slash handler
-- 
-- returns void
function ui:toggle( )

  local menu = frame or self:createMenu( )
  menu:SetShown( not menu:IsShown() )

end

-- create list of category vars 
-- index each with an integer
--
-- returns table
function ui:dataPreProcess( )

  local t = { }
  local persistence = tracked:getNameSpace( )
  self[ 'registry' ][ 'tracked_count' ] = 0
  self[ 'registry' ][ 'vars_count' ] = 0
  self[ 'registry' ][ 'locked_count' ] = 0

  for category, category_data in pairs( tracked:getConfig( ) ) do
    for i, row in pairs( category_data ) do
      if ui[ 'registry'][ category .. '|' .. row[ 'command' ] ] ~= nil then
        ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'var' ]:Hide( )
        ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'scope' ]:Hide( )
        ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'sep' ]:Hide( )
        ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'edit' ]:Hide( )
        ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'edit' ]:UnregisterAllEvents( )
        ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'help' ]:Hide( )
      end
      if row[ 'tracked' ] == true then
        self[ 'registry' ][ 'tracked_count' ] = self[ 'registry' ][ 'tracked_count' ] + 1
      end
      if row[ 'info' ][ 'readOnly' ] == true then
        self[ 'registry' ][ 'locked_count' ]  = self[ 'registry' ][ 'locked_count' ] + 1
      end
      self[ 'registry' ][ 'vars_count' ] = self[ 'registry' ][ 'vars_count' ] + 1
    end

    if category == persistence[ 'search' ][ 'category_filter' ] then
      for i, row in pairs( category_data ) do
        if persistence[ 'search' ][ 'staus_filter' ] == 'all' then
          t[ i ] = row[ 'command' ]
        end
        if persistence[ 'search' ][ 'staus_filter' ] == 'tracked' and row[ 'tracked' ] == true then
          t[ i ] = row[ 'command' ]
        elseif persistence[ 'search' ][ 'staus_filter' ] == 'default' and row[ 'tracked' ] == false then
          t[ i ] = row[ 'command' ]
        end
      end
    end
  end

  return t

end

-- filters main list via search options
--
-- returns table
function ui:filterList( )

  local t = { }

  local persistence   = tracked:getNameSpace( )
  local category      = persistence[ 'search' ][ 'category_filter' ]
  local search_string = persistence[ 'search' ][ 'text' ]
  local data          = self:dataPreProcess( )
  local frames        = vars:GetModule( 'frames' )
  local var_names     = nil

  if search_string ~= nil then
    var_names     = tracked:getConfig( )
  else
    var_names     = frames:sort( data, persistence[ 'search' ][ 'sort_direction' ] )
  end

  if search_string ~= nil then
    for category, category_data in pairs( var_names ) do
      for o, row in pairs( category_data ) do
        local s     = strlower( row[ 'command' ] )

        --[[
        if s == 'mousespeed' then

          utility:dump( row )

        end
        ]]

        local i, j  = string.find( s, search_string )
        if( i ~= nil and i > 0 ) and ( j ~= nil and j > 0 ) then
          if t[ category ] == nil then
            t[ category ] = { }
          end
          t[ category ][ o ] = row
        end
      end
    end

    return t
  end

  for o, var_name in pairs( var_names ) do
    for cat, category_data in pairs( tracked:getConfig( ) ) do
      if cat == category then
        for i, row in pairs( category_data ) do

          --[[
          utility:dump( row['command'] )
          utility:dump( row['info'] )
          ]]

          if row[ 'command' ] == var_name then
            if t[ category ] == nil then
              t[ category ] = { }
            end
            t[ category ][ o ] = row
          end
        end
      end
    end
  end

  return t

end

-- displays filtered list items
--
-- returns void
function ui:iterateList( list, c_type )

  local positions   = { x = 30, y = 0 }
  local frames      = vars:GetModule( 'frames' )

  for category, category_data in pairs( list ) do
    for i, row in pairs( category_data ) do

      if type( row ) == 'table' then

        if ui[ 'registry'][ category .. '|' .. row[ 'command' ] ] == nil then
          local locked = false
          local theme = 'text'
          if row[ 'tracked' ] then
            theme = 'info'
          elseif row['info']['readOnly'] then
            theme = 'error'
            locked = true
          end
          local c = frames:createText( self[ 'menu' ][ 'containers' ][ 1 ], row[ 'command' ], nil, theme )
          c[ 'c_identifier' ] = category .. '|' .. row[ 'command' ]
          c[ 'c_value' ]      = row[ 'command' ]
          c:SetJustifyH( 'right' )
          c:SetSize( 225, 40 )
          local scope
          if row[ 'info' ][ 'character' ] then
            scope = 'character'
          elseif row[ 'info' ][ 'account' ] then
            scope = 'account'
          elseif row['info']['readOnly'] then
            scope = 'locked'
          else
            scope = 'unknown'
          end
          local t = frames:createText( self[ 'menu' ][ 'containers' ][ 1 ], scope, nil, theme )
          t[ 't_identifier' ] = category .. '|' .. row[ 'command' ]
          t[ 't_value' ]      = scope
          ui[ 'registry'][ t[ 't_identifier' ] ] = t
          t:SetJustifyH( 'left' )
          t:SetSize( 55, 40 )

          local s = frames:createSeperator( self[ 'menu' ][ 'containers' ][ 1 ] )
          s:SetPoint( 'topleft', c, 'bottomleft', 10, 0, 0 )

          local v = frames:createEditBox( self[ 'menu' ][ 'containers' ][ 1 ], row[ 'value' ], nil, theme )
          v[ 'v_identifier' ] = category .. '|' .. row[ 'command' ]
          v[ 'v_value' ]      = row[ 'value' ]
          --v:SetCursorPosition( 0 )
          v:SetJustifyH( 'left' )
          v:SetJustifyV( 'top' )
          v:SetSize( 25, 10 )
          v:SetAutoFocus( false )
          if locked == true then
            v:Disable( )
          end

          -- @todo: row['help'] may be defined but somehow only whitespace
          --        this should be accounted for
          local d = frames:createText( self[ 'menu' ][ 'containers' ][ 1 ], row[ 'help' ] or '-', nil, theme )
          d[ 'd_identifier' ] = category .. '|' .. row[ 'command' ]
          d[ 'd_value' ]      = row[ 'help' ]
          d:SetJustifyH( 'left' )
          d:SetSize( 265, 40 )
          d:SetNonSpaceWrap( true )
          d:SetMaxLines( 3 )

          ui[ 'registry'][ category .. '|' .. row[ 'command' ] ] = { }
          ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'var' ] = c
          ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'scope' ] = t
          ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'sep' ] = s
          ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'edit' ] = v
          ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'help' ] = d
          
        end

        ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'var' ]:SetPoint( 
          'topleft', self[ 'menu' ][ 'containers' ][ 1 ], 'topleft', positions[ 'x' ], positions[ 'y' ]
        )
        ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'var' ]:Show( )
        ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'scope' ]:SetPoint(
          'topleft', ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'var' ], 'topright', 15, 0
        )
        ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'scope' ]:Show( )
        ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'sep' ]:SetPoint(
          'topleft', ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'var' ], 'bottomleft', 10, 0, 0
        )
        ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'sep' ]:Show( )

        --handle focus
        ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'edit' ]:SetScript( 
          'OnEditFocusGained', function( self )
          self:HighlightText( )
        end )
        -- or loss thereof
        ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'edit' ]:SetScript(
          'OnEditFocusLost', function( self )
          self:HighlightText( 0,0 )
        end )

        --[[
        -- instruct user
        ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'edit' ]:SetScript(
          'OnTextChanged', function( self )
          ui:updateStats( 
            ui[ 'menu' ], 
            ui[ 'registry' ][ 'vars_count' ], 
            ui[ 'registry' ][ 'tracked_count' ], 
            'value changed. press enter to accept or escape' 
          )
        end )
        ]]

        -- handle modification
        ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'edit' ]:SetScript(
          'OnEnterPressed', function( self )

          local i = gsub( self:GetText(), ' ', '' )
          local c, v = strsplit( '|', self[ 'v_identifier' ] )
          local updated = ui:updateConfig( ui[ 'menu' ], c, v, i )
          self:ClearFocus( )

        end )

        -- handle edit escape
        ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'edit' ]:SetScript(
          'OnEscapePressed', function( self )
          self:SetText( self[ 'v_value' ] )
          self:SetAutoFocus( false )
          self:ClearFocus( )
        end )

        ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'edit' ]:SetPoint(
          'topleft', ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'scope' ], 'topright', 0, 0
        )
        ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'edit' ]:Show( )
        ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'help' ]:SetPoint(
          'topleft', ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'edit' ], 'topright', 0, 0
        )
        ui[ 'registry'][ category .. '|' .. row[ 'command' ] ][ 'help' ]:Show( )

        -- udpate dynamic data
        positions[ 'y' ]  = positions[ 'y' ] - 35
        --list[ category .. '|' .. row[ 'command' ] ] = t

      end

    end

  end

  local position  = self[ 'menu' ][ 'scroll' ][ 'ScrollBar' ]:GetValue( )
  if position ~= 0 then
    self[ 'menu' ][ 'scroll' ][ 'ScrollBar' ]:SetValue( 0 )
  end

  self:updateStats( self[ 'menu' ], self[ 'registry' ][ 'vars_count' ], self[ 'registry' ][ 'tracked_count' ], nil )

end

-- provide access to ui
--
-- returns table
function ui:createMenu( )
  
  local persistence = tracked:getNameSpace( )
  local frames = vars:GetModule( 'frames' )
  self[ 'menu' ] = self[ 'menu' ] or frames:bootUI( )
  tinsert( UISpecialFrames, self[ 'menu' ]:GetName( ) )
  self[ 'search'] = frames:createFrame( 'EditBox', 'search_box', self[ 'menu' ][ 'controls' ], 'BagSearchBoxTemplate' )
  self[ 'search']:SetSize( 100, 25 )
  --self[ 'search']:SetBackdropColor( 0, 1, 0, .9 )  
  self[ 'search']:SetPoint( 'topleft', self[ 'menu' ][ 'controls' ], 'topleft', 100, -14 )

  -- GLARING BUG that causes key presses to lose focus
  self[ 'search']:SetScript( 'OnTextChanged', function( sbutton )
    if( strlen( sbutton:GetText( ) ) >= 3 ) then
      persistence[ 'search' ][ 'text' ] = strlower( sbutton:GetText( ) )
      ui:iterateList( ui:filterList( ), 'search' )
    elseif( strlen( sbutton:GetText( ) ) == 0 ) then
      persistence[ 'search' ][ 'text' ] = nil
      self:iterateList( self:filterList( ) )
    end
  end )
  self[ 'search']:SetScript( 'OnEnterPressed', function( self )
    return
  end )
  self[ 'search'].clearButton:Hide( )
  self[ 'search'].clearButton:SetScript( 'OnClick', function( sbutton )
    sbutton:SetText( '' )
    self:iterateList( self:filterList( ) )
    persistence[ 'search' ][ 'text' ] = nil
  end )

  self[ 'search' ]:SetScript( 'OnEditFocusLost', function( sbutton )
    if( strlen( sbutton:GetText( ) ) == 0 ) then
      sbutton[ 'Instructions' ]:Show( )
    end
    --self:SetAutoFocus( false )
    --self:SetText( '' )
    --persistence[ 'search' ][ 'text' ] = nil
    --[[C_Timer.After( 1, function( )
      ui:iterateList( ui:filterList( ) )
    end )]]

  end )

  self[ 'search' ]:SetScript( 'OnEditFocusGained', function( self )
    --self:SetAutoFocus( false )
    self[ 'Instructions' ]:Hide( )
    persistence[ 'search' ][ 'text' ] = nil
  end )
  
  local vn = frames:createText( self[ 'menu' ][ 'controls' ], 'var' )
  vn:SetJustifyH( 'right' )
  vn:SetSize( 25, 20 )
  vn:SetPoint( 'topleft', self[ 'search'], 'topright', 0, -6 )

  local s = frames:createButton( self[ 'menu' ][ 'controls' ], '^', 'sorted' )
  s:SetSize( 10, 10 )
  s:SetPoint( 'topleft', vn, 'topright', 0, 0 )
  s:SetFrameLevel( 5 )
  s:RegisterForClicks( 'LeftButtonDown' )
  s:SetScript( 'OnClick', function( self )
    if persistence[ 'search' ][ 'sort_direction' ] == 'asc' then
      persistence[ 'search' ][ 'sort_direction' ] = 'desc'
    else
      persistence[ 'search' ][ 'sort_direction' ] = 'asc'
    end
    ui:iterateList( ui:filterList( ) )
  end )

  local vs = frames:createText( self[ 'menu' ][ 'controls' ], 'scope' )
  vs:SetJustifyH( 'left' )
  vs:SetSize( 50, 20 )
  vs:SetPoint( 'topleft', vn, 'topright', 20, 0 )

  local vv = frames:createText( self[ 'menu' ][ 'controls' ], 'v' )
  vv:SetJustifyH( 'left' )
  vv:SetSize( 25, 20 )
  vv:SetPoint( 'topleft', vs, 'topright', 5, 0 )

 local vh = frames:createText( self[ 'menu' ][ 'controls' ], 'help' )
  vh:SetJustifyH( 'left' )
  vh:SetSize( 50, 20 )
  vh:SetPoint( 'topleft', vv, 'topright', 0, 0 )

  altered = true
  self:iterateList( self:filterList( ) )
  altered = false

  local i   = 1
  local ddl = { }
  for category, _ in pairs( tracked:getConfig( ) ) do
    
    ddl[ i ] = { }
    if category == persistence[ 'search' ][ 'category_filter' ] then
      ddl[ i ][ 'checked' ] = true
    end
    ddl[ i ][ 'text' ]   = category
    ddl[ i ][ 'value' ]  = category
    i = i + 1
  end
  local d = frames:createDropDown( self, 'category', self[ 'menu' ][ 'controls' ], ddl )
  d:SetPoint( 'topleft', vh, 'topright', -15, 8 )
  self[ 'menu' ][ 'dropdown' ] = d

  local hooked  = frames:IsHooked( 'UIDropDownMenu_SetSelectedValue' )
  if not hooked then
    frames:SecureHook( 'UIDropDownMenu_SetSelectedValue', function( self ) 

      if self:GetParent():GetParent()[ 'scroll' ] == nil then
        return
      end
      local position  = self:GetParent():GetParent()[ 'scroll' ][ 'ScrollBar' ]:GetValue( )
      if position ~= 0 then
        self:GetParent():GetParent()[ 'scroll' ][ 'ScrollBar' ]:SetValue( 0 )
      end

    end )
  end

  local dbwipe = frames:createButton( self[ 'menu' ][ 'containers' ][ 2 ], 'Database Wipe', 'dbwipe' )
  dbwipe:SetSize( 125, 25 )
  dbwipe:SetPoint( 'topleft', self[ 'menu' ][ 'browser' ], 'topleft', 10, -10 )
  local t = frames:createText( self[ 'menu' ][ 'containers' ][ 2 ], 'use this if vars configuration becomes corrupt. your modifications to game settings will persist', 9, 'warn' )

  -- my_top_left, frame_attaching_to, frame_top_right, 10, 0, 
  t:SetPoint( 'topleft', dbwipe, 'topright', 10, 0 )
  t:SetSize( ( self[ 'menu' ][ 'containers' ][ 2 ]:GetWidth( ) ) - 20, 20 )

  dbwipe:SetScript( 'OnClick', function( self )
    vars:wipeDB( )
    tracked:_geParenttDB( ):ResetDB( )
    ui:updateStats( 
      ui[ 'menu' ], 
      ui[ 'registry' ][ 'vars_count' ], 
      ui[ 'registry' ][ 'tracked_count' ], 
      'done' 
    )
  end )

  local defaults = frames:createButton( self[ 'menu' ][ 'containers' ][ 2 ], 'Reset to Defaults', 'defaults' )
  defaults:SetSize( 125, 25 )
  defaults:SetPoint( 'topleft', self[ 'menu' ][ 'browser' ], 'topleft', 10, - ( dbwipe:GetHeight( ) + 20 ) )
  local t = frames:createText( self[ 'menu' ][ 'containers' ][ 2 ], 'resets your game configuration back to Blizzard default state', 9, 'warn' )

  -- my_top_left, frame_attaching_to, frame_top_right, 10, 0, 
  t:SetPoint( 'topleft', defaults, 'topright', 10, 0 )
  t:SetSize( ( self[ 'menu' ][ 'containers' ][ 2 ]:GetWidth( ) ) - 20, 20 )
  
  defaults:SetScript( 'OnClick', function( self )

    if not frames[ 'confirm_defaults' ] then
      local f = frames:createFrame( 'Frame', 'confirm_defaults', self:GetParent( ) )

      f:SetPoint( 'center', self:GetParent( ), 'center', 0, 0 )
      f:SetSize( 100, 100 )
      
      local t = frames:createText( f, 'are you sure?' )
      t:SetSize( 100, 25 )
      t:SetPoint( 'center', f, 'center', 0, 0 )
      t:SetJustifyH( 'center' )
      
      local c = frames:createButton( f, 'Cancel', 'cancel_defaults' )
      c:SetSize( 50, 25 )
      c:SetPoint( 'topleft', t, 'bottomleft', 0, 0 )
      c:SetScript( 'OnClick', function( self )
        f:Hide( )
      end )
      
      local o = frames:createButton( f, 'Yes', 'apply_defaults' )
      o:SetSize( 50, 25 )
      o:SetPoint( 'topleft', c, 'topright', 0, 0 )
      o:SetScript( 'OnClick', function( self )
        vars:applyDefaults( )
        ui:updateStats( 
        ui[ 'menu' ], 
        ui[ 'registry' ][ 'vars_count' ], 
        ui[ 'registry' ][ 'tracked_count' ], 
        'done' 
      )
      ReloadUI( )
      end )
    else
      frames[ 'confirm_defaults' ]:Show( )
    end

  end )

  local _, _, _, x, y = defaults:GetPoint( )
  local rlgx = frames:createCheckbox( self[ 'menu' ][ 'containers' ][ 2 ], 'Reload Graphics', 'rlgx' )
  rlgx:SetSize( 25, 25 )

  -- my_top_left, frame_attaching_to, frame_top_right, 10, 0, 
  rlgx:SetPoint( 'topleft', defaults, 'bottomleft', 0, -20 )
  local t = frames:createText( self[ 'menu' ][ 'containers' ][ 2 ], 'some settings may only require a reload of your graphics', 9, 'warn' )
  t:SetPoint( 'topleft', rlgx, 'bottomleft', 0, 0 )
  t:SetSize( ( self[ 'menu' ][ 'containers' ][ 2 ]:GetWidth( ) / 2 ) - 20, 20 )

  rlgx:SetChecked( persistence[ 'options' ][ 'reloadgx' ] or false )
  rlgx:SetScript( 'OnClick', function( self )
    persistence[ 'options' ][ 'reloadgx' ] = self:GetChecked( )
    ui:updateStats( 
      ui[ 'menu' ], 
      ui[ 'registry' ][ 'vars_count' ], 
      ui[ 'registry' ][ 'tracked_count' ], 
      'done' 
    )
  end )

  local rlui = frames:createCheckbox( self[ 'menu' ][ 'containers' ][ 2 ], 'Reload UI', 'rlui' )
  rlui:SetSize( 25, 25 )

  -- my_top_left, frame_attaching_to, frame_top_right, 10, 0, 
  rlui:SetPoint( 'topleft', t, 'topright', 10, ( rlgx:GetHeight( ) ) )
  local t = frames:createText( self[ 'menu' ][ 'containers' ][ 2 ], 'some settings require a full reload of your ui', 9, 'warn' )
  t:SetPoint( 'topleft', rlui, 'bottomleft', 0, 0 )
  t:SetSize( ( self[ 'menu' ][ 'containers' ][ 2 ]:GetWidth( ) / 2 ) - 20, 20 )

  rlui:SetChecked( persistence[ 'options' ][ 'reloadui' ] or false )
  rlui:SetScript( 'OnClick', function( self )
    persistence[ 'options' ][ 'reloadui' ] = self:GetChecked( )
    ui:updateStats( 
      ui[ 'menu' ], 
      ui[ 'registry' ][ 'vars_count' ], 
      ui[ 'registry' ][ 'tracked_count' ], 
      'done' 
    )
  end )

  local csui = frames:createCheckbox( self[ 'menu' ][ 'containers' ][ 2 ], 'Cloud Sync', 'csui' )
  csui:SetSize( 25, 25 )
  csui:SetPoint( 'topleft', rlgx, 'bottomleft', 0, -20 )
  local t = frames:createText( self[ 'menu' ][ 'containers' ][ 2 ], 'save modifications to Blizzard servers', 9, 'warn' )
  t:SetPoint( 'topleft', csui, 'bottomleft', 0, 0 )
  t:SetSize( ( self[ 'menu' ][ 'containers' ][ 2 ]:GetWidth( ) / 2 ) - 20, 20 )

  csui:SetChecked( persistence[ 'options' ][ 'cloudsync' ] or false )
  csui:SetScript( 'OnClick', function( self )
    persistence[ 'options' ][ 'cloudsync' ] = self:GetChecked( )
    tracked:cloudSync( persistence[ 'options' ][ 'cloudsync' ] )
    ui:updateStats( 
      ui[ 'menu' ], 
      ui[ 'registry' ][ 'vars_count' ], 
      ui[ 'registry' ][ 'tracked_count' ], 
      'done' 
    )
  end )

  --[[
  -- import window
  utility:dump( self[ 'menu' ][ 'containers' ][ 3 ] )
  local iw = frames:createFrame( 'Frame', 'import_window', self[ 'menu' ][ 'containers' ][ 3 ], nil )
  iw:SetSize( self[ 'menu' ][ 'containers' ][ 3 ]:GetWidth( ) - 20, self[ 'menu' ][ 'containers' ][ 3 ]:GetHeight( ) - 20 )
  iw:SetPoint( 'center', self[ 'menu' ][ 'browser' ], 'center'  )

  -- import editor
  local ie = frames:createEditBox( iw, 'Import String', 'import_editor', nil )
  ie:SetMultiLine( true )
  ie[ 'num_lines']  = 30
  ie:SetSize( iw:GetWidth(),ie[ 'num_lines'] * 14 )
  ie:SetMaxLetters( 0 )
  ie:SetPoint( 'center', iw, 'center' )

  self[ 'menu' ][ 'scroll' ]:SetScrollChild( ie )
  ]]

  return self[ 'menu' ]

end

-- dropdown onchange event
--
-- returns void
function ui:dropdownOnChange( dropdown_frame )
  
  local persistence     = tracked:getNameSpace( )
  local selected_value  = UIDropDownMenu_GetSelectedValue( dropdown_frame )

  if persistence[ 'search' ][ 'category_filter' ] ~= selected_value then
    persistence[ 'search' ][ 'category_filter' ] = selected_value

    UIDropDownMenu_ClearAll( dropdown_frame )
    UIDropDownMenu_SetSelectedValue( dropdown_frame, selected_value )

    self:iterateList( self:filterList( ) )
  end

  CloseDropDownMenus( )

end

-- updates configuration
--
-- returns bool
function ui:updateConfig( f, cvar_category, cvar_name, cvar_value )

  tracked:queueConfig( cvar_category, cvar_name, cvar_value )

  local updated, tracked_count, message = tracked:applyConfig( cvar_category )
  self[ 'registry' ][ 'tracked_count' ] = tracked_count
  if updated then
    altered = true
  end
  self:updateStats(
    f, 
    self[ 'registry' ][ 'vars_count' ], 
    self[ 'registry' ][ 'tracked_count' ], 
    message 
  )

  return updated

end

-- updates stats
--
--  @param notification frame
--  @param # total vars
--  @param # changed vars
--  @param notification text
--
-- returns void
function ui:updateStats( f, vars_count, tracked_count, message )
  
  if not self[ 'registry'][ 'stats' ] then
    ui[ 'registry'][ 'stats' ] = { }
    local frames = vars:GetModule( 'frames' )

    local t = frames:createText(
      f, 
      nil,
      vars[ 'theme' ][ 'font' ][ 'small' ],
      'warn' 
    )
    t:SetPoint( 'topleft', f[ 'updates' ], 'topleft', 135, -5 )

    ui[ 'registry'][ 'stats' ][ 'message' ] = t

    local found_label = frames:createText( 
      f, 
      'Vars:', 
      vars[ 'theme' ][ 'font' ][ 'small' ] 
    )
    found_label:SetPoint( 
      'bottomright', 
      f[ 'updates' ], 
      'bottomright', 
      -( 
        ( 
          f[ 'scroll' ][ 'ScrollBar' ]:GetWidth( ) 
        ) + 10 
      ), 
    10 )
    local found_count = frames:createText( 
      f, 
      nil, 
      vars[ 'theme' ][ 'font' ][ 'small' ], 
      'text' 
    )
    found_count:SetPoint( 'topleft', found_label, 'topright', 0, 0 )
    ui[ 'registry'][ 'stats' ][ 'vars_count' ] = found_count
    
    local tracked_label = frames:createText( 
      f, 
      'Modified:', 
      vars[ 'theme' ][ 'font' ][ 'small' ] 
    )
    tracked_label:SetPoint(
      'topleft', 
      found_label, 
      'topleft', 
      -( ( found_label:GetWidth( ) + found_label:GetWidth( ) ) + 15 ), 
      0 
    )
    local tracked_count = frames:createText( 
      f, 
      nil, 
      vars[ 'theme' ][ 'font' ][ 'small' ], 
      'info' 
    )
    tracked_count:SetPoint( 'topleft', tracked_label, 'topright', 0, 0 )
    ui[ 'registry'][ 'stats' ][ 'tracked_count' ] = tracked_count
    
    local locked_label = frames:createText( 
      f, 
      'Locked:', 
      vars[ 'theme' ][ 'font' ][ 'small' ]
    )
    locked_label:SetPoint(
      'topleft', 
      tracked_label, 
      'topleft', 
      -( ( tracked_label:GetWidth( ) ) ), 
      0 
    )
    local locked_count = frames:createText( 
      f, 
      nil, 
      vars[ 'theme' ][ 'font' ][ 'small' ], 
      'error' 
    )
    locked_count:SetPoint( 'topleft', locked_label, 'topright', 0, 0 )
    ui[ 'registry'][ 'stats' ][ 'locked_count' ] = locked_count
  end
  if not altered then
    return
  end

  self[ 'registry'][ 'stats' ][ 'vars_count' ]:SetText( vars_count )
  self[ 'registry'][ 'stats' ][ 'tracked_count' ]:SetText( tracked_count )
  self[ 'registry'][ 'stats' ][ 'locked_count' ]:SetText( self[ 'registry' ][ 'locked_count' ] )

end

-- register addon
--
-- returns void
function ui:OnInitialize( )
  self:Enable( )
end

-- activated addon handler
--
-- returns void
function ui:OnEnable( )
  self:init( )
end