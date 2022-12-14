--------------------------------------------------------------------------------------------------------------------------------
if getmetatable(table) == nil then -- Table lib
--------------------------------------------------------------------------------------------------------------------------------
local table_proto = table

--- get instance type or raw type
---@param v any|nil @value
---@return string @mt.type or type(v)
typeof = function(v)
    local mt = getmetatable(v)
    if not mt or not mt.is_instace or not mt.type then return type(v) end
    return mt.type
end

--- get table item count
---@return integer @item count
function table_proto:count()
    local count = 0
	for k in pairs(self) do
        if k ~= "__readonly__" then count = count + 1 end
    end
	return count
end

--- create comples indexer for table,
--- searching values in all given tables until all returuns nil
---@vararg table   @fallback tables
---@return any|nil @search value, nil if no found
function table_proto:indexer(...)
    local tables = pack(self, ...)
    return function(_, key)
        for _, tb in ipairs(tables) do
            local value = tb[key]
            if value ~= nil then return value end
        end
        return nil
    end
end

--- create a protected table overlay
---@param overlay? table @optional overlay table
---@param mt?      table @optional metatable fields, will be copied to new metatable
---@return table @overlay result
---@return table @overlay metatable
function table:overlay(overlay, mt)
    local overlay = overlay or {}
    local new_mt = { __index = table.indexer(self), __metatable = table.empty }
    if mt then table.dump(mt, new_mt) end
    setmetatable(overlay, new_mt)
    return overlay, new_mt
end

--- set metatable to table. if the old mt same as the new mt then do nothing.
---@param mt table @metatable to set
---@param force? boolean|function @optiona boolean or function indicates that should overwrite metatable or not
function table_proto:set_metatable(mt, force)
    local target, old_mt = self, getmetatable(self)
    if old_mt == false
    then error("Table was protected")
    elseif old_mt ~= nil then
        if old_mt == mt then return target end -- Already set

        if type(force) == 'function' then force = force() end
        if not force then error("Table already has a metatable, use 'force' to bypass this check") end
    end
    return setmetatable(target, mt)
end

--- filter table entires
---@param filter fun(value: any, key : string|integer, count : integer) @filter
---@return table @new table containing filtered results
function table_proto:filter(filter)
    local source, target, counter = self, table {}, 1
    for k, v in pairs(source) do
        if filter(k, v, counter) then target[k] = v end
        counter = counter + 1
    end
    return target
end

function table_proto:pairs()
    return pairs(self)
end

local __default_string_converter = function(v) return tostring(v) end

--- join collection items to string
---@param delimiter? string @delimiter, default is empty string
---@param converter? fun(value : any, key : string|integer, counter : integer):string @optional converter, default is tostring(value)
function table_proto:join_tostring(delimiter, converter)
    local source = self
    local acc, counter = "", 1
    local converter, delimiter = (converter or __default_string_converter), (delimiter or "")
    for k, v in pairs(source) do
        if counter > 1 then acc = acc .. delimiter end
        local transformed = converter(v, k, counter)
        acc = acc .. transformed
        counter = counter + 1
    end
    return acc
end

--- map table entires
---@param converter fun(value : any, key : string|integer, count: integer) @converter
---@return table|array @new mapped items containing converted result, returns an array
function table_proto:map(converter)
    local source, target, counter = self, {}, 1
    for k, v in pairs(source) do
        table.insert(target, converter(v, k, counter))
        counter = counter + 1
    end
    return array(target)
end

--- Group item by key key_selector
---@param key_selector fun(value : any, key : string|integer, count : integer) @key selector
---@return table @grouped result
function table_proto:group_by(key_selector)
    local source, target = self, table {}
    local count = 1
    for k, v in pairs(source) do
        local key = key_selector(v, k, count)
        local bucket = target[key] or array {}
        bucket:insert(v)
        target[key] = bucket
        count = count + 1
    end
    return target
end

--- table type
local tables_mt = { __index = table.indexer(table_proto), is_instace = true, type = 'table' }

--- wrap a table as 'table'
---@param tb table @target table
---@return table @wrapped table
table_proto.wrap = function(tb) return table.set_metatable(tb, tables_mt) end

-- Export new table lib
table = table.protect({}, {
    __index = table_proto.indexer(table_proto);
    __call  = function(self, tb) return self.wrap(tb) end;
    __metatable = table.empty;
})

end -- END OF TABLE
return table