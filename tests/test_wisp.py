import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))  # -I leaves the script's folder off sys.path
from stubs import *

# ids: 1 Sad Onion (real), 2 Lucky Foot, 3 Clicker->Lemegeton (real), 4..9 wisp items
CAIN, ESAU = 500, 501
def jacob(mod): return P({1:1,2:1,3:1}, mod, seed=CAIN, ptype=19, ctrl=-2)
def esau(): return P({}, {}, seed=ESAU, ptype=20, ctrl=-2)
# started Cain: Lucky Foot owned + innate, Lemegeton, wisps after settle
T = fresh(); c = lambda mod: L((0, P({2:1,3:1}, {2:1, **mod}, seed=CAIN, ptype=2)))
run(T, c({})); W((4, CAIN)); run(T, c({4:1})); W((4, CAIN), (5, CAIN)); run(T, c({4:1,5:1})); W()
assert [e for e in entries(T) if e[0] >= 4] == [(4,0,'B1',True),(5,0,'B1',True)], entries(T); ok('plain Cain: post-settle wisps tracked, temporary')
# Cain -> Clicker -> Jacob + new Esau at index 1, wisp during the new settle window and after
T = fresh(); run(T, c({}))
T.update(L((0, jacob({})), (1, esau())))          # type change and Esau join in the same update
W((6, CAIN)); run(T, L((0, jacob({6:1})), (1, esau())), 5)  # inside the 30-update settle: attributed to its familiar, not learned
run(T, L((0, jacob({6:1})), (1, esau())), 30)      # settle ends
W((6, CAIN), (7, CAIN)); run(T, L((0, jacob({6:1,7:1})), (1, esau())))      # after settle
W((6, CAIN), (7, CAIN), (8, CAIN), (9, CAIN)); run(T, L((0, jacob({6:1,7:1,8:1,9:1})), (1, esau())))
w = [e for e in entries(T) if e[0] >= 6]
assert w == [(6,0,'B1',True),(7,0,'B1',True),(8,0,'B1',True),(9,0,'B1',True)], w; ok('Clicker->J&E: every wisp temporary for Jacob, one inside the settle too; Esau resets nothing')
