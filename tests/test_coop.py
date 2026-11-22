import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))  # -I leaves the script's folder off sys.path
from stubs import *

T = fresh(); T.update(L((0, P({1:1,2:1})))); assert entries(T) == [(1,0,'B1',False),(2,0,'B1',False)]; ok('single player')
T = fresh(); T.update(L((0, P({3:1})), (1, P({3:1})))); assert entries(T) == [(3,0,'B1',False),(3,1,'B1',False)]; ok('same item on Jacob and Esau -> two entries, numbered 1 and 2')
T = fresh(); run(T, L((0, P({})), (1, P({4:1})))); run(T, L((0, P({}, {4:1})), (1, P({4:1})))); assert entries(T) == [(4,1,'B1',False),(4,0,'B1',True)]; ok('temporary is per player')
# innate items: modifier-only items present while a character settles (first sight or a type change) are innate, later ones temporary
cain = lambda mod: L((0, P({1:1,2:1}, mod, seed=500, ptype=2)))  # started Cain: Lucky Foot owned 1 + innate 1
T = fresh(); run(T, cain({2:1})); assert entries(T) == [(1,0,'B1',False),(2,0,'B1',False),(2,0,'B1',False)], entries(T); ok('started Cain: owned + innate Lucky Foot = two icons, neither temporary')
run(T, cain({2:1,4:1})); assert entries(T)[-1] == (4,0,'B1',True); ok('... a wisp item obtained later is temporary')
T = fresh(); run(T, L((0, P({}, {3:1}, ptype=10)))); assert entries(T) == [(3,0,'B1',False)]; ok('Lost: innate Holy Mantle not temporary')
T = fresh(); run(T, L((0, P({}, {5:1}, ptype=99)))); assert entries(T) == [(5,0,'B1',False)]; ok('modded character: its innate item not temporary')
T = fresh(); T.update(L((0, P({1:1})))); run(T, L((0, P({1:1}, {2:1})))); assert entries(T) == [(1,0,'B1',False),(2,0,'B1',False)]; ok('innate grant landing a few updates after first sight still innate')
T = fresh(); run(T, cain({2:1})); run(T, L((0, P({1:1}, {6:1}, seed=500, ptype=5)))); run(T, L((0, P({1:1}, {6:1,7:1}, seed=500, ptype=5))))
assert entries(T) == [(1,0,'B1',False),(6,0,'B1',False),(7,0,'B1',True)]; ok('Clicker (same key, new type): new character innate items absorbed, later wisp temporary')
T = fresh(); run(T, cain({2:1})); W((4, 500)); run(T, cain({2:1,4:1})); run(T, L((0, P({1:1,2:1}, {4:1,6:1}, seed=500, ptype=5)))); W()
assert entries(T) == [(1,0,'B1',False),(2,0,'B1',False),(4,0,'B1',True),(6,0,'B1',False)], entries(T); ok('type change: a held wisp is attributed to its familiar and stays temporary, only new items absorbed')
fg = lambda ptype, mod: L((0, P({1:1}, mod, seed=600, ptype=ptype)))
T = fresh(); run(T, fg(16, {})); run(T, fg(17, {})); run(T, fg(16, {})); T.update(fg(17, {7:1})); run(T, fg(17, {7:1}))
assert entries(T) == [(1,0,'B1',False),(7,0,'B1',True)]; ok('switching back to a type the key already had (Forgotten/Soul) does not settle again')
T = fresh(); run(T, L((0, P({}, {5:1}, seed=700, ghost=True)))); run(T, L((0, P({}, {5:1}, seed=700))))
assert entries(T) == [(5,0,'B1',False)]; ok('first seen as a ghost: innate items learned once active')
T = fresh(); run(T, cain({2:1})); run(T, L((0, P({1:1}, {}, seed=500, ptype=0)))); run(T, L((0, P({1:1}, {2:1}, seed=500, ptype=0))))
assert entries(T)[-1] == (2,0,'B1',True); ok('Cain -> Clicker -> Isaac loses Lucky Foot: a later Lucky Foot wisp is temporary (sets per player type)')
run(T, L((0, P({1:1}, {2:1,7:1}, seed=500, ptype=2))))
assert entries(T)[1:] == [(2,0,'B1',False),(7,0,'B1',True)]; ok('... back to Cain: his innate Lucky Foot not temporary again, no re-settle (new wisp temporary)')
lua.execute('function countCalls(p) local f = p.GetCollectibleNum; p.calls = 0; p.GetCollectibleNum = function(...) p.calls = p.calls + 1; return f(...) end end')
T = fresh(); T.update(L((0, P({1:1})), (1, P({}, seed=1001)))); run(T, L((0, P({1:1})), (1, P({}, seed=1001, ghost=True))), 40)
p0 = P({1:1}); g.countCalls(p0); run(T, L((0, p0), (1, P({}, seed=1001, ghost=True))), 5)
assert p0.calls < 20, p0.calls; ok('a ghost frozen mid-settle does not force full scans')
T = fresh(); run(T, L((0, P({1:1})), (1, P({2:1}))))  # settled: no forced scans
g.floorName = 'B2'
T.update(L((0, P({1:1,7:1})), (1, P({2:1})))); assert entries(T) == [(1,0,'B1',False),(2,1,'B1',False),(7,0,'B2',False)]; ok('floor kept from first appearance')
T.update(L((0, P({1:1,7:1})), (1, P({})))); assert entries(T) == [(1,0,'B1',False),(7,0,'B2',False)]; ok('item a player lost is removed')
moved = L((0, P({7:1})), (1, P({1:1}))); T.update(moved); assert entries(T) == [(7,0,'B2',False)]; ok('item moving to another player: old entry dropped')
for _ in range(29): T.update(moved)
assert entries(T) == [(7,0,'B2',False),(1,1,'B2',False)]; ok('... and re-listed under the new holder at the scan cadence')
g.floorName = 'B1'; T = fresh(); run(T, L((0, P({1:1})), (1, P({2:1,3:1})))); g.floorName = 'B3'
T.update(L((0, P({1:1,5:1})), (1, P({}, ghost=True)))); assert entries(T) == [(1,0,'B1',False),(2,1,'B1',False),(3,1,'B1',False),(5,0,'B3',False)]; ok('ghost keeps entries and floors (frozen, not rescanned)')
T.update(L((0, P({1:1,5:1})), (1, P({2:1,3:1})))); assert entries(T) == [(1,0,'B1',False),(2,1,'B1',False),(3,1,'B1',False),(5,0,'B3',False)]; ok('revival does not duplicate')
g.floorName = 'B1'; T = fresh(); run(T, L((0, P({1:1})), (1, P({})))); g.floorName = 'B2'
T.update(L((0, P({1:1})), (1, P({}, {9:1})))); assert entries(T) == [(1,0,'B1',False)]; ok('summed count unchanged -> no scan yet')
T.update(L((0, P({1:1})), (1, P({6:1}, {9:1})))); assert entries(T) == [(1,0,'B1',False),(6,1,'B2',False),(9,1,'B2',True)]; ok('summed count changed (second player only) -> scan')
T = fresh(); T.update(L((0, P({1:1})), (1, P({2:1})))); T.update(L((0, P({}, ghost=True)), (1, P({}, ghost=True))))
assert [(e.id, e.number) for e in T.entries.values()] == [(1,0),(2,1)]; ok('all ghosts -> entries kept')
T.update(L()); assert [(e.id, e.number) for e in T.entries.values()] == [(1,0),(2,1)]; ok('empty player list -> nothing changes')
g.floorName = 'B1'
T = fresh(); T.restore(lua.table_from([1, 2]), lua.table_from(['B1', 'B2']), None, None); assert entries(T) == [(1,0,'B1',None),(2,0,'B2',None)] and owners(T) == [None, None]; ok('old save without owners or roster loads as character 1, owner unresolved')
T.update(L((0, P({1:1,2:1}, seed=77)), (1, P({3:1}, seed=88))))
assert entries(T) == [(1,0,'B1',False),(2,0,'B2',False),(3,1,'B1',False)] and owners(T) == [77,77,88]; ok('... first update gives them to player 0, no duplicates, floors kept')
T = fresh(); T.restore(lua.table_from([1]), lua.table_from(['B1']), None); T.update(L((0, P({}, ghost=True, seed=77)), (1, P({1:1}, seed=88))))
assert owners(T) == [None, 88]; T.update(L((0, P({1:1}, seed=77)), (1, P({}, seed=88)))); assert owners(T) == [77] and entries(T) == [(1,0,'B1',False)]; ok('... player 0 a ghost: resolved once he is back')
T.restore(lua.table_from([1, 2, 3, 4, 5, 6]), lua.table_from(['B1', 'B2', 'B3', 'B4', 'B5', 'B6']), lua.table_from([5, -1, 'x', 1.5, 7.0, 3]))
assert entries(T) == [(i,0,'B%d' % i,None) for i in range(1, 7)] and owners(T) == [None]*6; ok('restore: malformed owners, and owners without a roster row, load unset as character 1')

# co-op player leaving: GetPlayer indexes shift, identity does not
g.floorName = 'B1'; T = fresh(); T.update(L((0, P({1:1}, seed=10)), (1, P({2:1}, seed=20)))); g.floorName = 'B2'
left = L((0, P({2:1}, seed=20)))
for _ in range(31): T.update(left)
assert entries(T) == [(2,1,'B1',False)] and owners(T) == [20] and gone(T) == [(1,0,'B1',False)] and T.leftCount == 1; ok('P1 leaves: his items kept but marked left, P2 keeps number 2 and his floor, no duplicates')
for _ in range(31): T.update(L((0, P({2:1}, seed=20)), (1, P({1:1}, seed=11))))
assert entries(T) == [(2,1,'B1',False),(1,2,'B2',False)] and owners(T) == [20,11]; ok('rejoin (new seed) starts fresh with the next free number')
g.floorName = 'B1'; T = fresh(); T.update(L((0, P({1:1}, seed=10)), (1, P({2:1}, seed=20)), (2, P({3:1}, seed=30))))
for _ in range(31): T.update(L((0, P({}, ghost=True, seed=20)), (1, P({3:1}, seed=30))))  # P1 left, P2 a ghost
assert entries(T) == [(2,1,'B1',False),(3,2,'B1',False)] and owners(T) == [20,30]; assert gone(T) == [(1,0,'B1',False)]; ok('numbers stay unique and stable after a leave: no renumbering')
g.floorName = 'B1'

T = fresh(); assert T.characterCount == 0
T.update(L((0, P({1:1})), (1, P({}, ghost=True)), (2, P({})))); assert T.characterCount == 3
T.update(L()); assert T.characterCount == 3
T.reset(); assert T.characterCount == 0; ok('characterCount: one per character passed (ghosts included), kept on empty list, 0 after reset')
# solo Tainted Lazarus: each form is its own character
g.floorName = 'B1'; T = fresh(); T.update(L((0, P({1:1}, seed=29, ptype=29)))); assert T.characterCount == 1; ok('solo Lazarus before the first Flip: one character, no badges')
g.floorName = 'B2'
for _ in range(31): T.update(L((0, P({2:1}, seed=38, ptype=38))))
assert entries(T) == [(1,0,'B1',False),(2,1,'B2',False)] and T.characterCount == 2; ok('solo Lazarus Flip: forms numbered 1 and 2, both listed, floors kept')
for _ in range(31): T.update(L((0, P({1:1}, seed=29, ptype=29))))
assert entries(T) == [(1,0,'B1',False),(2,1,'B2',False)] and T.characterCount == 2; ok('solo Lazarus flip back: re-matched, numbers stable, no duplicates')
T2 = fresh(); T2.restore(*T.serialize())
for _ in range(31): T2.update(L((0, P({1:1}, seed=29, ptype=29))))
assert entries(T2) == [(1,0,'B1',False),(2,1,'B2',False)] and T2.characterCount == 2; ok('solo Lazarus continue: other form frozen, numbers stable, still two characters')
for _ in range(31): T2.update(L((0, P({1:1,3:1}, seed=77))))  # a new character in the same seat gets the next free number
assert entries(T2)[-1] == (3,2,'B2',False); ok('restore keeps the next free number past saved ones')
# co-op with Tainted Lazarus as P1
g.floorName = 'B1'; T = fresh(); T.update(L((0, P({1:1}, seed=29, ptype=29)), (1, P({5:1}, seed=50))))
g.floorName = 'B2'
for _ in range(31): T.update(L((0, P({2:1}, seed=38, ptype=38)), (1, P({5:1}, seed=50))))
assert entries(T) == [(1,0,'B1',False),(5,1,'B1',False),(2,2,'B2',False)] and owners(T) == [29,50,38] and T.characterCount == 3; ok('co-op Lazarus flip: P1 1, P2 2, second form 3')
g.floorName = 'B3'
for _ in range(31): T.update(L((0, P({1:1,3:1}, seed=29, ptype=29)), (1, P({5:1}, seed=50))))
assert entries(T) == [(1,0,'B1',False),(5,1,'B1',False),(2,2,'B2',False),(3,0,'B3',False)] and owners(T) == [29,50,38,29]; ok('co-op Lazarus flip back: re-matched, no duplicates')
T2 = fresh(); T2.restore(*T.serialize())
for _ in range(31): T2.update(L((0, P({1:1,3:1}, seed=29, ptype=29)), (1, P({5:1}, seed=50))))
assert entries(T2) == [(1,0,'B1',False),(5,1,'B1',False),(2,2,'B2',False),(3,0,'B3',False)]; ok('continue with the other Lazarus form absent: its entries kept (frozen, saved kind kept)')
for _ in range(31): T2.update(L((0, P({1:1,3:1}, seed=29, ptype=29))))
assert entries(T2) == [(1,0,'B1',False),(2,2,'B2',False),(3,0,'B3',False)]; assert gone(T2) == [(5,1,'B1',False)]; ok('co-op leave (count drops): the leaver is marked left, not swapped')
T = fresh(); T.restore(lua.table_from([1]), lua.table_from(['B1']), lua.table_from([29]), lua.table_from([lua.table_from({'key': 29, 'number': 0})]))
T.update(L((0, P({1:1}, seed=29, ptype=29)))); T.update(L((0, P({}, seed=38, ptype=38))))
assert entries(T) == [(1,0,'B1',False)]; ok('save without swap flags: a Flip after the continue is still detected')
# Esau Jr.: same character type, new seed at the same index
g.floorName = 'B1'; T = fresh(); T.update(L((0, P({1:1}, seed=300, ptype=3))))
g.floorName = 'B2'
for _ in range(31): T.update(L((0, P({2:1}, seed=301, ptype=3))))
assert entries(T) == [(1,0,'B1',False),(2,1,'B2',False)] and T.characterCount == 2; ok('Esau Jr.: Judas frozen as 1, Esau Jr. listed as 2')
for _ in range(31): T.update(L((0, P({1:1}, seed=300, ptype=3))))
assert entries(T) == [(1,0,'B1',False),(2,1,'B2',False)]; ok('Esau Jr. swap back: re-matched, no duplicates')
T2 = fresh(); T2.restore(*T.serialize())
for _ in range(31): T2.update(L((0, P({1:1}, seed=300, ptype=3))))
assert entries(T2) == [(1,0,'B1',False),(2,1,'B2',False)] and T2.characterCount == 2; ok('Esau Jr. continue: swapped-out form survives')
# two changes in one update
g.floorName = 'B1'; T = fresh(); T.update(L((0, P({1:1}, seed=10)), (1, P({2:1}, seed=20))))
for _ in range(31): T.update(L((0, P({3:1}, seed=11)), (1, P({4:1}, seed=21))))
assert sorted(entries(T)) == [(1,0,'B1',False),(2,1,'B1',False),(3,2,'B1',False),(4,3,'B1',False)]; ok('two players swap in the same update: both frozen, new forms numbered 3 and 4')
T = fresh(); T.update(L((0, P({1:1}, seed=10)), (1, P({2:1}, seed=20))))
for _ in range(31): T.update(L((0, P({2:1}, seed=20)), (1, P({5:1}, seed=50))))
assert entries(T) == [(2,1,'B1',False),(5,2,'B1',False)]; assert gone(T) == [(1,0,'B1',False)]; ok('a leave and a join in the same update: the leaver is marked left (his index holds a known player)')
T = fresh(); T.update(L((0, P({1:1}, seed=10)), (1, P({2:1}, seed=20))))
p21 = P({3:1}, seed=21); p21.ControllerIndex = 1  # P2's new form, on P2's controller
for _ in range(31): T.update(L((0, p21)))
assert entries(T) == [(3,2,'B1',False)]; assert gone(T) == [(1,0,'B1',False),(2,1,'B1',False)] and 20 in [r.key for r in T.serialize()[3].values()]; ok('a leave and a swap in the same update: the swapping group kept its count, so nothing merges; both old forms read as left, items kept')
g.floorName = 'B1'

# save.lua through the game's json.lua
g.package.loaded.json = lua.execute((GAME/'resources'/'scripts'/'json.lua').read_text(encoding='utf-8'))
S = lua.execute((repo/'scripts'/'save.lua').read_text(encoding='utf-8'))
cfg_src = (repo/'scripts'/'config.lua').read_text(encoding='utf-8')
lua.execute('function mkmod() local m = {}; function m:SaveData(s) m.data = s end; function m:HasData() return m.data ~= nil end; function m:LoadData() return m.data end; return m end')
T = fresh(); T.update(L((0, P({1:1})), (2, P({1:1,2:1}))))
mod = g.mkmod(); S.write(mod, lua.execute(cfg_src), *T.serialize())
saved = S.read(mod, lua.execute(cfg_src))
T2 = fresh(); T2.restore(*saved); assert entries(T2) == [(1,0,'B1',False),(1,1,'B1',False),(2,1,'B1',False)] and owners(T2) == [1000,1002,1002]; ok('new save round-trips owners, roster and temporary')
for _ in range(31): T2.update(L((0, P({1:1,2:1}, seed=1002)), (1, P({1:1}, seed=1000))))
assert entries(T2) == [(1,0,'B1',False),(1,1,'B1',False),(2,1,'B1',False)] and owners(T2) == [1000,1002,1002]; ok('continue with players reordered: identity and numbers kept, no duplicates')
def row(key, number, swapped): return lua.table_from({'key': key, 'number': number, 'swapped': swapped})
def rows(T): return sorted((r.key, r.number, r.swapped) for r in T.serialize()[3].values())
def roundtrip(T):
    mod = g.mkmod(); S.write(mod, lua.execute(cfg_src), *T.serialize()); T2 = fresh(); T2.restore(*S.read(mod, lua.execute(cfg_src))); return T2
T = fresh(); run(T, cain({2:1})); run(T, cain({2:1,4:1})); T = roundtrip(T); run(T, cain({2:1,4:1}))
assert entries(T) == [(1,0,'B1',False),(2,0,'B1',False),(2,0,'B1',False),(4,0,'B1',True)]; ok('continue with a saved innate set: wisp held at the continue stays temporary')
T = fresh(); T.restore(lua.table_from([1, 2]), lua.table_from(['B1', 'B1']), lua.table_from([500, 500]), lua.table_from([row(500, 0, False)])); W((4, 500)); run(T, cain({2:1,4:1})); W()
assert entries(T) == [(1,0,'B1',False),(2,0,'B1',False),(2,0,'B1',False),(4,0,'B1',True)], entries(T); ok('old save without innate: re-learned on load, a held wisp attributed and temporary')
T = fresh(); T.restore(lua.table_from([1, 2]), lua.table_from(['B1', 'B1']), lua.table_from([500, 500]), lua.table_from([row(500, 0, False)])); run(T, cain({2:1,4:1}))
assert entries(T)[-1] == (4,0,'B1',False); ok('... a 3 Dollar Bill grant held then is taken as innate (known limit)')
bad = row(500, 0, False); bad.innate = lua.table_from({'x': 4})
T = fresh(); T.restore(lua.table_from([1]), lua.table_from(['B1']), lua.table_from([500]), lua.table_from([bad])); run(T, cain({2:1}))
assert entries(T) == [(1,0,'B1',False),(2,0,'B1',False),(2,0,'B1',False)]; ok('corrupted innate (non-array table) re-learned, not taken as an empty set')
T = fresh(); run(T, fg(16, {})); run(T, fg(17, {})); run(T, fg(16, {})); T = roundtrip(T); run(T, fg(16, {})); T.update(fg(17, {7:1})); run(T, fg(17, {7:1}))
assert entries(T) == [(1,0,'B1',False),(7,0,'B1',True)], entries(T); ok('Forgotten/Soul round trip, continue, then Soul again: no re-settle, new wisp temporary')
T = fresh(); run(T, cain({}), 5); T = roundtrip(T); run(T, cain({2:1}))
assert entries(T) == [(1,0,'B1',False),(2,0,'B1',False),(2,0,'B1',False)]; ok('save while still settling, late innate grant after continue: still innate (settling type not saved)')
for bad_ids in (['a'], [2]):
    bad = row(500, 0, False); bad.innate = lua.table_from(bad_ids)
    T = fresh(); T.restore(lua.table_from([1]), lua.table_from(['B1']), lua.table_from([500]), lua.table_from([bad])); run(T, cain({2:1}))
    assert entries(T) == [(1,0,'B1',False),(2,0,'B1',False),(2,0,'B1',False)], bad_ids
ok('innate ["a"] and the old flat format [2] both re-learn')
T = fresh(); T.restore(lua.table_from([3]), lua.table_from(['B1']), lua.table_from([4000000000]), lua.table_from([row(4000000000, 5, True)]))
T = roundtrip(T)
assert entries(T) == [(3,5,'B1',None)] and owners(T) == [4000000000] and rows(T) == [(4000000000, 5, True)]; ok('roster number 5, a large seed, the swap flag and an unknown kind survive a save round trip')
T = fresh(); T.update(L((0, P({}, seed=100)), (1, P({4:1}, seed=101)))); T = roundtrip(T)
for _ in range(31): T.update(L((0, P({}, seed=100)), (1, P({4:1}, seed=101))))
assert entries(T) == [(4,1,'B1',False)] and rows(T) == [(100,0,False),(101,1,False)] and T.characterCount == 2; ok('Jacob without items keeps number 1 across a continue')
T = fresh(); T.update(L((0, P({}, seed=10)), (1, P({2:1}, seed=20)))); T = roundtrip(T)
for _ in range(31): T.update(L((0, P({}, seed=10)), (1, P({2:1}, seed=20)), (2, P({3:1}, seed=30))))
assert entries(T) == [(2,1,'B1',False),(3,2,'B1',False)]; ok('co-op P1 without items keeps number 1 across a continue; a new P3 gets 3')
T = fresh(); T.update(L((0, P({1:1}, seed=29, ptype=29)))); T.update(L((0, P({}, seed=38, ptype=38)))); T = roundtrip(T)
for _ in range(31): T.update(L((0, P({}, seed=38, ptype=38))))
assert entries(T) == [(1,0,'B1',False)] and rows(T) == [(29,0,True),(38,1,False)] and T.characterCount == 2; ok('active Lazarus form without items keeps number 2 across a continue, other form frozen')
T = fresh(); T.restore(lua.table_from([1]), lua.table_from(['B1']), lua.table_from([5]), lua.table_from([lua.table_from({'key': 'x', 'number': 1}), 7, row(6, -1, False), row(9, 3, 'yes'), row(8, 64, False)]))
assert rows(T) == [(9,3,False)] and owners(T) == [None]; ok('malformed roster rows (number 64 included) dropped; items whose owner has no row load unset')
T = fresh(); T.restore(lua.table_from([1, 2]), lua.table_from(['B1', 'B1']), lua.table_from([5, 6]), lua.table_from([row(5, 0, False), row(6, 0, False)]))
assert rows(T) == [(5,0,False)] and owners(T) == [5, None]; ok('two roster rows with the same number: the second key is refused, its items load unresolved')
T = fresh(); T.restore(lua.table_from([1, 2]), lua.table_from(['B1', 'B1']), None); T.update(L((1, P({2:1}, seed=9))))
mod = g.mkmod(); S.write(mod, lua.execute(cfg_src), *T.serialize()); T.restore(*S.read(mod, lua.execute(cfg_src)))
assert entries(T) == [(1,0,'B1',None),(2,0,'B1',None),(2,0,'B1',False)] and owners(T) == [None, None, 9]; ok('unresolved owners save as false and unknown kinds as 0, stay aligned, both stay unresolved')
mod = g.mkmod(); mod.data = '{"config":{"showPlayer":3,"columns":3}}'
c = lua.execute(cfg_src); S.read(mod, c); assert c.showPlayer is None and c.columns == 3; ok('a saved showPlayer (removed filter) is ignored as an unknown key')
for v, want in [('0',4),('9',4),('8',8),('1',1)]:
    mod = g.mkmod(); mod.data = '{"config":{"columns":%s}}' % v
    c = lua.execute(cfg_src); S.read(mod, c); assert c.columns == want, (v, c.columns)
ok('columns range still 1..8')

# render.lua filter and badges, minimal engine stubs
lua.execute(r'''
local V = {}
V.__add = function(a, b) return Vector(a.X + b.X, a.Y + b.Y) end
V.__mul = function(a, k) return Vector(a.X * k, a.Y * k) end
Vector = function(x, y) return setmetatable({ X = x, Y = y }, V) end
Color = function(...) return {...} end
KColor = Color
Options = { HUDOffset = 0 }
Isaac.GetScreenWidth = function() return 480 end
Isaac.GetScreenHeight = function() return 270 end
Font = function() return { Load = function() end, GetStringWidth = function() return 10 end,
  DrawStringScaled = function(_, s, x, y, sx) table.insert(texts, s); table.insert(textScales, sx) end, DrawStringScaledUTF8 = function() end } end
Sprite = function()
  local sp = {}
  function sp:Load() end function sp:Play() end function sp:ReplaceSpritesheet(_, f) sp.file = f end
  function sp:LoadGraphics() end function sp:Update() end function sp:SetFrame() end
  function sp:Render() table.insert(drawn, sp.file or "clock") end
  return sp
end
Game = function() return { IsPaused = function() return false end, TimeCounter = 0 } end
''')
R = lua.execute((repo/'scripts'/'render.lua').read_text(encoding='utf-8'))
def draw(es, players=2, leftCount=0, left=(), **cfg):
    g.drawn, g.texts, g.textScales = lua.table_from([]), lua.table_from([]), lua.table_from([])
    c = lua.execute(cfg_src); c.showTimer = False; c.showFloor = False
    for k, v in cfg.items(): c[k] = v
    R.draw(c, lua.table_from([lua.table_from({'id': i, 'owner': 1000 + o, 'number': o, 'floor': 'B1', 'type': 1, 'temporary': t, 'left': o in left or None}) for i, o, t in es]), players, leftCount)
    return list(g.drawn.values()), list(g.texts.values())
mixed = [(1,0,False),(2,1,True),(1,1,False)]
assert draw(mixed) == (['item1','item2','clock','item1'], ['2','2','1']); ok('All view, two players: every entry drawn, badged 1-based, clock kept')
assert draw(mixed, showTemporary=False) == (['item1','item1'], ['2','1']); ok('showTemporary off: clocked copies hidden, the rest still badged')
assert draw([(1,0,False),(2,0,False)], players=1) == (['item2','item1'], []); ok('All view, solo: no badges')
assert draw([(1,0,False),(2,0,False)]) == (['item2','item1'], ['1','1']); ok('All view, two players present, only P1 has items: badges shown')
assert draw([(1,1,False),(2,1,False)]) == (['item2','item1'], ['2','2']); ok('All view, two players present, only P2 has items: badges shown (count decides, not items)')
assert draw([(1,1,False),(2,1,False)], players=1) == (['item2','item1'], []); ok('All view, one player present (P1 left, old P2 items): no badges')
assert draw([(1,0,False),(2,1,False)], players=1, leftCount=1, left=(0,)) == (['item2'], []); ok('left player: hidden by default, not counted for badges')
assert draw([(1,0,False),(2,1,False)], players=1, leftCount=1, left=(0,), showLeft=True) == (['item2','item1'], ['2','1']); ok('left player: shown with showLeft, counted for badges')
assert draw([]) == ([], []); ok('All view, empty list')
assert draw([(1,0,False),(2,1,False)]) == (['item2','item1'], ['2','1']); ok('All view: two owners get two distinct badges')
assert draw([(1,0,False),(2,5,False)]) == (['item2','item1'], ['6','1']); ok('All view: number 5 badged 6')
draw(mixed, spriteScale=1.0, textScale=0.25)
assert set(g.textScales.values()) == {1.0}; ok('badge scales with spriteScale, not textScale')

# main.lua player filter, against the game's real enums so a missing vanilla global fails here
# engine-side (C++) bindings enums.lua expects to exist before it runs
lua.execute('BitSet128 = function(l, h) return {l, h} end; ItemConfig = {}; RoomDescriptor = {}')
lua.execute((GAME/'resources'/'scripts'/'enums.lua').read_text(encoding='utf-8'))
assert g.PlayerVariant is None, 'vanilla now defines PlayerVariant'
assert (g.PlayerType.PLAYER_LAZARUS_B, g.PlayerType.PLAYER_LAZARUS2_B, g.PlayerType.PLAYER_THESOUL_B) == (29, 38, 40)
assert g.CollectibleType.COLLECTIBLE_ESAU_JR == 703; g.CollectibleType.COLLECTIBLE_ESAU_JR = 13  # back to the stub id
assert (g.EntityType.ENTITY_FAMILIAR, g.FamiliarVariant.ITEM_WISP) == (3, 237)
CB = g.ModCallbacks
lua.execute(r'''
callbacks = {}
RegisterMod = function() return { AddCallback = function(_, cb, fn) callbacks[cb] = fn end } end
stubTracker = { entries = {}, reset = function() end }
include = function(name)
  if name == "scripts.tracker" then return stubTracker end
  if name == "scripts.save" then return { read = function() return {}, {} end } end
  if name == "scripts.mcm" then return { register = function() end } end
  return {}
end
Isaac.GetPlayer = function(i) return playersByIndex[i] end
Game = function() return { GetNumPlayers = function() return numPlayers end } end
''')
lua.execute((repo/'main.lua').read_text(encoding='utf-8'))
seen = []
g.stubTracker.update = lambda players: seen.append([(p.index, g.tostring(p.player), p.ghost) for p in players.values()])
p0, ghost, baby, esau, strawman, soul = P({1:1}), P({2:1}, ghost=True), P({3:1}, variant=1), P({4:1}), P({5:1}), P({}, ptype=40)
strawman.Parent = p0
g.playersByIndex = lua.table_from({0: p0, 1: ghost, 2: baby, 3: esau, 4: strawman, 5: soul}); g.numPlayers = 6
g.callbacks[CB.MC_POST_GAME_STARTED](None, False); g.callbacks[CB.MC_POST_UPDATE]()
assert seen == [[(0, g.tostring(p0), False), (1, g.tostring(ghost), True), (3, g.tostring(esau), False), (4, g.tostring(strawman), False)]], seen; ok('main: ghost passed marked, co-op baby and Tainted Soul excluded, Esau and Strawman\'s Keeper (Parent set) kept with their indexes')
seen.clear(); g.playersByIndex = lua.table_from({0: P({1:1}, ptype=35), 1: soul}); g.numPlayers = 2; g.callbacks[CB.MC_POST_UPDATE]()
assert len(seen) == 1 and len(seen[0]) == 1; ok('main: solo Tainted Forgotten passes one player (characterCount 1)')

# main's stubs replaced include and Game; restore the tracker's
lua.execute('Game = function() return { GetLevel = function() return { GetName = function() return floorName end } end } end')
lua.execute('include = function(name) return dofile(REPO .. "/" .. name:gsub("%.", "/") .. ".lua") end')
# left players across a continue, and a key that comes back
g.floorName = 'B1'; T = fresh(); T.update(L((0, P({1:1}, seed=10)), (1, P({2:1}, seed=20))))
for _ in range(31): T.update(L((0, P({2:1}, seed=20))))
T = roundtrip(T); T.update(L((0, P({2:1}, seed=20))))
assert gone(T) == [(1,0,'B1',False)] and entries(T) == [(2,1,'B1',False)] and (10,0,False) in [(k,n,sw) for k,n,sw in rows(T)]; ok('left player survives a continue, still hidden')
assert [r.left for r in T.serialize()[3].values() if r.key == 10] == [True]; ok('roster saves left')
for _ in range(31): T.update(L((0, P({1:1}, seed=10)), (1, P({2:1}, seed=20))))
assert gone(T) == [] and entries(T) == [(1,0,'B1',False),(2,1,'B1',False)] and T.leftCount == 0; ok('same key back: un-leaves and resumes, no duplicates')
c = lua.execute(cfg_src); assert c.showLeft == False
mod = g.mkmod(); mod.data = '{"config":{"showLeft":true}}'; S.read(mod, c); assert c.showLeft == True
mod = g.mkmod(); mod.data = '{"config":{"showLeft":1}}'; c = lua.execute(cfg_src); S.read(mod, c); assert c.showLeft == False; ok('showLeft: default off, saved boolean kept, non-boolean rejected')

# display order: within a floor, by player group, then character number, then newest first
def grow(key, number, group=None):
    t = {'key': key, 'number': number}
    if group is not None: t['group'] = group
    return lua.table_from(t)
def shown_order(T): return [(e.id, e.number) for e in reversed(list(T.ordered().values()))]  # the HUD reads from the end
T = fresh(); T.restore(lua.table_from([1, 2, 3, 4, 5, 6, 7, 8]), lua.table_from(['B1'] * 8), lua.table_from([29, 51, 29, 50, 51, 50, 38, 29]),
    lua.table_from([grow(29, 0, 0), grow(50, 1, 1), grow(51, 2, 1), grow(38, 3, 0)]))
assert [n + 1 for _, n in shown_order(T)] == [1, 1, 1, 4, 2, 2, 3, 3] and [i for i, _ in shown_order(T)] == [8, 3, 1, 7, 6, 4, 5, 2]; ok('screenshot case: Lazarus forms 1 and 4, then J&E 2 and 3, newest first within each character')
assert g.rawequal(T.ordered(), T.ordered()); ok('display order is cached between frames')
T = fresh(); T.restore(lua.table_from([1, 2, 3, 4]), lua.table_from(['B1', 'B1', 'B2', 'B2']), lua.table_from([20, 10, 20, 10]), lua.table_from([grow(10, 0, 0), grow(20, 1, 1)]))
assert shown_order(T) == [(4,0),(3,1),(2,0),(1,1)]; ok('floors keep their order (newest floor first); grouping stays within a floor')
# groups from live play: Jacob & Esau share a controller, a Flip keeps it, a co-op human has another
def groups(T): return sorted((r.key, r.number, r.group) for r in T.serialize()[3].values())
g.floorName = 'B1'; T = fresh()
laz, jacob, esau = P({1:1}, seed=29), P({2:1}, seed=50), P({3:1}, seed=51)
laz.ControllerIndex, jacob.ControllerIndex, esau.ControllerIndex = 4294967294, 0, 0
T.update(L((0, laz), (1, jacob), (2, esau)))
laz2 = P({4:1}, seed=38); laz2.ControllerIndex = 4294967294
for _ in range(31): T.update(L((0, laz2), (1, P({2:1}, seed=50)), (2, P({3:1}, seed=51))))
assert groups(T) == [(29,0,0),(38,3,0),(50,1,1),(51,2,1)]; ok('groups: keyboard Lazarus and his Flip form share group 1, J&E share group 2')
assert [n + 1 for _, n in shown_order(T)] == [1, 4, 2, 3]; ok('live order: 1 4 2 3')
T = roundtrip(T); assert groups(T) == [(29,0,0),(38,3,0),(50,1,1),(51,2,1)]; ok('groups survive a save round trip')
# old roster rows without a group, and group validation
T = fresh(); T.restore(lua.table_from([1, 2, 3]), lua.table_from(['B1'] * 3), lua.table_from([5, 6, 7]), lua.table_from([grow(5, 0), grow(6, 1, 64), grow(7, 2, 0)]))
assert groups(T) == [(5,0,64),(6,1,65),(7,2,0)] and shown_order(T) == [(3,2),(1,0),(2,1)]; ok('rows without a valid group (missing, 64) get their own group after real ones, ordered by number')
T = fresh(); T.restore(lua.table_from([1]), lua.table_from(['B1']), lua.table_from([5]), lua.table_from([lua.table_from({'key': 5, 'number': 0, 'group': -1}), lua.table_from({'key': 6, 'number': 1, 'group': 'x'})]))
assert groups(T) == [(5,0,64),(6,1,65)]; ok('malformed groups (-1, non-integer) fall back to an own group')
p5 = P({1:1}, seed=5); p5.ControllerIndex = 3; T.update(L((0, p5)))
p9 = P({9:1}, seed=9); p9.ControllerIndex = 3
for _ in range(31): T.update(L((0, p9)))
assert (9, 2, 64) in groups(T); ok('after a continue, a new form joins the group relearned from its controller')
T = fresh(); T.update(L((0, P({1:1})))); o1 = T.ordered()
for _ in range(31): T.update(L((0, P({1:1,2:1}))))
assert not g.rawequal(o1, T.ordered()) and shown_order(T) == [(2,0),(1,0)]
T.update(L((0, P({2:1})))); assert shown_order(T) == [(2,0)]; ok('display order is rebuilt after an add and a removal')
# co-op Lazarus flips, then that player leaves: both forms leave, the other player is unaffected
g.floorName = 'B1'; T = fresh()
T.update(L((0, P({1:1}, seed=29)), (1, P({5:1}, seed=50))))
for _ in range(31): T.update(L((0, P({2:1}, seed=38)), (1, P({5:1}, seed=50))))  # Flip (both on controller 0)
assert (29, 0, True) in rows(T); ok('co-op flip: inactive form swapped')
for _ in range(31): T.update(L((0, P({5:1, 6:1}, seed=50))))  # the Lazarus player leaves; P2 now index 0
assert sorted(gone(T)) == [(1,0,'B1',False),(2,2,'B1',False)] and entries(T) == [(5,1,'B1',False),(6,1,'B1',False)]; ok('Lazarus player leaves: both forms marked left, P2 unaffected')
assert rows(T) == [(29,0,False),(38,2,False),(50,1,False)] and T.characterCount == 1 and T.leftCount == 2; ok('... no stale swap flag; left forms count only when shown')
T = roundtrip(T); T.update(L((0, P({5:1, 6:1}, seed=50))))
assert sorted(gone(T)) == [(1,0,'B1',False),(2,2,'B1',False)] and T.characterCount == 1 and T.leftCount == 2; ok('... and that survives a continue')
T = fresh(); T.update(L((0, P({1:1}, seed=29))))
for _ in range(2): T.update(L((0, P({}, seed=38))))
assert rows(T) == [(29,0,True),(38,1,False)] and gone(T) == []; ok('solo flip: still swapped, not left')
T = fresh(); T.update(L((0, P({}, seed=29)), (1, P({5:1}, seed=50))))
T.update(L((0, P({}, seed=38)), (1, P({5:1}, seed=50)))); T.update(L((0, P({5:1}, seed=50))))
assert rows(T) == [(29,0,False),(38,2,False),(50,1,False)]; ok('a Lazarus player without items leaving still clears the swap flag')
T = fresh(); T.restore(lua.table_from([1]), lua.table_from(['B1']), None, None); o1 = T.ordered()
T.update(L((0, P({1:1}, seed=77)))); assert not g.rawequal(o1, T.ordered()) and list(T.ordered().values())[0].owner == 77; ok('display order is rebuilt after an owner is resolved')

# multiple copies (2.8)
g.floorName = 'B1'; W()
ISAAC = 900
isaac = lambda real, mod, ptype=0, zodiac=None: L((0, (lambda p: (setattr(p, 'zodiac', zodiac), p)[1])(P(real, mod, seed=ISAAC, ptype=ptype))))
T = fresh(); run(T, isaac({1:1,4:1}, {}))
W((4, ISAAC)); T.update(isaac({1:1,4:1}, {4:1}))
assert entries(T) == [(1,0,'B1',False),(4,0,'B1',False),(4,0,'B1',True)], entries(T); ok('owned + a wisp of it: two icons, the wisp clocked, listed on the update it appears')
W(); T.update(isaac({1:1,4:1}, {}))
assert entries(T) == [(1,0,'B1',False),(4,0,'B1',False)]; ok('... the wisp dies: only its icon leaves, on the same update')
T = fresh(); run(T, isaac({1:1}, {})); W((4, ISAAC)); T.update(isaac({1:1}, {4:1})); g.floorName = 'B2'
W((4, ISAAC), (4, ISAAC)); T.update(isaac({1:1}, {4:2}))
assert entries(T) == [(1,0,'B1',False),(4,0,'B1',True),(4,0,'B2',True)], entries(T); ok('two wisps of one item: two clocked icons, floors as obtained')
W((4, ISAAC)); T.update(isaac({1:1}, {4:1}))
assert entries(T) == [(1,0,'B1',False),(4,0,'B2',True)], entries(T); ok('... one dies: the oldest wisp icon leaves')
g.floorName = 'B1'; W()
T = fresh(); run(T, isaac({1:1}, {})); W((9, ISAAC)); T.update(isaac({1:1}, {9:1})); W((9, ISAAC), (5, ISAAC)); T.update(isaac({1:1}, {9:1,5:1}))
assert entries(T) == [(1,0,'B1',False),(9,0,'B1',True),(5,0,'B1',True)]; ok('wisps on separate updates list in the order obtained, not by id')
T = fresh(); run(T, isaac({1:1,3:2}, {})); assert entries(T) == [(1,0,'B1',False),(3,0,'B1',False),(3,0,'B1',False)]; ok('an item owned twice: two icons')
g.floorName = 'B2'; run(T, isaac({1:1,3:3}, {})); g.floorName = 'B1'
assert entries(T)[-1] == (3,0,'B2',False) and len(entries(T)) == 4; ok('... a third copy lists under the current floor')
T.update(isaac({1:1,3:2}, {})); assert entries(T) == [(1,0,'B1',False),(3,0,'B1',False),(3,0,'B2',False)], entries(T); ok('... losing one: the oldest icon of that kind leaves')
# PR #3 Clicker case: a wisp of X held through a type change into a character with X innate
T = fresh(); W((4, ISAAC)); run(T, isaac({1:1}, {4:1})); run(T, isaac({1:1}, {4:1}))
assert entries(T) == [(1,0,'B1',False),(4,0,'B1',True)], entries(T); ok('Clicker case: Isaac with a wisp of 4 at the start (attributed while settling): clocked')
run(T, isaac({1:1}, {4:2}, ptype=2))  # Clicker into a type with 4 innate: wisp + innate copy
assert entries(T) == [(1,0,'B1',False),(4,0,'B1',True),(4,0,'B1',False)], entries(T); ok('... into a type with 4 innate: innate copy learned (unclocked), the wisp stays clocked')
W(); T.update(isaac({1:1}, {4:1}, ptype=2))
assert entries(T) == [(1,0,'B1',False),(4,0,'B1',False)], entries(T); ok('... the wisp dies: one unclocked 4 stays (PR #3 limit fixed)')
# Zodiac: attributed while settling, so it keeps the clock and is not learned
T = fresh(); run(T, isaac({1:1}, {5:1}, zodiac=5))
assert entries(T) == [(1,0,'B1',False),(5,0,'B1',True)], entries(T); ok('Zodiac grant held at first sight: clocked, not learned as innate')
T.update(isaac({1:1}, {6:1}, zodiac=6))
assert entries(T) == [(1,0,'B1',False),(6,0,'B1',True)], entries(T); ok('... the Zodiac item changes: the old icon leaves and the new one lists on the same update')
T = fresh(); run(T, isaac({1:1}, {})); run(T, isaac({1:1}, {7:1}))
assert entries(T) == [(1,0,'B1',False),(7,0,'B1',True)]; ok('3 Dollar Bill grant outside a settle: clocked')
T = fresh(); run(T, isaac({1:1}, {7:1})); assert entries(T)[-1] == (7,0,'B1',False); ok('3 Dollar Bill grant inside a settle: learned innate (known limit)')
T = fresh(); W((4, None)); run(T, isaac({1:1}, {4:1})); W(); assert entries(T)[-1] == (4,0,'B1',False); ok('a wisp without a Player while settling: no error, counted innate (known limit)')
# Jacob & Esau settle together: each wisp goes to its own character
JAC, ESA = 510, 511
def je(jmod, emod):
    j, e = P({}, jmod, seed=JAC, ptype=19), P({}, emod, seed=ESA, ptype=20); j.ControllerIndex = e.ControllerIndex = 0
    return L((0, j), (1, e))
T = fresh(); W((4, ESA)); run(T, je({4:1}, {4:1})); W()
assert entries(T) == [(4,0,'B1',False),(4,1,'B1',True)], entries(T); ok('J&E settling: Esau\'s wisp of 4 clocked, the same item on Jacob (no wisp) innate')
# clamp: a learned innate count above what the engine still grants draws nothing extra
T = fresh(); run(T, cain({2:1})); run(T, cain({}))
assert entries(T) == [(1,0,'B1',False),(2,0,'B1',False)], entries(T); ok('innate copy gone (engine stopped granting it): one icon left, no phantom')
big = row(500, 0, False); big.innate = lua.table_from([lua.table_from({'type': 2, 'ids': lua.table_from([2, 2, 2])})])
T = fresh(); T.restore(lua.table_from([1, 2]), lua.table_from(['B1', 'B1']), lua.table_from([500, 500]), lua.table_from([big]), lua.table_from([False, False])); run(T, cain({2:1}))
assert entries(T) == [(1,0,'B1',False),(2,0,'B1',False),(2,0,'B1',False)], entries(T); ok('saved innate count 3 with one copy granted: capped, two icons')
# saves: 2.7 format (innate ids listed once, no temporary array) and 2.8 counts
old26 = row(500, 0, False); old26.innate = lua.table_from([lua.table_from({'type': 2, 'ids': lua.table_from([2])})])
T = fresh(); T.restore(lua.table_from([1, 2, 4]), lua.table_from(['B1', 'B1', 'B2']), lua.table_from([500, 500, 500]), lua.table_from([old26])); W((4, 500)); run(T, cain({2:1,4:1})); W()
assert entries(T) == [(1,0,'B1',False),(2,0,'B1',False),(4,0,'B2',True),(2,0,'B1',False)], entries(T); ok('2.7 save: innate id read as one copy, the held wisp keeps its floor and gets the clock, the second Lucky Foot lists')
T = fresh(); run(T, L((0, P({}, {5:2}, seed=800, ptype=99)))); assert entries(T) == [(5,0,'B1',False),(5,0,'B1',False)]; ok('a character with two innate copies: two icons')
assert sorted(list(list(T.serialize()[3].values())[0].innate.values())[0].ids.values()) == [5, 5]; ok('... saved as the id listed twice')
T = roundtrip(T); run(T, L((0, P({}, {5:2}, seed=800, ptype=99)))); assert entries(T) == [(5,0,'B1',False),(5,0,'B1',False)]; ok('... and both stay unclocked after a continue')
T = fresh(); run(T, isaac({1:1,4:1}, {})); W((4, ISAAC)); T.update(isaac({1:1,4:1}, {4:1})); g.floorName = 'B2'
T = roundtrip(T); T.update(isaac({1:1,4:1}, {4:1})); W()
assert entries(T) == [(1,0,'B1',False),(4,0,'B1',False),(4,0,'B1',True)], entries(T); ok('2.8 save: owned + wisp keep their kinds and floors across a continue')
g.floorName = 'B1'
T = fresh(); T.restore(lua.table_from([4, 4]), lua.table_from(['B1', 'B2']), lua.table_from([ISAAC, ISAAC]), lua.table_from([row(ISAAC, 0, False)])); W((4, ISAAC)); T.update(isaac({4:1}, {4:1})); W()
assert entries(T) == [(4,0,'B1',True),(4,0,'B2',False)], entries(T); ok('save without temporary: unknown kinds fill unclocked copies first (newest first), then clocked')
# Jacob & Esau into one character (Clicker): Esau is a character who left, not a player; his owned copies move to the survivor, his clocked ones go
JK, EK, CTRL = 610, 611, 0
def pl(real, mod, seed, ptype):
    p = P(real, mod, seed=seed, ptype=ptype); p.ControllerIndex = CTRL; return p
def je2(jreal, jmod, ereal, emod): return L((0, pl(jreal, jmod, JK, 19)), (1, pl(ereal, emod, EK, 20)))
def solo(real, mod, ptype=8): return L((0, pl(real, mod, JK, ptype)))
def rowkeys(T): return sorted(r.key for r in T.serialize()[3].values())
def je_setup():
    T = fresh(); W()
    g.floorName = 'B1'; run(T, je2({4:1}, {}, {}, {}))
    g.floorName = 'B2'; run(T, je2({4:1}, {}, {4:2}, {}))
    g.floorName = 'B3'; run(T, je2({4:3}, {}, {4:2}, {}))
    W((4, JK), (4, JK), (4, EK)); run(T, je2({4:3}, {4:2}, {4:2}, {4:1}))
    assert entries(T) == [(4,0,'B1',False),(4,1,'B2',False),(4,1,'B2',False),(4,0,'B3',False),(4,0,'B3',False),(4,0,'B3',True),(4,0,'B3',True),(4,1,'B3',True)], entries(T)
    g.floorName = 'B4'
    return T
MERGED = [(4,0,'B2',False),(4,0,'B2',False),(4,0,'B3',False),(4,0,'B3',False),(4,0,'B3',True),(4,0,'B3',True)]
T = je_setup(); W((4, JK), (4, JK)); run(T, solo({4:4}, {4:2}))
assert entries(T) == MERGED and gone(T) == [] and T.leftCount == 0 and T.characterCount == 1, (entries(T), gone(T)); ok('user sequence (merge in one update): Esau\'s owned copies move with floors, his wisp goes, Clicker\'s loss takes the oldest')
assert rowkeys(T) == [JK]; ok('... Esau is forgotten, not saved as a left row')
T = roundtrip(T); run(T, solo({4:4}, {4:2}))
assert entries(T) == MERGED and gone(T) == [] and rowkeys(T) == [JK]; ok('... and that survives a save round trip')
T = je_setup(); W((4, JK), (4, JK)); run(T, solo({4:3}, {4:2}), 2)
assert [e for e in entries(T) if not e[3]] == [(4,0,'B1',False),(4,0,'B2',False),(4,0,'B2',False),(4,0,'B3',False),(4,0,'B3',False)], entries(T); ok('merge, copies arriving later: moved copies and the survivor\'s own kept while the survivor settles')
run(T, solo({4:4}, {4:2})); assert entries(T) == MERGED, entries(T); ok('... once they arrive: same as the one-update merge, nothing re-listed at the current floor')
T = je_setup(); W((4, JK), (4, JK)); run(T, solo({4:3}, {4:2}), 31)
assert [e for e in entries(T) if not e[3]] == [(4,0,'B2',False),(4,0,'B3',False),(4,0,'B3',False)], entries(T); ok('... copies that never arrive: dropped (oldest first) once the survivor settles')
T = je_setup(); W((4, JK), (4, JK), (4, EK)); T.update(solo({4:4}, {4:3})); W((4, JK), (4, JK)); run(T, solo({4:4}, {4:2}))
W((4, JK)); T.update(solo({4:4}, {4:1}))
assert sorted(e[3] for e in entries(T)) == [False]*4 + [True], entries(T); ok('Esau\'s wisp still counted on the survivor for an update: not learned innate')
# co-op leaver unaffected; merge picks the same group
T = fresh(); W(); g.floorName = 'B1'
coop = lambda real: (lambda p: (setattr(p, 'ControllerIndex', 1), p)[1])(P(real, seed=700))
run(T, L((0, pl({1:1}, {}, JK, 19)), (1, pl({2:1}, {}, EK, 20)), (2, coop({5:1}))))
run(T, L((0, pl({1:1,2:1}, {}, JK, 8)), (1, coop({5:1}))))
assert entries(T) == [(1,0,'B1',False),(2,0,'B1',False),(5,2,'B1',False)] and gone(T) == [], (entries(T), gone(T)); ok('merge with a co-op player present: Esau merges into Jacob, not the other player')
run(T, L((0, pl({1:1,2:1}, {}, JK, 8))))
assert gone(T) == [(5,2,'B1',False)] and T.leftCount == 1 and 700 in rowkeys(T); ok('a co-op player leaving is still a player who left')
T = fresh(); run(T, L((0, pl({1:1}, {}, JK, 0)))); run(T, L((0, pl({1:1}, {}, JK, 0)), (1, pl({}, {}, 650, 20)))); run(T, L((0, pl({1:1}, {}, JK, 0))))
assert entries(T) == [(1,0,'B1',False)] and gone(T) == [] and rowkeys(T) == [JK]; ok('a temporary same-group character without items (Soul of Jacob and Esau): no left row')
# Clicker into Jacob & Esau: the in-game split (2026-11-21), owned 12 + 2 wisps into Jacob 5 + 2 wisps and a new Esau 6
NE = 177
T = fresh(); W()
for f, n in (('B1', 4), ('B2', 8), ('B3', 12)): g.floorName = f; run(T, solo({4:n, 482:0}, {}, 4))
W((4, JK), (4, JK)); run(T, solo({4:12}, {4:2}, 4)); g.floorName = 'B4'
run(T, L((0, pl({4:5}, {4:2}, JK, 19)), (1, pl({4:6}, {}, NE, 20))))
assert entries(T) == [(4,1,'B1',False)]*3 + [(4,1,'B2',False)]*3 + [(4,0,'B2',False)] + [(4,0,'B3',False)]*4 + [(4,0,'B3',True)]*2, entries(T); ok('split: Jacob keeps his newest 5, the new Esau takes the next 6 with their floors, the oldest copy leaves')
# J&E -> Clicker (merge) -> Clicker into J&E (split): the old Esau's entries do not linger
T = je_setup(); W((4, JK), (4, JK)); run(T, solo({4:4}, {4:2})); g.floorName = 'B5'
run(T, L((0, pl({4:2}, {4:2}, JK, 19)), (1, pl({4:1}, {}, 612, 20))))
assert entries(T) == [(4,2,'B2',False),(4,0,'B3',False),(4,0,'B3',False),(4,0,'B3',True),(4,0,'B3',True)] and EK not in owners(T) and gone(T) == [] and rowkeys(T) == [JK, 612], entries(T); ok('merge then split: old Esau gone, new Esau numbered 3 takes a copy with its floor')
# Tainted Lazarus turned into another character: the swapped-out form merges into the active one
def tlaz_setup():
    T = fresh(); W(); g.floorName = 'B1'; run(T, L((0, pl({1:1}, {}, 29, 29))))
    g.floorName = 'B2'; run(T, L((0, pl({2:1}, {}, 38, 38)))); g.floorName = 'B3'
    return T
T = tlaz_setup(); run(T, L((0, pl({1:1,2:1}, {}, 38, 0))))
assert entries(T) == [(1,1,'B1',False),(2,1,'B2',False)] and gone(T) == [] and rowkeys(T) == [38], entries(T); ok('ChangePlayerType out of Tainted Lazarus (in-game): both forms\' items on the active one, floors kept')
# real Clicker, in-game 2026-11-21: Tainted Lazarus (29 active, Dead form 38 stored) into Tainted Isaac (21) holds both forms' items
T = fresh(); W(); g.floorName = 'B1'; run(T, L((0, pl({4:1}, {}, 29, 29)))); run(T, L((0, pl({5:2,7:1}, {}, 38, 38))))
g.floorName = 'B2'; run(T, L((0, pl({4:3}, {}, 29, 29)))); g.floorName = 'B3'; run(T, L((0, pl({4:3,5:2,7:1}, {}, 29, 21))))
assert entries(T) == [(4,0,'B1',False),(5,0,'B1',False),(5,0,'B1',False),(7,0,'B1',False),(4,0,'B2',False),(4,0,'B2',False)] and gone(T) == [] and rowkeys(T) == [29], entries(T); ok('Clicker out of Tainted Lazarus into Tainted Isaac (in-game): the Dead form\'s items move with their B1 floors, nothing under B3')
T = tlaz_setup(); T = roundtrip(T); run(T, L((0, pl({2:1}, {}, 38, 38)))); run(T, L((0, pl({1:1,2:1}, {}, 38, 0))))
assert entries(T) == [(1,1,'B1',False),(2,1,'B2',False)] and gone(T) == [] and rowkeys(T) == [38], entries(T); ok('continue, then ChangePlayerType out of Tainted Lazarus: the stored form merges by its saved type and partner')
T = tlaz_setup(); run(T, L((0, pl({2:1}, {}, 38, 0))))
assert entries(T) == [(2,1,'B2',False)] and gone(T) == [] and rowkeys(T) == [38], entries(T); ok('Clicker out of Tainted Lazarus, survivor without the stored form\'s items: they go once it settles')
T = tlaz_setup(); run(T, L((0, pl({2:1}, {}, 38, 38)), (1, pl({5:1}, {}, 39, 20))))
assert entries(T) == [(1,0,'B1',False),(2,1,'B2',False),(5,2,'B3',False)] and 29 in rowkeys(T) and (29,0,True) in rows(T), entries(T); ok('Esau (Soul of Jacob and Esau) beside Tainted Lazarus: the stored form stays swapped')
# a ghost is never a merge target
T = fresh(); W(); g.floorName = 'B1'
run(T, L((0, pl({1:1}, {}, JK, 19)), (1, pl({2:1}, {}, EK, 20)), (2, coop({5:1}))))
gj = P({1:1}, seed=JK, ptype=19, ghost=True); gj.ControllerIndex = CTRL
run(T, L((0, gj), (1, coop({5:1}))))
assert entries(T) == [(1,0,'B1',False),(5,2,'B1',False)] and gone(T) == [(2,1,'B1',False)] and EK in rowkeys(T), (entries(T), gone(T)); ok('Esau vanishing while Jacob is a ghost: marked left, not merged into the ghost')
# Tainted Lazarus losing Birthright: the vanished form is stored again
T = fresh(); W(); g.floorName = 'B1'; run(T, L((0, pl({1:1}, {}, 29, 29)), (1, pl({2:1}, {}, 38, 38))))
g.floorName = 'B2'; run(T, L((0, pl({2:1}, {}, 38, 38))))
assert entries(T) == [(1,0,'B1',False),(2,1,'B1',False)] and (29,0,True) in rows(T) and gone(T) == [], entries(T); ok('Birthright lost: the other form is swapped out, its entries frozen')
g.floorName = 'B3'; run(T, L((0, pl({1:1}, {}, 29, 29))))
assert entries(T) == [(1,0,'B1',False),(2,1,'B1',False)] and (29,0,False) in rows(T) and (38,1,True) in rows(T), entries(T); ok('... a later Flip back resumes it as number 1')
# merge without Clicker's loss, Esau's copies reaching Jacob an update late: every copy keeps its floor
T = je_setup(); W((4, JK), (4, JK)); T.update(solo({4:3}, {4:2})); run(T, solo({4:5}, {4:2}))
assert [e for e in entries(T) if not e[3]] == [(4,0,'B1',False),(4,0,'B2',False),(4,0,'B2',False),(4,0,'B3',False),(4,0,'B3',False)], entries(T); ok('late merge: the survivor\'s own oldest copy kept too, nothing re-listed under B4')
g.floorName = 'B1'; W()
T = fresh(); run(T, L((0, pl({1:1}, {}, 29, 29)), (1, pl({2:1}, {}, 38, 38)))); run(T, L((0, pl({1:1}, {}, 29, 29)), (1, pl({2:1}, {}, 38, 0))))
assert entries(T) == [(1,0,'B1',False),(2,1,'B1',False)] and rowkeys(T) == [29, 38]; ok('Clicker with Birthright: the other form stays a player, nothing merged or dropped')
T = fresh(); run(T, L((0, pl({1:1}, {}, 300, 3)))); run(T, L((0, pl({2:1}, {}, 301, 3))))
assert entries(T) == [(1,0,'B1',False),(2,1,'B1',False)] and rowkeys(T) == [300, 301]; ok('Esau Jr. swapped-out form unaffected')
g.floorName = 'B1'; W()
# a stored Tainted Lazarus form swapped out inside its settle second: its type and partner are saved, so it merges after a continue
T = fresh(); W(); g.floorName = 'B1'; run(T, L((0, pl({1:1}, {}, 29, 29))), 10)
g.floorName = 'B2'; run(T, L((0, pl({}, {}, 38, 38)))); T = roundtrip(T); run(T, L((0, pl({}, {}, 38, 38))), 2); run(T, L((0, pl({1:1}, {}, 38, 0))))
assert entries(T) == [(1,1,'B1',False)] and gone(T) == [] and rowkeys(T) == [38], entries(T); ok('Flip inside the settle second, continue, ChangePlayerType: the stored form still merges by its saved type')
T = fresh(); W(); g.floorName = 'B1'; run(T, L((0, pl({4:1}, {}, 29, 29)))); run(T, L((0, pl({5:1}, {}, 38, 38))), 5); run(T, L((0, pl({4:1}, {}, 29, 29))))
T = roundtrip(T); g.floorName = 'B2'; run(T, L((0, pl({4:1}, {}, 29, 29))), 2); run(T, L((0, pl({4:1,5:1}, {}, 29, 21))))
assert entries(T) == [(4,0,'B1',False),(5,0,'B1',False)] and gone(T) == [] and rowkeys(T) == [29], entries(T); ok('Dead form flipped back inside its settle second, continue, Clicker: its items merge with their B1 floor')
g.floorName = 'B1'; W()
# a form swapped out inside its settle second (here an Esau Jr. original): its settling row is left out, so it settles again once it plays
T = fresh(); run(T, L((0, pl({1:1}, {}, 300, 3))), 10); run(T, L((0, pl({2:1}, {}, 301, 3))))
r300 = [r for r in T.serialize()[3].values() if r.key == 300][0]
assert r300.swapped and [r.type for r in (r300.innate or {}).values()] == [], list((r300.innate or {}).values()); ok('Esau Jr. original swapped out inside its settle second: its settling innate row is left out of the save')
g.floorName = 'B1'; W()
# Tainted Lazarus's active Dead form turned type 29 with the 29 form stored (in-game 2026-11-21, J510): the engine keeps the seed, gives it both forms' owned items
# and keeps Flip; the stored seed never returns, and the next Flip brings a fresh Dead form holding only Flip. FL = Flip, CK = Clicker (small stub ids).
FL, CK, EJ, TA, TB, TC = 11, 12, 13, 801, 802, 803  # EJ: Esau Jr., held by every Esau Jr. form in game (2026-11-22)
def owned(T): return sorted((e.id, e.floor, e.owner) for e in T.entries.values() if not e.left)
# real Clicker from 38 rolled 29 on Caves I, dropping My Reflection
T = fresh(); W(); g.floorName = 'B1'; run(T, L((0, pl({4:1, FL:1}, {}, TA, 29))))
g.floorName = 'B2'; run(T, L((0, pl({FL:1, 5:1, CK:1}, {}, TB, 38)))); g.floorName = 'B3'; run(T, L((0, pl({FL:1, 5:1, CK:1}, {}, TB, 38))), 5)
run(T, L((0, pl({4:1, FL:1, CK:1}, {}, TB, 29))))
assert [e for e in owned(T) if e[0] in (4, 5)] == [(4,'B1',TB)] and all(e[2] == TB for e in owned(T)) and [e[0] for e in owned(T)].count(FL) == 1, owned(T); ok('Clicker from the Dead form into 29 (in-game 2026-11-21): one c4 on B1 owned by the active form, one Flip')
assert TA not in rowkeys(T) and gone(T) == [], rowkeys(T); ok('... the stored 29 form is forgotten, nothing left')
# ChangePlayerType(29) on the Dead form on Basement II, then Flip
T = fresh(); W(); g.floorName = 'B1'; run(T, L((0, pl({4:1, FL:1}, {}, TA, 29))))
g.floorName = 'B2'; run(T, L((0, pl({FL:1, 5:1}, {}, TB, 38)))); run(T, L((0, pl({4:1, 5:1, FL:1}, {}, TB, 29))))
assert [e for e in owned(T) if e[0] != FL] == [(4,'B1',TB), (5,'B2',TB)] and [e[0] for e in owned(T)].count(FL) == 1 and TA not in rowkeys(T) and gone(T) == [], owned(T); ok('ChangePlayerType(29) on the Dead form (in-game 2026-11-21): c4 on B1 and c5 on B2 owned by it, stored form forgotten')
run(T, L((0, pl({FL:1}, {}, TC, 38))))
assert [e for e in owned(T) if e[2] == TC] == [(FL,'B2',TC)] and (TB, 1, True) in rows(T) and gone(T) == [], (owned(T), rows(T)); ok('... the next Flip: a fresh Dead form holding only Flip, the merged form stored')
assert [e for e in owned(T) if e[2] == TB and e[0] != FL] == [(4,'B1',TB), (5,'B2',TB)] and [e[:3:2] for e in owned(T)].count((FL, TB)) == 1 and TA not in rowkeys(T), owned(T); ok('... the stored survivor keeps c4 on B1, c5 on B2 and one Flip; the phantom stays forgotten')
# no crossing, no merge: Flip, Esau Jr. and a continue change the seed or keep the type
T = fresh(); W(); g.floorName = 'B1'; run(T, L((0, pl({4:1, FL:1}, {}, TA, 29)))); g.floorName = 'B2'; run(T, L((0, pl({FL:1, 5:1}, {}, TB, 38)))); run(T, L((0, pl({4:1, FL:1}, {}, TA, 29))))
assert rows(T) == [(TA,0,False),(TB,1,True)] and owned(T) == [(4,'B1',TA),(5,'B2',TB),(FL,'B1',TA),(FL,'B2',TB)], (rows(T), owned(T)); ok('plain Flip there and back: no merge, each form keeps its items')
T = fresh(); W(); g.floorName = 'B1'; run(T, L((0, pl({4:1, FL:1}, {}, TA, 29)))); g.floorName = 'B2'; run(T, L((0, pl({FL:1}, {}, TB, 29))))
assert rows(T) == [(TA,0,True),(TB,1,False)] and (4,'B1',TA) in owned(T) and gone(T) == [], (rows(T), owned(T)); ok('Esau Jr. on Tainted Lazarus (same type, new seed): the original stays stored, no merge')
T = fresh(); W(); g.floorName = 'B1'; run(T, L((0, pl({4:1, FL:1}, {}, TA, 29)))); g.floorName = 'B2'; run(T, L((0, pl({FL:1, 5:1}, {}, TB, 38))))
T = roundtrip(T); T.update(L((0, pl({FL:1, 5:1}, {}, TB, 38))))
assert rows(T) == [(TA,0,True),(TB,1,False)] and (4,'B1',TA) in owned(T) and gone(T) == [], (rows(T), owned(T)); ok('first update after a continue: no merge')
run(T, L((0, pl({FL:1, 5:1}, {}, TB, 38))))
assert rows(T) == [(TA,0,True),(TB,1,False)] and (4,'B1',TA) in owned(T), (rows(T), owned(T)); ok('... nor once settled')
g.floorName = 'B1'; W()
# Tainted Lazarus pair record (partnerOf): these print FAIL and carry on, so a run lists every miss; the exit code says whether any failed
failed = []
def check(name, cond, info=None):
    print('PASS' if cond else 'FAIL', name, '' if cond else info)
    if not cond: failed.append(name)
TD = 804
# mirror of the in-game 2026-11-21 crossing: the 29 form (TA) active turned 38 by ChangePlayerType, Dead form TB (38) stored
T = fresh(); W(); g.floorName = 'B1'; run(T, L((0, pl({4:1, FL:1}, {}, TA, 29))))
g.floorName = 'B2'; run(T, L((0, pl({FL:1, 5:1}, {}, TB, 38)))); run(T, L((0, pl({4:1, FL:1}, {}, TA, 29))))
run(T, L((0, pl({4:1, 5:1, FL:1}, {}, TA, 38))))
check('crossing 29->38 with 38 stored: stored Dead form merged, c5 keeps B2', TB not in rowkeys(T) and [e for e in owned(T) if e[0] != FL] == [(4,'B1',TA), (5,'B2',TA)] and gone(T) == [], (rowkeys(T), owned(T)))
# ChangePlayerType on Esau Jr.'s form with Esau Jr. kept leaves the original stored: seen for Clicker into types 35, 13 and 5 (in-game 2026-11-22); 0 and 38 here assumed the same.
T = fresh(); W(); g.floorName = 'B1'; run(T, L((0, pl({4:1, FL:1}, {}, TA, 29))))
g.floorName = 'B2'; run(T, L((0, pl({FL:1, 6:1, EJ:1}, {}, TC, 29))))  # Esau Jr.: same type, new seed
run(T, L((0, pl({FL:1, 6:1, EJ:1}, {}, TC, 0))))
check('ChangePlayerType out of Tainted Lazarus on an Esau Jr. form: the original stays stored', (TA, 0, True) in rows(T) and (4,'B1',TA) in owned(T), (rows(T), owned(T)))
T = fresh(); W(); g.floorName = 'B1'; run(T, L((0, pl({4:1, FL:1}, {}, TA, 29))))
run(T, L((0, pl({FL:1}, {}, TB, 38)))); run(T, L((0, pl({4:1, FL:1}, {}, TA, 29))))
g.floorName = 'B2'; run(T, L((0, pl({FL:1, 6:1, EJ:1}, {}, TB, 29)))); run(T, L((0, pl({FL:1, 6:1, EJ:1}, {}, TB, 38))))
check('Esau Jr. reuses the Dead seed: crossing 29->38 leaves the original stored',
      rows(T) == [(TA, 0, True), (TB, 1, False)] and (4,'B1',TA) in owned(T), (rows(T), owned(T)))
# a save without type or partner (2.7): the stored 29 form is told by its single Tainted Lazarus innate row, then ChangePlayerType out
T = fresh(); W(); g.floorName = 'B1'; run(T, L((0, pl({1:1}, {}, 29, 29))))
g.floorName = 'B2'; run(T, L((0, pl({2:1}, {}, 38, 38))))
ids, floors, owners_, rws, temps = T.serialize()
for r in rws.values(): r.type, r.partner = None, None
T2 = fresh(); T2.restore(ids, floors, owners_, rws, temps); run(T2, L((0, pl({2:1}, {}, 38, 38)))); run(T2, L((0, pl({1:1,2:1}, {}, 38, 0))))
check('save without type or partner: the stored form merges by its innate row', entries(T2) == [(1,1,'B1',False),(2,1,'B2',False)] and rowkeys(T2) == [38], (entries(T2), rowkeys(T2)))
# a crossing on the first update after a continue: reachable by mods only (ChangePlayerType that early), no player action does it
T = fresh(); W(); g.floorName = 'B1'; run(T, L((0, pl({4:1, FL:1}, {}, TA, 29))))
g.floorName = 'B2'; run(T, L((0, pl({FL:1, 5:1}, {}, TB, 38))))
T = roundtrip(T); T.update(L((0, pl({4:1, 5:1, FL:1}, {}, TB, 29)))); run(T, L((0, pl({4:1, 5:1, FL:1}, {}, TB, 29))))
check('continue, crossing on its first update: the stored form merged', TA not in rowkeys(T) and [e for e in owned(T) if e[0] != FL] == [(4,'B1',TB), (5,'B2',TB)], (rowkeys(T), owned(T)))
# Birthright lost after a continue
T = fresh(); W(); g.floorName = 'B1'; run(T, L((0, pl({1:1}, {}, 29, 29)), (1, pl({2:1}, {}, 38, 38))))
T = roundtrip(T); run(T, L((0, pl({1:1}, {}, 29, 29)), (1, pl({2:1}, {}, 38, 38)))); run(T, L((0, pl({2:1}, {}, 38, 38))))
check('continue, then Birthright lost: the other form stored', (29, 0, True) in rows(T) and gone(T) == [] and entries(T) == [(1,0,'B1',False),(2,1,'B1',False)], (rows(T), entries(T)))
# Esau Jr.'s form keeps the same seed when it Flips; flipping back leaves the original stored.
for cont in (False, True):
    T = fresh(); W(); g.floorName = 'B1'; run(T, L((0, pl({4:1, FL:1}, {}, TA, 29))))
    g.floorName = 'B2'; run(T, L((0, pl({FL:1, 6:1, EJ:1}, {}, TC, 29))))
    run(T, L((0, pl({FL:1}, {}, TC, 38))))
    if cont: T = roundtrip(T); run(T, L((0, pl({FL:1}, {}, TC, 38))))
    run(T, L((0, pl({FL:1, 6:1, EJ:1}, {}, TC, 29))))
    check('same-seed Flip back on an Esau Jr. form%s: the original stays stored' % (' after a continue' if cont else ''),
          rows(T) == [(TA, 0, True), (TC, 1, False)] and owned(T) == [(4,'B1',TA), (6,'B2',TC), (FL,'B1',TA), (FL,'B2',TC), (EJ,'B2',TC)] and not gone(T),
          (rows(T), owned(T)))
# co-op: two Tainted Lazarus players both flip, one is Clickered out: only that player's stored form merges (live and after a continue)
LA, LB, LX, LY = 901, 902, 903, 904
for cont in (False, True):
    T = fresh(); W(); g.floorName = 'B1'; run(T, L((0, P({4:1, FL:1}, seed=LA, ptype=29)), (1, P({6:1, FL:1}, seed=LX, ptype=29))))
    g.floorName = 'B2'; run(T, L((0, P({FL:1}, seed=LB, ptype=38)), (1, P({FL:1, 7:1}, seed=LY, ptype=38))))
    if cont: T = roundtrip(T); run(T, L((0, P({FL:1}, seed=LB, ptype=38)), (1, P({FL:1, 7:1}, seed=LY, ptype=38))))
    run(T, L((0, P({FL:1}, seed=LB, ptype=38)), (1, P({FL:1, 6:1, 7:1}, seed=LY, ptype=21))))
    check('co-op Tainted Lazarus pair Clickered%s: only its stored form merges, the other pair stays' % (' after a continue' if cont else ''),
          (LA, 0, True) in rows(T) and LX not in rowkeys(T) and [e for e in owned(T) if e[0] == 6] == [(6,'B1',LY)] and (4,'B1',LA) in owned(T) and gone(T) == [], (rows(T), owned(T)))
g.floorName = 'B1'; W()
# Observed seed, type and inventory transitions, seen in game (2026-11-21).
BR, RANDOM = 14, 15
A, B, C, D = TA, TB, TC, TD
BJ, DJ = B + 2**32, D + 2**32  # keys of a second character on B's and D's seeds
original = (4, EJ, FL)
esau = (5, EJ, FL, RANDOM)
def form(seed, ptype, *ids):
    return pl({id_: 1 for id_ in ids}, {}, seed, ptype)

def other(p, ent):  # another entity on the same seed
    p.ent = ent; return p

def play(T, *players, n=31):
    run(T, L(*enumerate(players)), n)

def replay(T, name, *expected, label='obs '):
    expected_rows = sorted((key, number, swapped) for key, number, swapped, _ in expected)
    expected_items = sorted((key, number, id_) for key, number, _, ids in expected for id_ in ids)
    actual_items = sorted((e.owner, e.number, e.id) for e in T.entries.values() if not e.left)
    check(label + name, rows(T) == expected_rows and actual_items == expected_items
          and not gone(T) and not any(e.merged for e in T.entries.values()), (rows(T), actual_items))

def esau_setup():
    T = fresh()
    play(T, form(A, 29, *original))
    play(T, form(B, 29, *esau))
    return T

for name, transitions, returned_type, a_items in (
    ('cross', [(38, esau), (0, (5, EJ, RANDOM))], 0, (4, EJ)),
    ('out', [(0, (5, EJ, RANDOM))], 0, (4, EJ)),
    ('flip', [(38, (FL,)), (29, esau)], 29, original),
    # ReHUD's isCharacter filters the extra type-40 Soul before updating the tracker.
    ('cross35', [(35, (5, EJ, RANDOM))], 35, (4, EJ)),  # also Clicker's effect with Esau Jr. kept (in-game 2026-11-22)
):
    T = esau_setup()
    if name == 'cross':
        T = roundtrip(T)
        run(T, L((0, form(B, 29, *esau))))
    for ptype, b_items in transitions:
        play(T, form(B, ptype, *b_items), n=3)
        check('obs ' + name + ': A#0 stays stored while B becomes type ' + str(ptype),
              (A, 0, True) in rows(T) and (4, 'B1', A) in owned(T), (rows(T), owned(T)))
    play(T, form(A, returned_type, *a_items), n=60)
    replay(T, name + ': A returns', (A, 0, False, a_items), (B, 1, True, b_items))
    if name == 'cross35':
        play(T, form(B, 35, *b_items))
        replay(T, name + ': B returns', (A, 0, True, a_items), (B, 1, False, b_items))

T = fresh()
play(T, form(A, 29, *original))
play(T, form(B, 38, 5, FL))
play(T, form(A, 29, *original))
play(T, other(form(B, 29, EJ, FL, RANDOM), 'Bj'), n=3)
replay(T, 'flipped cross: Esau Jr. reuses the Dead form seed: own row, the Dead form stored', (A, 0, True, original), (B, 1, True, (5, FL)), (BJ, 2, False, (EJ, FL, RANDOM)))
play(T, other(form(B, 38, *esau), 'Bj'), n=3)
play(T, form(A, 38, *original), n=60)
# A returning as the Dead form's type merges the stored Dead form into it (what the engine did with that form is unobserved; A came back without the Dead form's items)
replay(T, 'flipped cross: A returns', (A, 0, False, original), (BJ, 2, True, esau))
play(T, other(form(B, 38, *esau), 'Bj'), n=60)
replay(T, 'flipped cross: Esau Jr. returns its form', (A, 0, True, original), (BJ, 2, False, esau))

T = esau_setup()
play(T, form(B, 29, *esau, BR), other(form(B, 38, FL), 'twin'), n=6)
play(T, form(B, 29, *esau), n=60)
replay(T, 'birthright removed: A stays stored, the twin stored too', (A, 0, True, original), (B, 1, False, esau), (BJ, 2, True, (FL,)))

T = fresh()
play(T, form(C, 29, *original))
play(T, form(C, 29, *original, BR), form(D, 38, FL))
play(T, other(form(D, 29, EJ, FL, RANDOM), 'Dj'))
replay(T, 'birthright: Esau Jr. stores C and its twin D, its form on that seed gets its own row', (C, 0, True, (*original, BR)), (D, 1, True, (FL,)), (DJ, 2, False, (EJ, FL, RANDOM)))
play(T, other(form(D, 29, *esau), 'Dj'), n=3)
play(T, form(C, 29, *original, BR), form(D, 38, FL), n=60)
replay(T, 'birthright: C returns with c4 and Birthright, D with its own items, the form stored with its own', (C, 0, False, (*original, BR)), (D, 1, False, (FL,)), (DJ, 2, True, esau))

T = esau_setup()
play(T, form(B, 29, *esau, BR), other(form(B, 38, FL), 'twin'), n=60)
check('obs birthright keep: A#0 stays stored with two live B entities',
      (A, 0, True) in rows(T) and (4, 'B1', A) in owned(T), (rows(T), owned(T)))
play(T, form(A, 29, *original), n=60)
replay(T, 'birthright keep: A returns, B and its twin stored with their own items', (A, 0, False, original), (B, 1, True, (*esau, BR)), (BJ, 2, True, (FL,)))

T = esau_setup()
play(T, form(B, 29, *esau, BR), other(form(B, 38, FL), 'twin'), n=15)
play(T, other(form(B, 38, FL), 'twin'), form(B, 29, *esau, BR), n=60)
check('obs birthright flip: A#0 stays stored after B exchanges indexes',
      rows(T) == [(A, 0, True), (B, 1, False), (BJ, 2, False)]
      and [id_ for id_, _, key in owned(T) if key == A] == sorted(original)
      and not any(e.merged for e in T.entries.values()), (rows(T), owned(T)))

T = esau_setup()
play(T, form(A, 29, *original))
replay(T, 'dead seed: A returns', (A, 0, False, original), (B, 1, True, esau))
play(T, other(form(B, 38, FL), 'Bdead'), n=60)
replay(T, 'dead seed: Flip of A on B\'s seed gets its own row', (A, 0, True, original), (B, 1, True, esau), (BJ, 2, False, (FL,)))

T = fresh()
play(T, form(A, 29, 4, FL))
play(T, form(B, 38, 5, FL))
replay(T, 'mirror: Flip stores A', (A, 0, True, (4, FL)), (B, 1, False, (5, FL)))
play(T, form(A, 29, 4, FL))
replay(T, 'mirror: Flip back stores B', (A, 0, False, (4, FL)), (B, 1, True, (5, FL)))
play(T, form(A, 38, 4, 5, FL), n=60)
replay(T, 'mirror: same-seed crossing merges B into A', (A, 0, False, (4, 5, FL)))

# in game (2026-11-22): the engine never frees an Esau Jr. slot within a run, so a stored character stays listed with its items whatever happens to Esau Jr. (user decision 2026-11-22)
T = esau_setup()
play(T, form(B, 29, 5, RANDOM, FL, CK))
replay(T, 'form loses Esau Jr.: A stays stored with its items', (A, 0, True, original), (B, 1, False, (5, RANDOM, FL, CK)))
play(T, form(B, 29, 5, RANDOM, FL, EJ))
play(T, form(D, 29, 7, EJ, FL))
replay(T, 'form loses Esau Jr.: Esau Jr. given back introduces D', (A, 0, True, original), (B, 1, True, (5, RANDOM, FL, EJ)), (D, 2, False, (7, EJ, FL)))
play(T, form(B, 29, 5, RANDOM, FL, EJ))
replay(T, 'form loses Esau Jr.: Esau Jr. returns B', (A, 0, True, original), (B, 1, False, (5, RANDOM, FL, EJ)), (D, 2, True, (7, EJ, FL)))

T = esau_setup()
play(T, form(B, 38, FL), n=3)
play(T, form(B, 35, 5, CK))
replay(T, 'Clicker on the flipped form, Esau Jr. replaced: A stays stored with its items', (A, 0, True, original), (B, 1, False, (5, CK)))

T = esau_setup()
play(T, form(B, 29, *esau, BR), other(form(B, 38, FL), 'twin'), n=6)
play(T, form(B, 29, 5, RANDOM, FL, BR, CK), other(form(B, 38, FL), 'twin'))
replay(T, 'Birthright form loses Esau Jr.: A stays stored, its flipped twin plays on', (A, 0, True, original), (B, 1, False, (5, RANDOM, FL, BR, CK)), (BJ, 2, False, (FL,)))

D6ED = 16  # what D6 turned the used Esau Jr. into (item 236 in game)
T = fresh()
play(T, form(A, 0, 4, EJ))
play(T, form(B, 0, 5, EJ))
play(T, form(B, 0, 5, D6ED))
replay(T, 'Isaac form D6s its used Esau Jr.: Isaac stays stored with his items', (A, 0, True, (4, EJ)), (B, 1, False, (5, D6ED)))
T = roundtrip(T); play(T, form(B, 0, 5, D6ED))
replay(T, '... and after a continue', (A, 0, True, (4, EJ)), (B, 1, False, (5, D6ED)))

T = esau_setup()
play(T, form(A, 29, *original))
play(T, form(A, 29, 4, FL, CK))
# whether the next press then brings B's entity or a new one on B's seed (obsx2) is unobserved, so no step for it
replay(T, 'original loses Esau Jr.: B stays stored with its items', (A, 0, False, (4, FL, CK)), (B, 1, True, esau))

# two Esau Jr. copies juggled (in-game 2026-11-22): Isaac presses copy 1 -> A, A presses copy 2 -> B, then copy 2 swaps A and B; each keeps its own items
I0, IA, IB = 910, 911, 912
T = fresh()
play(T, form(I0, 0, 1, EJ))
play(T, form(IA, 0, 2, EJ))
play(T, form(IB, 0, 3, EJ, 6))
play(T, form(IA, 0, 2, EJ, 7))
play(T, form(IB, 0, 3, EJ, 6))
replay(T, 'two copies juggled: B back, Isaac and A stored with their own items', (I0, 0, True, (1, EJ)), (IA, 1, True, (2, EJ, 7)), (IB, 2, False, (3, EJ, 6)))
play(T, form(IA, 0, 2, EJ, 7))
replay(T, '... and A back', (I0, 0, True, (1, EJ)), (IA, 1, False, (2, EJ, 7)), (IB, 2, True, (3, EJ, 6)))

# a third, never-pressed copy pressed by Isaac makes C on A's item seed and type (in-game 2026-11-22): a second key for that seed, own items
IC = IA + 2**32
T = fresh()
play(T, form(I0, 0, 1, EJ))
play(T, form(IA, 0, 2, EJ, 7))
play(T, form(IB, 0, 3, EJ))
play(T, form(I0, 0, 1, EJ))
c_form = lambda: other(form(IA, 0, 8, EJ), 'C')
play(T, c_form())
replay(T, 'same-seed Isaac forms: C on A\'s seed gets its own row', (I0, 0, True, (1, EJ)), (IA, 1, True, (2, EJ, 7)), (IB, 2, True, (3, EJ)), (IC, 3, False, (8, EJ)))
play(T, form(IA, 0, 2, EJ, 7))
replay(T, '... A plays again: its own row and items, C stored', (I0, 0, True, (1, EJ)), (IA, 1, False, (2, EJ, 7)), (IB, 2, True, (3, EJ)), (IC, 3, True, (8, EJ)))
T = roundtrip(T); play(T, form(IA, 0, 2, EJ, 7)); play(T, c_form())
replay(T, '... after a continue (GetData wiped) each takes its seed\'s keys in the order they play, here the right ones', (I0, 0, True, (1, EJ)), (IA, 1, True, (2, EJ, 7)), (IB, 2, True, (3, EJ)), (IC, 3, False, (8, EJ)))
T = roundtrip(T); play(T, c_form())
check('... C playing first after a continue takes A\'s row (shortcut: stated limit)', (IA, 1, False) in rows(T), rows(T))

# Tainted Lazarus (29) pressing Esau Jr. with the Dead form (38) stored makes a type-29 form on the Dead form's seed (in-game 2026-11-22)
LJ = B + 2**32
T = fresh()
play(T, form(A, 29, 4, FL, EJ))
play(T, form(B, 38, 5, FL))
play(T, form(A, 29, 4, FL, EJ))
play(T, other(form(B, 29, 6, FL, EJ), 'LJ'))
replay(T, 'Tainted Lazarus form on Dead Lazarus\'s seed: own row, both forms stored with their items', (A, 0, True, (4, FL, EJ)), (B, 1, True, (5, FL)), (LJ, 2, False, (6, FL, EJ)))

# Strawman's Keeper (type 14, Parent set, own new seed; in-game 2026-11-22): a character with its own row
KP = 920
T = fresh(); isa = pl({1:1}, {}, I0, 0); keeper = pl({2:1}, {}, KP, 14); keeper.Parent = isa
play(T, isa, keeper)
replay(T, 'Strawman Keeper: own row and items', (I0, 0, False, (1,)), (KP, 1, False, (2,)), label='')

# Soul of Jacob and Esau's Esau (type 20, Parent set, a new seed per summon; in-game 2026-11-22): a row while present, removed when he leaves (user decision 2026-11-22)
SE, SE2 = 921, 922
def summon(seed, *ids):
    e = form(seed, 20, *ids); e.Parent = isa; return e
T = fresh(); isa = form(I0, 0, 1)
play(T, isa, summon(SE, 2, 3))
replay(T, 'summoned Esau: own row and items', (I0, 0, False, (1,)), (SE, 1, False, (2, 3)), label='')
T = roundtrip(T); play(T, form(I0, 0, 1), summon(SE, 2, 3))
replay(T, '... kept across a continue while present', (I0, 0, False, (1,)), (SE, 1, False, (2, 3)), label='')
play(T, form(I0, 0, 1))
replay(T, '... he leaves: row and items gone, none moved to Isaac', (I0, 0, False, (1,)), label='')
play(T, form(I0, 0, 1), summon(SE2, 4))
replay(T, '... summoned again (new seed): a new row', (I0, 0, False, (1,)), (SE2, 2, False, (4,)), label='')
T = roundtrip(T); play(T, form(I0, 0, 1))
replay(T, '... saved but absent after a continue: forgotten', (I0, 0, False, (1,)), label='')

# Not observed in game: guards for the design.
T = esau_setup()
play(T, form(B, 29, *esau), P({}, seed=50))
play(T, P({}, seed=B, ptype=29, ghost=True), P({}, seed=50))
check('ghost counterpart: A stays stored', (A, 0, True) in rows(T), rows(T))
X = 905  # A's Dead form from an earlier Flip
T = fresh()
play(T, form(A, 29, *original))
play(T, form(X, 38, 8, FL))
play(T, form(A, 29, *original))
play(T, form(B, 29, *esau))
play(T, form(B, 29, 5, RANDOM, FL, CK))
replay(T, "form loses Esau Jr. after the original's Flip: the original and its Dead form stay stored", (A, 0, True, original), (X, 1, True, (8, FL)), (B, 2, False, (5, RANDOM, FL, CK)), label='')
play(T, form(X, 38, 8, FL), n=1)  # the Esau Jr. form flips to the original's Dead form (in-game 2026-11-22); one update: a merge would list items on the wrong one
replay(T, "... then B's Flip brings the Dead form back: nobody gets another's items", (A, 0, True, original), (X, 1, False, (8, FL)), (B, 2, True, (5, RANDOM, FL, CK)), label='')
T = fresh()
play(T, P({4:1}, seed=50), P({6:1, FL:1}, seed=C, ptype=29))
newcomer = lambda ptype: P({7:1, FL:1}, seed=D, ptype=ptype)
q = newcomer(29); q.ControllerIndex = 5; play(T, P({4:1}, seed=50), q)
q = newcomer(35); q.ControllerIndex = 5; play(T, P({4:1}, seed=50), q)
check('co-op newcomer at a vacated index without Esau Jr.: no link, the old player is kept', C in [r[0] for r in rows(T)] and (6, 'B1', C) in [(e.id, e.floor, e.owner) for e in T.entries.values()], rows(T))
T = fresh()
play(T, form(C, 29, *original))
play(T, form(C, 29, *original, BR), form(D, 38, FL))
play(T, other(form(D, 29, EJ, FL, RANDOM), 'Dj'))
play(T, other(form(D, 29, FL, RANDOM, CK), 'Dj'))
replay(T, "Birthright Esau Jr. form loses Esau Jr.: C and its twin D stay stored, the form plays on", (C, 0, True, (*original, BR)), (D, 1, True, (FL,)), (DJ, 2, False, (FL, RANDOM, CK)), label='')
p2 = lambda: P({6:1}, seed=50, ent='p2')
T = fresh()
play(T, form(A, 29, 4, FL), p2())
play(T, form(X, 38, 8, FL), p2())
q = p2(); q.ControllerIndex = 1; play(T, q)  # online co-op: the Tainted Lazarus player leaves with A stored, P2 shifts to index 0
check('co-op Tainted Lazarus leaves with its other form stored: both read as left, not stored',
      rows(T) == sorted([(A, 0, False), (50, 1, False), (X, 2, False)]) and sorted((e.id, e.owner) for e in T.entries.values() if e.left) == sorted([(4, A), (8, X), (FL, A), (FL, X)]), (rows(T), gone(T)))

T = fresh()
play(T, form(A, 29, 4))
play(T, form(B, 38, 5))
play(T, form(B, 29, 4, 5), n=1)
check('merge starts settling before the survivor is stored',
      any(e.merged for e in T.entries.values()), owned(T))
play(T, form(C, 38, FL), n=60)
replay(T, 'stored survivor clears merge flags', (B, 1, True, (4, 5)), (C, 2, False, (FL,)), label='')
T = fresh()
play(T, form(A, 29, 4, FL))
play(T, form(B, 38, 5, FL))
play(T, form(B, 38, 5, FL, EJ))
play(T, form(A, 29, 4, FL))
play(T, form(B, 38, 5, FL, EJ))
play(T, form(B, 21, 4, 5, FL, EJ))
replay(T, 'Dead form holding its own Esau Jr., Clicker out: the stored form merges', (B, 1, False, (4, 5, FL, EJ)), label='')
assert not failed, failed
