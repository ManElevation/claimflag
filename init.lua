-- ManElevations's Claim Flag
-- part of code by Zeg9
-- based on Zeg9's protector mod

local flag_sbox = {
	type = "fixed",
	fixed = { -0.1, -0.625, -0.1, 0.1, 0.5, 0.1 }
}
-- claim lag

minetest.register_privilege("delclaim","Delete other's Flags by sneaking")

claimflag = {}

claimflag.node = "claimflag:flag"
claimflag.item = "claimflag:stick"

claimflag.get_member_list = function(meta)
	local s = meta:get_string("members")
	local list = s:split(" ")
	return list
end

claimflag.set_member_list = function(meta, list)
	meta:set_string("members", table.concat(list, " "))
end

claimflag.is_member = function (meta, name)
	local list = claimflag.get_member_list(meta)
	for _, n in ipairs(list) do
		if n == name then
			return true
		end
	end
	return false
end

claimflag.add_member = function(meta, name)
	if claimflag.is_member(meta, name) then return end
	local list = claimflag.get_member_list(meta)
	table.insert(list,name)
	claimflag.set_member_list(meta,list)
end

claimflag.del_member = function(meta,name)
	local list = claimflag.get_member_list(meta)
	for i, n in ipairs(list) do
		if n == name then
			table.remove(list, i)
			break
		end
	end
	claimflag.set_member_list(meta,list)
end

claimflag.generate_formspec = function (meta)
	if meta:get_int("page") == nil then meta:set_int("page",0) end
	local formspec = "size[8,8]"
		.."label[0,0;-- Claim Flag --]"
		.."label[0,1;Punch the node to show the claimed area.]"
		.."label[0,2;Current members:]"
	members = claimflag.get_member_list(meta)
	
	local npp = 15 -- names per page, for the moment is 4*4 (-1 for the + button)
	local s = 0
	local i = 0
	for _, member in ipairs(members) do
		if s < meta:get_int("page")*15 then s = s +1 else
			if i < 15 then
				formspec = formspec .. "button["..(i%4*2)..","..math.floor(i/4+3)..";1.5,.5;claimflag_member;"..member.."]"
				formspec = formspec .. "button["..(i%4*2+1.25)..","..math.floor(i/4+3)..";.75,.5;claimflag_del_member_"..member..";X]"
			end
			i = i +1
		end
	end
	local add_i = i
	if add_i > npp then add_i = npp end
	formspec = formspec
		.."field["..(add_i%4*2+1/3)..","..(math.floor(add_i/4+3)+1/3)..";1.433,.5;claimflag_add_member;;]"
		.."button["..(add_i%4*2+1.25)..","..math.floor(add_i/4+3)..";.75,.5;claimflag_submit;+]"
	
	if s > 0 then
		formspec = formspec .. "button[0,7;1,1;claimflag_page_prev;<<]"
	end
	if i > npp then
		formspec = formspec .. "button[1,7;1,1;claimflag_page_next;>>]"
	end
	formspec = formspec .. "label[2,7;Page "..(meta:get_int("page")+1).."/"..math.floor((s+i-1)/15+1).."]"
	return formspec
end

-- r: radius to check for flags
-- Infolevel:
-- * 0 for no info
-- * 1 for "This area is owned by <owner> !" if you can't dig
-- * 2 for "This area is owned by <owner>.
--   Members are: <members>.", even if you can dig
claimflag.can_dig = function(r,pos,digger,onlyowner,infolevel)
	if infolevel == nil then infolevel = 1 end
	if not digger or not digger.get_player_name then return false end
	-- Delclaim privileged users can override flags by holding sneak
	if minetest.get_player_privs(digger:get_player_name()).delclaim and
	   digger:get_player_control().sneak then
		return true end
	-- Find the claimflag nodes
	local positions = minetest.find_nodes_in_area(
		{x=pos.x-r, y=pos.y-r, z=pos.z-r},
		{x=pos.x+r, y=pos.y+r, z=pos.z+r},
		claimflag.node)
	for _, pos in ipairs(positions) do
		local meta = minetest.env:get_meta(pos)
		local owner = meta:get_string("owner")
		if owner ~= digger:get_player_name() then 
			if onlyowner or not claimflag.is_member(meta, digger:get_player_name()) then
				if infolevel == 1 then
					minetest.chat_send_player(digger:get_player_name(), "This area is owned by "..owner.." !")
				elseif infolevel == 2 then
					minetest.chat_send_player(digger:get_player_name(),"This area is owned by "..meta:get_string("owner")..".")
					if meta:get_string("members") ~= "" then
						minetest.chat_send_player(digger:get_player_name(),"Members are: "..meta:get_string("members")..".")
					end
				end
				return false
			end
		end
	end
	if infolevel == 2 then
		if #positions < 1 then
			minetest.chat_send_player(digger:get_player_name(),"This area is not claimed.")
		else
			local meta = minetest.env:get_meta(positions[1])
			minetest.chat_send_player(digger:get_player_name(),"This area is owned by "..meta:get_string("owner")..".")
			if meta:get_string("members") ~= "" then
				minetest.chat_send_player(digger:get_player_name(),"Members are: "..meta:get_string("members")..".")
			end
		end
		minetest.chat_send_player(digger:get_player_name(),"You can build here.")
	end
	return true
end

local old_node_dig = minetest.node_dig
function minetest.node_dig(pos, node, digger)
	local ok=true
	if node.name ~= claimflag.node then
		ok = claimflag.can_dig(5,pos,digger)
	else
		ok = claimflag.can_dig(5,pos,digger,true)
	end
	if ok == true then
		old_node_dig(pos, node, digger)
	end
end

local old_node_place = minetest.item_place
function minetest.item_place(itemstack, placer, pointed_thing)
	if itemstack:get_definition().type == "node" then
		local ok=true
		if itemstack:get_name() ~= claimflag.node then
			local pos = pointed_thing.above
			ok = claimflag.can_dig(5,pos,placer)
		else
			local pos = pointed_thing.above
			ok = claimflag.can_dig(10,pos,placer,true)
		end 
		if ok == true then
			return old_node_place(itemstack, placer, pointed_thing)
		else
			return
		end	
	end	
	return old_node_place(itemstack, placer, pointed_thing)
end
local flag = {}
minetest.register_node(claimflag.node, {
	description = "Claim Flag",
	drawtype = "mesh",
	mesh = "flag.obj",
	tiles = {"claim_flag.png"},
	walkable = true,
	climbable = true,
	sunlight_propagates = true,
	paramtype = "light",
	inventory_image = "claim_inv.png",
	groups = {cracky=3},
--	selection_box = flag_sbox,
	drawtype = "mesh",
selection_box = {
		type = "fixed",
		fixed = { -0.5, -0.5, -0.5, 0.5, 1.5, 0.5 }
	},
collision_box = {
		type = "fixed",
		fixed = {

			{ 0.48, -0.5,-0.5,  0.5,  0.5, 0.5},
			{-0.5 , -0.5, 0.48, 0.48, 0.5, 0.5}, 
			{-0.5,  -0.5,-0.5 ,-0.48, 0.5, 0.5},
			{-0.5,  -0.5,-0.5 ,-0.48, 0.5, 0.5},

			--groundplate to stand on
			{-0.5,  -0.5,-0.5 ,-0.48, 0.5, 0.5},
		},
	},
	
	paramtype = "light",
	after_place_node = function(pos, placer)
		local meta = minetest.env:get_meta(pos)
		meta:set_string("owner", placer:get_player_name() or "")
		meta:set_string("infotext", "Claim Flag (owned by "..
				meta:get_string("owner")..")")
		meta:set_string("members", "")
		--meta:set_string("formspec",claimflag.generate_formspec(meta))
	end,
	on_rightclick = function(pos, node, clicker, itemstack)
		local meta = minetest.env:get_meta(pos)
		if claimflag.can_dig(1,pos,clicker,true) then
			minetest.show_formspec(
				clicker:get_player_name(),
				"claimflag_"..minetest.pos_to_string(pos),
				claimflag.generate_formspec(meta)
			)
		end
	end,
	on_punch = function(pos, node, puncher)
		if not claimflag.can_dig(1,pos,puncher,true) then
			return
		end
		local objs = minetest.env:get_objects_inside_radius(pos,.5) -- a radius of .5 since the entity serialization seems to be not that precise
		local removed = false
		for _, o in pairs(objs) do
			if (not o:is_player()) and o:get_luaentity().name == "claimflag:display" then
				o:remove()
				removed = true
			end
		end
		if not removed then -- nothing was removed: there wasn't the entity
			minetest.env:add_entity(pos, "claimflag:display")
		end
	end,
})
-- remove formspecs from older versions of the mod
minetest.register_abm({
	nodenames = {claimflag.node},
	interval = 5.0,
	chance = 1,
	action = function(pos,...)
		local meta = minetest.env:get_meta(pos)
		meta:set_string("formspec","")
	end,
})
minetest.register_on_player_receive_fields(function(player,formname,fields)
	if string.sub(formname,0,string.len("claimflag_")) == "claimflag_" then
		local pos_s = string.sub(formname,string.len("claimflag_")+1)
		local pos = minetest.string_to_pos(pos_s)
		local meta = minetest.env:get_meta(pos)
		if meta:get_int("page") == nil then meta:set_int("page",0) end
		if not claimflag.can_dig(1,pos,player,true) then
			return
		end
		if fields.claimflag_add_member then
			for _, i in ipairs(fields.claimflag_add_member:split(" ")) do
				claimflag.add_member(meta,i)
			end
		end
		for field, value in pairs(fields) do
			if string.sub(field,0,string.len("claimflag_del_member_"))=="claimflag_del_member_" then
				claimflag.del_member(meta, string.sub(field,string.len("claimflag_del_member_")+1))
			end
		end
		if fields.claimflag_page_prev then
			meta:set_int("page",meta:get_int("page")-1)
		end
		if fields.claimflag_page_next then
			meta:set_int("page",meta:get_int("page")+1)
		end
		if not fields.quit then
			minetest.show_formspec(
				player:get_player_name(), formname,
				claimflag.generate_formspec(meta)
			)
		end
	end
end)

minetest.register_craftitem(claimflag.item, {
	description = "Flag tool",
	inventory_image = "claimflag_stick.png",
	on_use = function(itemstack, user, pointed_thing)
		if pointed_thing.type ~= "node" then
			return
		end
		claimflag.can_dig(5,pointed_thing.under,user,false,2)
	end,
})

minetest.register_craft({
	output = claimflag.node .. " 4",
	recipe = {
		{"default:stone","default:stone","default:stone"},
		{"default:stone","default:steel_ingot","default:stone"},
		{"default:stone","default:stone","default:stone"},
	}
})
minetest.register_craft({
	output = claimflag.item,
	recipe = {
		{claimflag.node},
		{'default:stick'},
	}
})

minetest.register_entity("claimflag:display", {
	physical = false,
	collisionbox = {0,0,0,0,0,0},
	visual = "wielditem",
	visual_size = {x=1.0/1.5,y=1.0/1.5}, -- wielditem seems to be scaled to 1.5 times original node size
	textures = {"claimflag:display_node"},
	on_step = function(self, dtime)
		if minetest.get_node(self.object:getpos()).name ~= claimflag.node then
			self.object:remove()
			return
		end
	end,
})

-- Display-zone node.
-- Do NOT place the display as a node
-- it is made to be used as an entity (see above)
minetest.register_node("claimflag:display_node", {
	tiles = {"claim_display.png"},
	use_texture_alpha = true,
	walkable = false,
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			-- sides
			{-5.55, -5.55, -5.55, -5.45, 5.55, 5.55},
			{-5.55, -5.55, 5.45, 5.55, 5.55, 5.55},
			{5.45, -5.55, -5.55, 5.55, 5.55, 5.55},
			{-5.55, -5.55, -5.55, 5.55, 5.55, -5.45},
			-- top
			{-5.55, 5.45, -5.55, 5.55, 5.55, 5.55},
			-- bottom
			{-5.55, -5.55, -5.55, 5.55, -5.45, 5.55},
			-- middle (surround claimflag)
			{ -0.5,-0.5,-0.5,0.5,-0.48, 0.5}
		},
	},
	selection_box = {
		type = "regular",
	},
	paramtype = "light",
	groups = {dig_immediate=3,not_in_creative_inventory=1},
	drop = "",
})

