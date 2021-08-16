---@diagnostic disable: lowercase-global, undefined-global, undefined-field

dir = './plugins/LXLLock/'
db = data.openDB(dir)
if(db == nil)then
    colorLog('red',"db error!")
    return
end
local seeing = {}
function split(input, delimiter)
    input,delimiter = tostring(input),tostring(delimiter)
    if (delimiter=='') then return false end
    local pos,arr = 0, {}
    for st,sp in function() return string.find(input, delimiter, pos, true) end do
        table.insert(arr, string.sub(input, pos, st - 1))
        pos = sp + 1
    end
    table.insert(arr, string.sub(input, pos))
    return arr
end
function toint(n)
    local s = tostring(n)
    local i,j = s:find('%.')
    if i then
        return tonumber(s:sub(1,i-1))
    else
        return n
    end
end
function toindex(b)
    return toint(b.pos.x).."_"..toint(b.pos.y)..'_'..toint(b.pos.z)..'_'..b.pos.dimid
end
function is_own(b)
    local k = toint(b.pos.x).."_"..toint(b.pos.y)..'_'..toint(b.pos.z)..'_'..b.pos.dimid
    if(db:get(k)~=nil)then
        return true,db:get(k).owner,db:get(k).share
    end
    return false
end
function add_chest(pl,b)
    local k = b.pos.x.."_"..b.pos.y..'_'..b.pos.z..'_'..b.pos.dimid
    db:set(k,{owner=pl.xuid,share={}})
end
function del_chest(b)
    local k = b.pos.x.."_"..b.pos.y..'_'..b.pos.z..'_'..b.pos.dimid
    db:delete(k)
end
function explode_check(pos)
    for k,v in pairs(db:listKey())do
        local c = split(v,'_')
        if(tonumber(c[4]) == pos.dimid)then
            local m = (tonumber(c[1]) - pos.x)^2 + (tonumber(c[2]) - pos.y)^2 + (tonumber(c[3]) - pos.z)^2
            --print(math.sqrt(m))
            if(math.sqrt(m) < 5)then
                print('[LXLLock] 为了保护'..data.xuid2name(db:get(v).owner)..'的上锁箱子,已拦截一次爆炸')
                return false
            end
        end
    end
    return true
end
function getonline()
    local t = {}
    for k,v in pairs(mc.getOnlinePlayers())do
        table.insert(t,v.realName)
    end
    return t
end
function sharef(b)
    local k = toint(b.pos.x).."_"..toint(b.pos.y)..'_'..toint(b.pos.z)..'_'..b.pos.dimid
    local t = {}
    for k,v in pairs(db:get(k).share)do
        table.insert(t,data.xuid2name(v))
    end
    local f = mc.newCustomForm()
    f = f:setTitle('chest share')
    f = f:addDropdown('选择要共享的人',getonline())
    return f
end
function unsharef(b)
    local k = toint(b.pos.x).."_"..toint(b.pos.y)..'_'..toint(b.pos.z)..'_'..b.pos.dimid
    local t = {}
    for k,v in pairs(db:get(k).share)do
        table.insert(t,data.xuid2name(v))
    end
    local f = mc.newCustomForm()
    f = f:setTitle('chest unshare')
    f = f:addDropdown('选择要移除共享的人',getonline())
    return f
end
function share(pl,dt)
    if(dt~=nil)then
        local p = mc.getOnlinePlayers()[dt[1]+1].xuid
        local t = db:get(seeing[pl.realName])
        if(p == pl.xuid)then pl:tell("you are the owner!!") return end
        for k,v in pairs(db:get(seeing[pl.realName]).share)do
            if(v ==p)then
                pl:tell('you are already share this chest to this player!')
                return
            end
        end
        table.insert(t.share,p)
        db:set(seeing[pl.realName],t)
        pl:tell('share success!')
    end
end

function v_include(tab, value)
    for k,v in pairs(tab)do
      if (v==value)then
          return true
      end
    end
    return false
end
function unshare(pl,dt)
    if(dt~=nil)then
        local p = mc.getOnlinePlayers()[dt[1]+1].xuid
        local t = db:get(seeing[pl.realName])
        if(p == pl.xuid)then pl:tell("you are the owner!!") return end
        for k,v in pairs(db:get(seeing[pl.realName]).share)do
            if(v ==p)then
                t.share[k] = nil
                db:set(seeing[pl.realName],t)
                pl:tell('unshare success')
                return
            end
        end
        pl:tell('you haven\'t share this chest to this player!')
    end
end
--[[
{
    "100_-100_3123_0":{
        "owner":"xuid string",
        "share":["782158754821","678364287616"]
    }
}
]]

mc.listen("onExplode",function (en,pos)
    return explode_check(pos)
end)
mc.listen("onBedExplode",function (pos)
    return explode_check(pos)
end)
mc.listen("onRespawnAnchorExplode",function (pos,pl)
    return explode_check(pos)
end)
mc.listen("onPistonPush",function (ppos,bl)
    if(bl.type == 'minecraft:chest')then
        if(db:get(toint(bl.pos.x).."_"..toint(bl.pos.y)..'_'..toint(bl.pos.z)..'_'..bl.pos.dimid)~=nil)then
            return false
        end
    end
end)
mc.listen("onOpenContainer",function (pl,bl)
    if(bl.type == 'minecraft:chest')then
        local o,s,e = is_own(bl)
        if(o)and(v_include(e,pl.xuid))then return true end
        if(o)and(pl.xuid~=s)then
            pl:tell("chest already lock by "..data.xuid2name(s))
            return false
        end
    end
end)
mc.listen("onHopperSearchItem",function (pos)
    local y = pos.y+1
    if(db:get(toint(pos.x).."_"..toint(y)..'_'..toint(pos.z)..'_'..pos.dimid)~=nil)then
        return false
    end
end)
mc.listen("onDestroyBlock",function (pl,bl)
    if(bl.type == 'minecraft:chest')then
        local o,s,e = is_own(bl)
        if(o)then
            pl:tell("chest already lock by "..data.xuid2name(s))
            return false
        end
    end
end)
mc.regPlayerCmd("chest","chest command",function (pl,arg)
    if(#arg == 0)then pl:tell('too feew arguments!') return end
    local b = mc.getBlock(toint(pl.pos.x),toint(pl.pos.y),toint(pl.pos.z),0)
    if(b~=nil)then
        if(b.type ~= 'minecraft:chest')then
            pl:tell("you should stand on the top of a chest!")
            return
        end
        local o,s,e = is_own(b)
        if(arg[1] == 'lock')then  
            if(o)then
                pl:tell("chest already lock by "..data.xuid2name(s))
            else
                add_chest(pl,b)
                pl:tell("chest lock!")
            end
        elseif (arg[1] == 'unlock') then
            if(o)and(pl.xuid~=s)then
                pl:tell("chest already lock by "..data.xuid2name(s))
            elseif (o)and(pl.xuid==s) then
                del_chest(b)
                pl:tell("chest unlock!")
            else
                pl:tell("this chest doesn\'t have owner!")
            end
        elseif (arg[1] == 'share') then
            if(o)and(pl.xuid==s)then
                seeing[pl.realName] = toindex(b)
                pl:sendForm(sharef(b),share)
            elseif(o)and(pl.xuid~=s)then
                pl:tell('you are not this chest\'s owner!')
            elseif (o == false) then
                pl:tell('this chest doesn\'t have owner')
            end
        elseif (arg[1] == 'unshare') then
            if(o)and(pl.xuid==s)then
                seeing[pl.realName] = toindex(b)
                pl:sendForm(unsharef(b),unshare)
            elseif(o)and(pl.xuid~=s)then
                pl:tell('you are not this chest\'s owner!')
            elseif (o == false) then
                pl:tell('this chest doesn\'t have owner')
            end
        end
    end
end)

log('[LXLLock] init!')
log("[LXLLock] v1.2.0")