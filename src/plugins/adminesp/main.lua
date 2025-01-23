local playerWallhackModels = {}
local playerHasWallhack = {}

AddEventHandler("OnAllPluginsLoaded", function(event)
    local modelCount = #ModelsToPrecache
    for i = 1, modelCount do
        precacher:PrecacheModel(ModelsToPrecache[i])
    end

    return EventResult.Continue
end)

AddEventHandler("OnPlayerDisconnect", function(event)
    local playerid = event:GetInt("userid")
    playerHasWallhack[playerid] = nil
    return EventResult.Continue
end)

AddEventHandler("OnRoundEnd", function()
    playerWallhackModels = {}
    return EventResult.Continue
end)

-- At spawn, create a relay and a glow entity for the player.
AddEventHandler("OnPlayerSpawn", function (event)
    local playerid = event:GetInt("userid")
    local player = GetPlayer(playerid)
    if not player or not player:IsValid() then return EventResult.Continue end

    local instanceGlow = CreateEntityByName("prop_dynamic")
    local instanceRelay = CreateEntityByName("prop_dynamic")
    if not instanceGlow:IsValid() or not instanceRelay:IsValid() then return EventResult.Continue end

    local modelGlow = CBaseModelEntity(instanceGlow:ToPtr())
    local modelRelay = CBaseModelEntity(instanceRelay:ToPtr())

    local entityGlow = CBaseEntity(instanceGlow:ToPtr())
    local entityRelay = CBaseEntity(instanceRelay:ToPtr())

    local modelName = player:CBaseEntity().CBodyComponent.SceneNode:GetSkeletonInstance().ModelState.ModelName

    modelRelay:SetModel(modelName)
    entityRelay.Spawnflags = 256
    modelRelay.RenderMode = RenderMode_t.kRenderNone
    entityRelay:Spawn()

    modelGlow:SetModel(modelName)
    entityGlow.Spawnflags = 256
    entityGlow:Spawn()

    modelGlow.Glow.GlowColorOverride = Color(255,255,255,255)
    modelGlow.Glow.GlowRange = 5000
    modelGlow.Glow.GlowTeam = -1
    modelGlow.Glow.GlowType = 3
    modelGlow.Glow.GlowRangeMin = 50

    entityRelay:AcceptInput("FollowEntity", player:CCSPlayerPawn(), modelRelay, "!activator", 0)
    entityGlow:AcceptInput("FollowEntity", modelRelay, modelGlow, "!activator", 0)

    local indexRelay = CBasePlayerController(entityRelay:ToPtr()):EntityIndex()
    local indexGlow = CBasePlayerController(entityGlow:ToPtr()):EntityIndex()
    playerWallhackModels[indexRelay] = true
    playerWallhackModels[indexGlow] = true

    if config:Fetch("adminesp.dead_only") == true then
        if player:CBaseEntity().Health > 0 and playerHasWallhack[playerid] then
            playerHasWallhack[playerid] = false
        end
    end

    return EventResult.Continue
end)

AddEventHandler("OnPlayerCheckTransmit", function(event, playerid, transmitinfoptr)
    if not playerHasWallhack[playerid] then
        local transmitinfo = CCheckTransmitInfo(transmitinfoptr)
        local entity_indexes = transmitinfo:GetEntities()
        local entity_count = #entity_indexes
        local filteredEntities = {}

        for i = 1, entity_count do
            if not playerWallhackModels[entity_indexes[i]] then
                filteredEntities[#filteredEntities + 1] = entity_indexes[i]
            end
        end

        transmitinfo:SetEntities(filteredEntities)
    end
    return EventResult.Continue
end)

commands:Register("wh", function (playerid, args, argsCount, silent, prefix)
    local flag = config:Fetch("adminesp.access_flags")
	if playerid == -1 then return end
	if playerid ~= -1 then
        local player = GetPlayer(playerid)
        if not player then return end

        local hasAccess = exports["admins"]:HasFlags(playerid, tostring(flag))
        if not hasAccess then
            return ReplyToCommand(playerid, config:Fetch("admins.prefix"), string.format(FetchTranslation("admins.no_permission"), prefix))
        end

        if argsCount ~= 0 then
            return ReplyToCommand(playerid, config:Fetch("admins.prefix"), string.format(FetchTranslation("adminesp.invalid_syntax"), prefix))
        end

        local playerName = player:CBasePlayerController().PlayerName
        
        if config:Fetch("adminesp.dead_only") == true then
            if player:CBaseEntity().Health > 0 then
                return ReplyToCommand(playerid, config:Fetch("admins.prefix"), FetchTranslation("adminesp.dead_only"))
            end
        end

        if config:Fetch("adminesp.spec_only") == true then
            if player:CBaseEntity().TeamNum ~= 1 then
                return ReplyToCommand(playerid, config:Fetch("admins.prefix"), FetchTranslation("adminesp.spec_only"))
            end
        end

        playerHasWallhack[playerid] = not playerHasWallhack[playerid]
        local status = tostring(playerHasWallhack[playerid])

        print("{red}Wallhack " .. status .. " for " .. playerName) -- Only viewable in server console.
    end
end)
commands:RegisterAlias("wh", "esp")

AddEventHandler("OnPostPlayerTeam", function(p_Event)
    if p_Event:GetBool("disconnect") then
        return
    end

    local l_PlayerId = p_Event:GetInt("userid")
    local l_Player = GetPlayer(l_PlayerId)

    if not l_Player or not l_Player:IsValid() then
        return
    end

    local l_Team = p_Event:GetInt("team")

    NextTick(function()
        if not l_Player:IsValid() then
            return
        end

        l_Player:CBaseEntity().TeamNum = l_Team
    end)
end)