# Lua 5.3 runtime with stubs of the Isaac API the tracker uses, and helpers shared by the tests; the tests import it with `from stubs import *`.
import pathlib
from lupa.lua53 import LuaRuntime  # game runs Lua 5.3
repo = pathlib.Path(__file__).resolve().parents[1]  # the ReHUD repo
GAME = pathlib.Path(r'C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth')
lua = LuaRuntime()
load_error = lua.eval('function(s, n) local f, e = load(s, n); return e end')
for f in [repo/'main.lua', *sorted((repo/'scripts').glob('*.lua'))]:
    r = load_error(f.read_text(encoding='utf-8'), f.name)
    assert r is None, (f, r); print('syntax ok', f.name)
lua.execute(r'''
ItemType = { ITEM_PASSIVE = 1, ITEM_ACTIVE = 3, ITEM_FAMILIAR = 4 }
PlayerType = { PLAYER_LAZARUS_B = 29, PLAYER_LAZARUS2_B = 38, PLAYER_THESOUL_B = 40 } -- checked against enums.lua below
local items = {}
for i = 1, 20 do items[i] = { Type = 1, GfxFileName = "item" .. i } end
Isaac = { GetItemConfig = function() return {
  GetCollectibles = function() return { Size = 21 } end,
  GetCollectible = function(_, id) return items[id] end } end }
floorName = "B1"
Game = function() return { GetLevel = function() return { GetName = function() return floorName end } end } end
CollectibleType = { COLLECTIBLE_ESAU_JR = 13 } -- stub id (703 in enums.lua, checked in test_coop): the item stubs stop at 20
EntityType = { ENTITY_FAMILIAR = 3 }; FamiliarVariant = { ITEM_WISP = 237 } -- checked against enums.lua below
wispList = {}
Isaac.FindByType = function(t, v) assert(t == 3 and v == 237); return wispList end
GetPtrHash = function(e) return e.seed end
function mkwisp(id, seed) return { SubType = id, Player = seed and { seed = seed }, ToFamiliar = function(self) return self end } end
function mkplayer(real, mod, variant, ghost, seed)
  return { Variant = variant, seed = seed, ghost = ghost,
    GetPlayerType = function(self) return self.ptype or 0 end,
    GetCollectibleRNG = function(self, id) assert(id == 1); return { GetSeed = function() return self.seed end } end,
    GetCollectibleNum = function(self, id, onlyTrue) return (real[id] or 0) + (onlyTrue and 0 or (mod[id] or 0)) end,
    GetCollectibleCount = function(self) local n = 0; for _, c in pairs(real) do n = n + c end; return n end,
    GetZodiacEffect = function(self) return self.zodiac or 0 end,
    IsCoopGhost = function() return ghost end }
end
''')
src = (repo/'scripts'/'tracker.lua').read_text(encoding='utf-8')
# include re-runs the file, so every fresh tracker gets a fresh roster
g = lua.globals(); g.REPO = str(repo)
lua.execute('include = function(name) return dofile(REPO .. "/" .. name:gsub("%.", "/") .. ".lua") end')
fresh = lambda: lua.execute(src)
def P(real={}, mod={}, variant=0, ghost=False, seed=None, ptype=0):
    p = g.mkplayer(lua.table_from(real), lua.table_from(mod), variant, ghost, seed); p.ptype = ptype
    return p
def L(*ps):
    for i, p in ps:
        if p.seed is None: p.seed = 1000 + i  # default identity: stable per index
        if p.ControllerIndex is None: p.ControllerIndex = i  # default: one human per index
    return lua.table_from([lua.table_from({'index': i, 'player': p, 'ghost': p.ghost}) for i, p in ps])
# entries/owners: what is listed by default; gone: entries of players who left (kept, hidden unless showLeft)
def entries(T): return [(e.id, e.number, e.floor, e.temporary) for e in T.entries.values() if not e.left]
def owners(T): return [e.owner for e in T.entries.values() if not e.left]
def gone(T): return [(e.id, e.number, e.floor, e.temporary) for e in T.entries.values() if e.left]
ok = lambda name: print('PASS', name)
def W(*specs): g.wispList = lua.table_from([g.mkwisp(i, s) for i, s in specs])  # item wisps as (item id, owner seed or None)
def run(T, ps, n=31):
    for _ in range(n): T.update(ps)
