--[[
	CharacterModels  (ModuleScript)
	WHERE IT GOES: ReplicatedStorage > Characters > CharacterModels

	Appearance SPECS for the roster, read straight off the reference art, and
	consumed by ServerStorage.CharacterModelFactory to build themed R6 rigs (for
	campaign bosses and for display statues). Pure data — colors are {r,g,b}.

	Spec fields (all optional except a name is inferred from the key):
	  scale        number (1 = player-size; bosses use ~1.6)
	  material     Enum.Material name string ("Metal" for robots, etc.)
	  body/limbs/legs/skin   {r,g,b}
	  hair         {r,g,b}          spiky anime hair on top
	  eyes         {r,g,b} + eyeStyle "dual"|"single"|"visor"
	  hood         {r,g,b} + hoodGlow {r,g,b}   shadowed cowl w/ glowing eyes
	  tvHead       true (+ screen {r,g,b})      Channel-style monitor head
	  emblem       { text="E", color={..}, plate={..} }   chest logo
	  chestEye     {r,g,b}          glowing eye on the chest (Red Eye)
	  cape         {r,g,b}
	  tentacles    N (+ tentacleColor/tentacleTip)   back tentacles
	  aura         "fire"|"electric"|"void"|"energy"|"holy"|"gold"|"ice"|"green" (+ auraColor)
	  health/walkSpeed  used when spawned as a boss/NPC

	Adding a character = adding a spec here; no factory changes.
]]

local M = {}

-- ============================ HEROES / LEGENDS ============================

M["Titan"] = { scale = 1, body = { 40, 44, 54 }, limbs = { 34, 38, 48 }, skin = { 220, 180, 150 },
	hair = { 24, 20, 24 }, aura = "fire", auraColor = { 255, 90, 40 }, eyes = { 255, 120, 60 } }

M["Red Rocket"] = { body = { 200, 40, 44 }, limbs = { 170, 34, 38 }, skin = { 120, 78, 52 },
	hair = { 20, 16, 16 }, aura = "fire", emblem = { text = "RR", color = { 240, 220, 60 }, plate = { 170, 30, 34 } } }

M["Looney"] = { body = { 232, 234, 240 }, limbs = { 232, 234, 240 }, legs = { 240, 210, 70 }, skin = { 225, 185, 150 },
	hair = { 20, 18, 22 }, emblem = { text = "E", color = { 240, 200, 60 }, plate = { 240, 242, 248 } } }

M["Erik"] = { body = { 20, 20, 26 }, limbs = { 18, 18, 24 }, skin = { 210, 175, 150 },
	hair = { 16, 14, 18 }, cape = { 14, 14, 20 }, eyes = { 170, 70, 255 }, aura = "void",
	emblem = { text = "◎", color = { 170, 70, 255 }, plate = { 24, 20, 32 } } }

M["Red Eye"] = { body = { 40, 92, 185 }, limbs = { 34, 82, 170 }, skin = { 40, 92, 185 },
	eyes = { 235, 40, 40 }, eyeStyle = "single", chestEye = { 235, 40, 40 } }

M["Phase"] = { body = { 18, 18, 24 }, limbs = { 16, 16, 22 }, skin = { 205, 170, 148 },
	hair = { 16, 14, 18 }, aura = "void", auraColor = { 150, 60, 255 }, eyes = { 150, 90, 255 } }

M["Glitch"] = { body = { 20, 18, 28 }, limbs = { 18, 16, 26 }, hood = { 16, 14, 24 }, hoodGlow = { 60, 240, 220 },
	aura = "energy", auraColor = { 220, 60, 210 } }

M["The Engineer"] = { body = { 26, 28, 34 }, limbs = { 30, 32, 40 }, skin = { 20, 22, 28 },
	eyeStyle = "visor", eyes = { 60, 150, 255 }, tentacles = 4, tentacleColor = { 70, 74, 84 }, tentacleTip = { 255, 210, 90 },
	aura = "gold", auraColor = { 255, 210, 90 } }

M["Frost"] = { body = { 150, 200, 235 }, limbs = { 130, 185, 225 }, skin = { 210, 235, 250 },
	hair = { 235, 245, 255 }, aura = "ice", eyes = { 150, 220, 255 } }

M["Ice Man"] = { body = { 170, 215, 245 }, limbs = { 150, 200, 235 }, skin = { 220, 240, 252 },
	hair = { 240, 248, 255 }, aura = "ice", eyes = { 180, 235, 255 } }

M["Water Woman"] = { body = { 30, 110, 200 }, limbs = { 26, 96, 180 }, skin = { 90, 60, 46 },
	hair = { 30, 40, 70 }, aura = "energy", auraColor = { 90, 180, 255 }, eyes = { 120, 210, 255 } }

-- Chasm — teen energy manipulator: blue kinetic energy, spiky blue-tinted hair
M["Chasm"] = { body = { 24, 34, 54 }, limbs = { 30, 44, 70 }, skin = { 215, 180, 150 },
	hair = { 40, 90, 200 }, aura = "energy", auraColor = { 60, 170, 255 }, eyes = { 120, 200, 255 } }

-- Leon — ruler's mastery, half-demon, master armor: dark suit, red/gold accents
M["Leon"] = { body = { 22, 22, 28 }, limbs = { 120, 30, 34 }, skin = { 210, 172, 146 },
	hair = { 18, 16, 20 }, aura = "cosmic", auraColor = { 255, 200, 120 }, eyes = { 255, 210, 120 } }

M["Dead Dash"] = { body = { 22, 22, 28 }, limbs = { 18, 18, 24 }, skin = { 22, 22, 28 },
	eyes = { 240, 245, 255 }, aura = "electric", emblem = { text = "⚡", color = { 240, 245, 255 }, plate = { 30, 30, 38 } } }

M["Green Grenade"] = { body = { 26, 30, 30 }, limbs = { 40, 46, 44 }, skin = { 90, 62, 46 },
	hair = { 30, 26, 24 }, aura = "green", auraColor = { 90, 240, 120 }, emblem = { text = "✸", color = { 90, 240, 120 }, plate = { 24, 28, 26 } } }

M["Imp"] = { body = { 18, 18, 26 }, limbs = { 16, 16, 24 }, skin = { 205, 170, 148 },
	hair = { 16, 14, 18 }, aura = "electric", auraColor = { 90, 150, 255 }, eyes = { 120, 180, 255 } }

M["The Squelch"] = { body = { 90, 150, 210 }, limbs = { 78, 135, 195 }, skin = { 120, 175, 225 },
	eyes = { 240, 245, 255 } }

M["Onix"] = { scale = 1.15, body = { 28, 26, 34 }, limbs = { 40, 34, 30 }, skin = { 60, 46, 40 },
	aura = "gold", auraColor = { 255, 200, 90 }, eyes = { 255, 200, 90 } }

M["Iron Pirate"] = { scale = 1.1, body = { 28, 26, 24 }, limbs = { 40, 36, 30 }, material = "Metal",
	eyes = { 240, 200, 90 }, eyeStyle = "dual", aura = "gold", auraColor = { 240, 200, 90 } }

M["Mr Universe"] = { scale = 1.1, body = { 230, 232, 240 }, limbs = { 220, 222, 232 }, skin = { 40, 44, 80 },
	aura = "holy", emblem = { text = "∞", color = { 90, 180, 255 }, plate = { 240, 242, 248 } }, eyes = { 120, 200, 255 } }

M["Megabot"] = { scale = 1.2, body = { 90, 96, 108 }, limbs = { 74, 80, 92 }, material = "Metal",
	eyes = { 80, 180, 255 }, eyeStyle = "single", chestEye = { 80, 180, 255 }, aura = "energy" }

M["Oryiox"] = { scale = 1.1, body = { 225, 228, 236 }, limbs = { 205, 210, 222 }, material = "Metal",
	aura = "energy", auraColor = { 90, 170, 255 }, eyes = { 120, 200, 255 }, eyeStyle = "visor" }

M["Daniel Storm"] = { body = { 235, 236, 242 }, limbs = { 225, 226, 234 }, skin = { 90, 62, 46 },
	hair = { 20, 18, 22 }, aura = "electric", auraColor = { 255, 210, 90 }, eyes = { 255, 225, 120 } }

M["Celestial Guard"] = { scale = 1.1, body = { 235, 232, 220 }, limbs = { 220, 210, 170 },
	skin = { 120, 82, 54 }, hair = { 235, 210, 120 }, aura = "holy", eyes = { 255, 245, 190 } }

M["Starforge"] = { body = { 26, 22, 38 }, limbs = { 34, 28, 50 }, aura = "void", auraColor = { 160, 90, 255 },
	eyes = { 190, 130, 255 } }

-- Titan-gem forms
M["True Gold Titan"] = { scale = 1.25, body = { 235, 190, 60 }, limbs = { 210, 165, 45 }, material = "Metal",
	aura = "gold", eyes = { 255, 240, 150 } }
M["True Silver Titan"] = { scale = 1.25, body = { 205, 210, 220 }, limbs = { 180, 186, 198 }, material = "Metal",
	aura = "ice", auraColor = { 200, 220, 245 }, eyes = { 220, 235, 250 } }
M["Red Titan"] = { scale = 1.3, body = { 190, 40, 40 }, limbs = { 150, 30, 30 }, aura = "fire",
	eyes = { 255, 120, 90 } }
M["Green Titan"] = { scale = 1.3, body = { 50, 170, 70 }, limbs = { 40, 140, 58 }, aura = "green",
	eyes = { 150, 255, 160 } }

-- ============================ VILLAINS / BOSSES ============================

M["Manderin"] = { scale = 1.6, body = { 232, 234, 240 }, limbs = { 30, 32, 40 }, skin = { 20, 22, 28 },
	tentacles = 4, tentacleColor = { 24, 26, 32 }, tentacleTip = { 60, 150, 255 },
	aura = "energy", auraColor = { 60, 150, 255 },
	emblem = { text = "M", color = { 60, 150, 255 }, plate = { 20, 22, 28 } }, health = 2200 }

M["The Anonymous"] = { scale = 1.6, body = { 16, 14, 24 }, limbs = { 14, 12, 22 },
	hood = { 12, 10, 20 }, hoodGlow = { 170, 70, 255 }, cape = { 12, 10, 20 },
	aura = "void", auraColor = { 150, 60, 255 }, health = 2600 }

M["Void Overlord"] = { scale = 1.7, body = { 20, 14, 30 }, limbs = { 26, 18, 40 },
	hood = { 16, 10, 26 }, hoodGlow = { 160, 60, 255 }, cape = { 14, 10, 24 },
	tentacles = 2, tentacleColor = { 22, 14, 34 }, tentacleTip = { 160, 60, 255 },
	aura = "void", auraColor = { 150, 55, 255 }, health = 2400 }

M["Nemesis"] = { scale = 1.6, body = { 16, 16, 22 }, limbs = { 14, 14, 20 }, skin = { 18, 18, 24 },
	hood = { 12, 12, 18 }, hoodGlow = { 160, 70, 255 }, cape = { 12, 12, 18 }, hair = { 14, 12, 18 },
	aura = "void", auraColor = { 150, 60, 255 }, health = 2400 }

M["Minus"] = { scale = 1.5, body = { 46, 108, 58 }, limbs = { 38, 92, 50 }, skin = { 52, 118, 62 },
	eyes = { 235, 60, 50 }, health = 1800 }

M["Null"] = { scale = 1.55, body = { 14, 14, 20 }, limbs = { 12, 12, 18 },
	hood = { 10, 10, 16 }, hoodGlow = { 150, 60, 255 }, cape = { 10, 10, 16 },
	aura = "void", health = 2000 }

M["Omega"] = { scale = 1.6, body = { 18, 18, 24 }, limbs = { 16, 16, 22 }, skin = { 205, 170, 148 },
	hair = { 16, 14, 18 }, cape = { 14, 14, 20 }, eyes = { 240, 245, 255 }, aura = "cosmic",
	emblem = { text = "Ω", color = { 235, 60, 50 }, plate = { 18, 18, 24 } }, health = 3000 }

-- Old Man Omega — normal Omega but greyed with a beard (strongest variant)
M["Old Man Omega"] = { scale = 1.6, body = { 18, 18, 24 }, limbs = { 16, 16, 22 }, skin = { 200, 168, 148 },
	hair = { 180, 182, 188 }, beard = { 190, 192, 198 }, cape = { 14, 14, 20 }, eyes = { 240, 245, 255 },
	aura = "cosmic", emblem = { text = "Ω", color = { 235, 60, 50 }, plate = { 18, 18, 24 } }, health = 3400 }

-- Carnage — modeled from DESCRIPTION (no clear reference): "god of fear",
-- metallic blood-red alien with horns, sharp teeth, claws and a fear aura
M["Carnage"] = { scale = 1.5, body = { 120, 20, 26 }, limbs = { 96, 16, 22 }, skin = { 110, 18, 22 },
	material = "Metal", horns = { 60, 12, 16 }, eyes = { 255, 60, 50 }, cape = { 70, 12, 18 },
	aura = "void", auraColor = { 200, 30, 50 }, health = 2400 }

M["Armageddon"] = { scale = 1.75, body = { 16, 16, 20 }, limbs = { 120, 96, 40 }, material = "Metal",
	eyes = { 235, 50, 40 }, eyeStyle = "dual", cape = { 12, 12, 16 }, aura = "void", auraColor = { 200, 60, 60 },
	health = 3500 }

M["Rynox"] = { scale = 1.6, body = { 20, 20, 24 }, limbs = { 150, 30, 34 }, skin = { 18, 18, 22 },
	eyes = { 235, 40, 40 }, eyeStyle = "dual", aura = "fire", auraColor = { 200, 40, 40 }, health = 2600 }

M["Sugoro"] = { scale = 1.8, body = { 120, 30, 34 }, limbs = { 96, 24, 28 }, skin = { 110, 28, 30 },
	eyes = { 255, 60, 50 }, aura = "void", auraColor = { 200, 40, 60 },
	tentacles = 2, tentacleColor = { 90, 22, 26 }, tentacleTip = { 255, 60, 50 }, health = 3200 }

M["Dragon"] = { scale = 1.65, body = { 16, 18, 26 }, limbs = { 30, 40, 70 }, skin = { 60, 90, 150 },
	cape = { 14, 16, 24 }, eyes = { 90, 170, 255 }, aura = "void", auraColor = { 80, 140, 255 }, health = 3200 }

M["Channel"] = { scale = 1.5, body = { 22, 24, 30 }, limbs = { 26, 28, 36 }, material = "Metal",
	tvHead = true, screen = { 190, 215, 220 }, aura = "energy", auraColor = { 90, 220, 210 }, health = 1900 }

-- ======================= EXTENDED ROSTER (from the four sheets) =======================
-- Colors read off the art; a few are description-based where the image isn't the guide.

M["Jumper"]        = { body = { 24, 20, 34 }, limbs = { 22, 18, 32 }, hair = { 16, 14, 20 }, aura = "void", auraColor = { 160, 70, 255 }, eyes = { 180, 110, 255 } }
M["Prometheus"]    = { body = { 30, 96, 175 }, limbs = { 210, 180, 90 }, skin = { 90, 60, 46 }, hair = { 20, 30, 60 }, aura = "energy", auraColor = { 90, 180, 255 }, eyes = { 130, 210, 255 } }
M["Bullet Train"]  = { body = { 22, 26, 40 }, limbs = { 34, 60, 120 }, eyeStyle = "visor", eyes = { 80, 180, 255 }, aura = "electric" }
M["Patriot"]       = { body = { 40, 60, 140 }, limbs = { 170, 40, 44 }, skin = { 215, 180, 150 }, hair = { 60, 40, 24 }, emblem = { text = "★", color = { 245, 245, 250 }, plate = { 40, 60, 140 } }, eyes = { 120, 200, 255 } }
M["Champion Bot"]  = { scale = 1.15, body = { 96, 102, 114 }, limbs = { 78, 84, 96 }, material = "Metal", eyeStyle = "single", eyes = { 80, 180, 255 }, chestEye = { 80, 180, 255 } }
M["Bone Crusher"]  = { scale = 1.15, body = { 196, 186, 158 }, limbs = { 170, 160, 134 }, skin = { 210, 200, 172 }, horns = { 150, 140, 116 }, eyes = { 235, 60, 50 } }
M["Liberty"]       = { body = { 40, 60, 120 }, limbs = { 34, 50, 105 }, skin = { 210, 172, 146 }, hair = { 235, 240, 248 }, aura = "electric", eyes = { 120, 200, 255 } }
M["Battle Squid"]  = { scale = 1.1, body = { 90, 40, 140 }, limbs = { 74, 32, 120 }, tentacles = 2, tentacleColor = { 80, 34, 128 }, tentacleTip = { 190, 120, 255 }, aura = "electric", eyes = { 200, 120, 255 } }
M["Reddon"]        = { body = { 24, 22, 26 }, limbs = { 170, 34, 38 }, eyes = { 235, 50, 50 }, aura = "electric", auraColor = { 230, 60, 60 } }
M["Caped Crusader"] = { body = { 36, 88, 52 }, limbs = { 30, 74, 44 }, cape = { 235, 205, 70 }, aura = "energy", auraColor = { 120, 220, 140 }, eyes = { 120, 230, 150 } }
M["Golden Girl"]   = { body = { 235, 190, 60 }, limbs = { 210, 165, 45 }, skin = { 240, 205, 90 }, hair = { 245, 220, 120 }, aura = "gold", eyes = { 255, 240, 150 } }
M["Hela"]          = { body = { 40, 120, 70 }, limbs = { 235, 236, 240 }, skin = { 210, 172, 146 }, hair = { 20, 30, 24 }, aura = "holy", auraColor = { 120, 255, 160 }, eyes = { 150, 255, 170 } }
M["X"]             = { body = { 26, 22, 26 }, limbs = { 130, 34, 36 }, skin = { 210, 172, 146 }, hair = { 16, 14, 18 }, aura = "fire", eyes = { 255, 120, 70 } }
M["Estiss"]        = { body = { 210, 200, 180 }, limbs = { 180, 168, 146 }, skin = { 215, 180, 150 }, hair = { 235, 235, 240 }, beard = { 235, 235, 240 }, aura = "gold", eyes = { 255, 210, 120 } }
M["Gale"]          = { body = { 120, 124, 132 }, limbs = { 96, 100, 108 }, skin = { 210, 172, 146 }, hair = { 235, 235, 240 }, beard = { 235, 235, 240 }, aura = "gold", eyes = { 255, 220, 130 } }
M["Morbius"]       = { scale = 1.1, body = { 22, 18, 30 }, limbs = { 20, 16, 28 }, hood = { 16, 12, 24 }, hoodGlow = { 160, 70, 255 }, tentacles = 2, tentacleColor = { 24, 16, 34 }, tentacleTip = { 160, 70, 255 }, aura = "void" }
M["Star Man"]      = { body = { 235, 236, 242 }, limbs = { 210, 180, 90 }, skin = { 210, 172, 146 }, hair = { 90, 70, 40 }, emblem = { text = "★", color = { 245, 205, 80 }, plate = { 235, 236, 242 } }, aura = "holy", eyes = { 255, 235, 150 } }
M["Zero"]          = { body = { 18, 16, 26 }, limbs = { 16, 14, 24 }, aura = "cosmic", eyes = { 150, 120, 255 }, emblem = { text = "O", color = { 150, 120, 255 }, plate = { 18, 16, 26 } } }
M["Beast"]         = { scale = 1.35, body = { 40, 70, 140 }, limbs = { 34, 60, 125 }, eyes = { 235, 50, 50 }, chestEye = { 235, 50, 50 }, aura = "electric" }
M["Wolf"]          = { body = { 40, 42, 48 }, limbs = { 34, 36, 42 }, skin = { 46, 48, 54 }, eyes = { 235, 210, 90 } }
M["Golddon"]       = { body = { 235, 190, 60 }, limbs = { 210, 165, 45 }, skin = { 240, 205, 90 }, aura = "gold", eyes = { 255, 240, 150 } }
M["Golden Knight"] = { scale = 1.1, body = { 225, 185, 70 }, limbs = { 205, 165, 55 }, material = "Metal", aura = "gold", eyes = { 255, 240, 150 } }
M["Electra"]       = { body = { 40, 60, 120 }, limbs = { 34, 50, 105 }, skin = { 210, 172, 146 }, hair = { 20, 24, 40 }, aura = "electric", eyes = { 120, 200, 255 } }
M["Valkery"]       = { body = { 60, 80, 120 }, limbs = { 180, 186, 198 }, skin = { 210, 172, 146 }, hair = { 200, 180, 120 }, cape = { 90, 110, 150 }, aura = "holy", eyes = { 150, 210, 255 } }
M["Nejhora"]       = { scale = 1.55, body = { 40, 70, 150 }, limbs = { 34, 60, 135 }, aura = "cosmic", auraColor = { 90, 150, 255 }, eyes = { 120, 200, 255 } }
M["Super Guy"]     = { body = { 40, 60, 140 }, limbs = { 40, 56, 130 }, skin = { 215, 180, 150 }, hair = { 30, 26, 30 }, cape = { 150, 30, 34 }, emblem = { text = "S", color = { 200, 40, 44 }, plate = { 40, 60, 140 } }, eyes = { 235, 60, 60 } }
M["Jhaunju"]       = { body = { 24, 22, 28 }, limbs = { 120, 30, 34 }, skin = { 210, 172, 146 }, hair = { 235, 235, 240 }, aura = "cosmic", auraColor = { 255, 200, 120 }, eyes = { 255, 210, 120 } }
M["Mercy"]         = { body = { 22, 18, 30 }, limbs = { 40, 26, 56 }, skin = { 205, 168, 146 }, hair = { 235, 235, 240 }, aura = "void", eyes = { 190, 120, 255 } }
M["Puppet Master"] = { body = { 22, 20, 26 }, limbs = { 20, 18, 24 }, eyes = { 235, 50, 50 }, aura = "void", auraColor = { 160, 60, 220 } }

M["Atom"]          = { body = { 22, 26, 22 }, limbs = { 20, 24, 20 }, aura = "green", eyes = { 120, 255, 120 } }
M["Phoenix"]       = { body = { 40, 20, 18 }, limbs = { 120, 40, 24 }, skin = { 210, 172, 146 }, hair = { 20, 16, 16 }, cape = { 180, 60, 24 }, aura = "fire", eyes = { 255, 150, 60 } }
M["Fission"]       = { body = { 24, 24, 30 }, limbs = { 40, 44, 54 }, skin = { 210, 172, 146 }, hair = { 235, 235, 240 }, aura = "energy", eyes = { 120, 200, 255 } }
M["MechaManiac"]   = { scale = 1.2, body = { 30, 34, 40 }, limbs = { 44, 48, 56 }, material = "Metal", eyes = { 120, 255, 120 }, aura = "energy", auraColor = { 120, 255, 120 } }
M["The Collector"] = { body = { 30, 22, 40 }, limbs = { 26, 20, 36 }, aura = "void", auraColor = { 150, 90, 220 }, eyes = { 180, 130, 255 } }
M["Blue Jay"]      = { body = { 40, 90, 190 }, limbs = { 34, 78, 170 }, cape = { 60, 130, 220 }, eyeStyle = "visor", eyes = { 120, 210, 255 }, aura = "energy" }
M["Yellow Jacket"] = { body = { 235, 200, 60 }, limbs = { 30, 30, 34 }, cape = { 235, 200, 60 }, aura = "energy", auraColor = { 255, 220, 90 }, eyes = { 255, 230, 120 } }
M["Slimey"]        = { body = { 90, 210, 90 }, limbs = { 76, 190, 78 }, skin = { 120, 230, 110 }, aura = "green", eyes = { 200, 255, 190 } }
M["Powernoid"]     = { body = { 28, 24, 28 }, limbs = { 150, 40, 90 }, material = "Metal", aura = "energy", auraColor = { 230, 70, 150 }, eyes = { 235, 70, 150 } }
M["Punisher"]      = { body = { 22, 20, 24 }, limbs = { 34, 30, 34 }, eyes = { 235, 40, 40 }, aura = "electric", auraColor = { 230, 50, 50 } }
M["2z"]            = { body = { 170, 34, 38 }, limbs = { 40, 60, 150 }, tentacles = 4, tentacleColor = { 30, 30, 34 }, tentacleTip = { 200, 40, 44 }, eyes = { 240, 245, 255 }, aura = "electric" }
M["Cockroach"]     = { body = { 46, 36, 28 }, limbs = { 38, 30, 22 }, horns = { 30, 24, 18 }, eyes = { 235, 60, 50 } }
M["Juggernaut"]    = { scale = 1.25, body = { 30, 32, 40 }, limbs = { 44, 46, 54 }, horns = { 26, 28, 34 }, eyes = { 90, 180, 255 } }
M["Bulldozer"]     = { scale = 1.15, body = { 96, 100, 108 }, limbs = { 74, 78, 88 }, material = "Metal", eyeStyle = "visor", eyes = { 90, 180, 255 }, aura = "energy", auraColor = { 120, 190, 255 } }
M["Scrapatron"]    = { scale = 1.3, body = { 70, 78, 66 }, limbs = { 58, 64, 54 }, material = "Metal", aura = "green", eyes = { 120, 255, 120 } }
M["Celcius"]       = { body = { 150, 205, 240 }, limbs = { 130, 190, 230 }, skin = { 210, 235, 250 }, hair = { 240, 248, 255 }, aura = "ice", eyes = { 170, 235, 255 } }
M["Fahrenheit"]    = { body = { 40, 20, 18 }, limbs = { 130, 40, 22 }, aura = "fire", eyes = { 255, 130, 50 } }
M["Ultratron"]     = { scale = 1.25, body = { 28, 26, 30 }, limbs = { 42, 40, 44 }, material = "Metal", eyeStyle = "single", eyes = { 235, 50, 40 }, aura = "fire", auraColor = { 230, 60, 40 } }
M["Omnicron"]      = { scale = 1.45, body = { 26, 28, 34 }, limbs = { 40, 44, 52 }, material = "Metal", eyes = { 235, 50, 40 }, chestEye = { 235, 50, 40 } }
M["Alien X"]       = { body = { 20, 20, 26 }, limbs = { 18, 18, 24 }, aura = "electric", eyes = { 120, 200, 255 } }
M["The One Who Laughs"] = { body = { 22, 18, 28 }, limbs = { 20, 16, 26 }, hair = { 60, 200, 90 }, aura = "void", auraColor = { 170, 70, 255 }, eyes = { 150, 255, 120 } }
M["Bloodbath"]     = { scale = 1.3, body = { 130, 20, 24 }, limbs = { 104, 16, 20 }, aura = "fire", auraColor = { 220, 30, 40 }, eyes = { 255, 60, 50 } }
M["Dark Looney"]   = { body = { 14, 14, 18 }, limbs = { 12, 12, 16 }, eyes = { 235, 50, 50 }, aura = "void" }
M["The Anaconda"]  = { scale = 1.4, body = { 40, 110, 60 }, limbs = { 34, 96, 52 }, aura = "cosmic", auraColor = { 120, 255, 140 }, eyes = { 150, 255, 150 } }
M["Purpurs"]       = { scale = 1.6, body = { 90, 40, 150 }, limbs = { 76, 34, 130 }, cape = { 70, 30, 120 }, aura = "void", auraColor = { 160, 70, 255 }, eyes = { 200, 120, 255 } }
M["Monster Boy"]   = { body = { 40, 120, 60 }, limbs = { 34, 104, 52 }, aura = "green", eyes = { 150, 255, 150 } }
M["Scar"]          = { scale = 1.1, body = { 150, 110, 60 }, limbs = { 130, 94, 50 }, hair = { 180, 120, 50 }, eyes = { 245, 210, 90 } }
M["Toxic"]         = { body = { 30, 46, 30 }, limbs = { 40, 60, 40 }, aura = "green", eyes = { 150, 255, 120 } }
M["Rocky"]         = { body = { 24, 22, 30 }, limbs = { 22, 20, 28 }, hair = { 16, 14, 20 }, aura = "energy", auraColor = { 170, 90, 255 }, eyes = { 190, 120, 255 } }
M["Ultramega"]     = { scale = 1.55, body = { 20, 20, 26 }, limbs = { 18, 18, 24 }, hair = { 200, 202, 208 }, cape = { 14, 14, 20 }, aura = "cosmic", emblem = { text = "Ω", color = { 235, 60, 50 }, plate = { 20, 20, 26 } }, eyes = { 240, 245, 255 } }
M["Midas"]         = { body = { 230, 185, 55 }, limbs = { 205, 160, 45 }, skin = { 240, 205, 90 }, aura = "gold", eyes = { 255, 240, 150 } }
M["Ares"]          = { scale = 1.1, body = { 150, 30, 34 }, limbs = { 120, 24, 28 }, material = "Metal", horns = { 100, 20, 24 }, eyes = { 255, 80, 60 } }
M["Kratos"]        = { scale = 1.1, body = { 180, 175, 165 }, limbs = { 160, 155, 146 }, skin = { 195, 190, 180 }, eyes = { 235, 60, 50 } }
M["Infinity"]      = { body = { 24, 24, 34 }, limbs = { 34, 34, 50 }, hair = { 20, 20, 30 }, aura = "cosmic", auraColor = { 120, 200, 255 }, eyes = { 130, 220, 255 } }
M["Cosmo"]         = { body = { 18, 16, 28 }, limbs = { 16, 14, 26 }, aura = "cosmic", eyes = { 180, 130, 255 } }
M["Apex"]          = { body = { 26, 24, 28 }, limbs = { 22, 20, 24 }, eyes = { 245, 210, 90 } }
M["Heat Wave"]     = { body = { 40, 20, 18 }, limbs = { 130, 44, 24 }, aura = "fire", eyes = { 255, 140, 50 } }
M["Blaze"]         = { body = { 40, 20, 18 }, limbs = { 150, 40, 22 }, aura = "fire", eyes = { 255, 120, 50 } }
M["Ghost"]         = { body = { 150, 160, 175 }, limbs = { 135, 145, 160 }, aura = "energy", auraColor = { 150, 200, 255 }, eyes = { 200, 230, 255 } }
M["Volt"]          = { body = { 20, 20, 28 }, limbs = { 18, 18, 26 }, aura = "electric", eyes = { 120, 200, 255 } }
M["Blackout"]      = { body = { 14, 12, 18 }, limbs = { 12, 10, 16 }, aura = "void", eyes = { 170, 90, 255 } }
M["Void Walker"]   = { body = { 20, 16, 30 }, limbs = { 18, 14, 28 }, aura = "void", eyes = { 180, 110, 255 } }
M["Virgil"]        = { body = { 26, 20, 38 }, limbs = { 22, 18, 34 }, aura = "void", auraColor = { 150, 90, 220 }, eyes = { 180, 120, 255 } }
M["Champion"]      = { body = { 40, 56, 36 }, limbs = { 34, 48, 30 }, skin = { 210, 172, 146 }, eyes = { 150, 220, 120 } }
M["Lockdown"]      = { body = { 22, 20, 24 }, limbs = { 34, 30, 34 }, eyeStyle = "single", eyes = { 235, 50, 40 }, aura = "energy", auraColor = { 230, 60, 50 } }
M["Fallout"]       = { body = { 40, 38, 22 }, limbs = { 60, 56, 30 }, aura = "green", eyes = { 235, 60, 50 } }
M["Bloody Soldier"] = { body = { 40, 18, 20 }, limbs = { 120, 24, 28 }, skin = { 205, 168, 146 }, hair = { 235, 235, 240 }, aura = "fire", auraColor = { 220, 30, 40 }, eyes = { 255, 60, 50 } }
M["Nightmare"]     = { scale = 1.5, body = { 14, 14, 18 }, limbs = { 12, 12, 16 }, hood = { 10, 10, 14 }, hoodGlow = { 245, 210, 60 }, cape = { 10, 10, 14 }, aura = "void", health = 2200 }
-- El Primo Libre — drug-lord pro wrestler: gold wrestling mask, black suit,
-- golden knuckles, a thousand pounds of muscle. Season 1 mini-boss.
M["El Primo Libre"] = { scale = 1.4, body = { 20, 20, 24 }, limbs = { 26, 26, 30 }, skin = { 235, 190, 60 },
	material = "SmoothPlastic", aura = "gold", auraColor = { 255, 205, 80 }, eyes = { 30, 30, 34 }, health = 1100 }

M["Star Forge"]    = M["Starforge"]   -- alias for the alternate spelling on the sheet

return M
