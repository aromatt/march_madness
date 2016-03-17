#!/usr/bin/env python
import sys
from os.path import dirname
import fileinput
import numpy as np
from scipy.sparse import csc_matrix, lil_matrix
from sklearn.preprocessing import maxabs_scale, normalize
from sklearn.neighbors import KNeighborsClassifier, KNeighborsRegressor
from sklearn.cross_validation import train_test_split
from sparsesvd import sparsesvd
import json as json
import hashlib, binascii
import operator

TEAM_INDEX_PATH = dirname(__file__) + "/../stat/teams.index"
TEAM_IDS_NAMES_PATH = dirname(__file__) + "/../stat/team_ids_names.tsv"
GAME_OUTCOMES_PATH = dirname(__file__) + "/../stat/game_outcomes.json"
TOURNAMENT_PATH = dirname(__file__) + "/../stat/tournament.json"

RUN_TOURNAMENT = False
TRAIN_SPLIT = 0.80

DO_SVD = True
KEEP_SV = 100

USE_HASH = False
HASH_SPACE = 1 << 9

WEIGHT_GATE = 0            # 0 seems to be best? actually 1 or 2
WEIGHT_CEIL = 100000
WEIGHT_IGNORE = 10000000
BINARY_WEIGHT_PRE = False   # pre-normalization

NEIGHBORS = 30             # 20 was best


def build_team_index(path):
    team_array = open(path).read().strip().split("\n")
    return dict([(int(x), i) for (i, x) in enumerate(team_array) if len(x) > 0])

def build_team_ids_names(path):
    lines = open(path).read().strip().split("\n")
    return dict([(int(i), x) for (i, x) in [l.split("\t") for l in lines]])

def build_games_map(path):
    h = []
    for line in open(path):
        h.append(json.loads(line))
    return h

def get_num_features(path):
    fs = {}
    for line in open(path):
        for f in json.loads(line).values()[0].keys():
            fs[f] = 1
    return len(fs.keys())

def get_tuple_key(key):
    if USE_HASH:
        return hash(key) % HASH_SPACE
    else:
        if key in tuple_keys:
            return tuple_keys[key]
        else:
            tuple_keys[key] = len(tuple_keys)
            return tuple_keys[key]

def empty_features_matrix(path):
    num_features = HASH_SPACE if USE_HASH else get_num_features(tuples_path)
    return num_features, np.empty([len(team_index), num_features])

tuples_path = sys.argv[1]
team_index = build_team_index(TEAM_INDEX_PATH)
team_name = build_team_ids_names(TEAM_IDS_NAMES_PATH)
games = build_games_map(GAME_OUTCOMES_PATH)
tuple_keys = {}

print "Building team * features matrix..."
num_features, team_features = empty_features_matrix(tuples_path)
for line in open(tuples_path):
    obj = json.loads(line)
    team = int(obj['team'])
    vec = np.zeros(num_features)
    for tuple_key, count in obj['tuples'].iteritems():
        val = count
        val = min(max(val - WEIGHT_GATE, 0), WEIGHT_CEIL)
        val = 0 if val > WEIGHT_IGNORE else val
        if BINARY_WEIGHT_PRE:
            val = 1 if val > 0 else 0
        vec[get_tuple_key(tuple_key)] = val
    team_features[team_index[team]] = vec
print team_features.shape
print team_features

print "Normalizing matrix..." # TODO norm
maxabs_scale(team_features, axis=0, copy=False) # scale each feature
maxabs_scale(team_features, axis=1, copy=False) # scale each team
print team_features
csc = csc_matrix(team_features)

if DO_SVD:
    print "Computing SVD..."
    ut, s, vt = sparsesvd(csc, KEEP_SV)
    #team_feat_dense = np.dot(np.transpose(ut), np.square(np.diag(s)))
    #team_feat_dense = np.transpose(ut)
    team_feat_dense = np.dot(np.transpose(ut), np.diag(s))
    print "Dense team feature vectors:", team_feat_dense.shape
    print team_feat_dense
    actual_features = len(s)
    print "%s singular values, min: %s, max: %s" % (actual_features, min(s), max(s))
else:
    print "Skipping SVD."
    actual_features = num_features
    team_feat_dense = team_features

# Each row in games_matrix is a concatenation of the teams' dense feature vectors.
# For each, store two entries: one with winner first and one with loser first.
print "Building games matrix..."
games_matrix = np.empty([len(games * 2), actual_features * 2])
regress_vec = np.empty(len(games * 2))
class_vec = np.empty(len(games * 2))
for (i, game) in enumerate(games):
    w_index, l_index = [i, i + len(games)]
    w_vec = team_feat_dense[team_index[game['winner']]]
    l_vec = team_feat_dense[team_index[game['loser']]]

    games_matrix[w_index] = np.concatenate([w_vec, l_vec])
    games_matrix[l_index] = np.concatenate([l_vec, w_vec])

    regress_vec[w_index] = game['score_diff']
    regress_vec[l_index] = -game['score_diff']
    class_vec[w_index] = 1.0
    class_vec[l_index] = -1.0
print games_matrix.shape
print


# distance metrics: http://scikit-learn.org/stable/modules/generated/sklearn.neighbors.DistanceMetric.html#sklearn.neighbors.DistanceMetric
# KNN http://scikit-learn.org/stable/modules/generated/sklearn.neighbors.KNeighborsClassifier.html#sklearn.neighbors.KNeighborsClassifier
# http://scikit-learn.org/stable/modules/generated/sklearn.neighbors.KNeighborsRegressor.html
print "Regression test..."
games_train, games_test, regress_train, regress_test = train_test_split(
        games_matrix, regress_vec, test_size=TRAIN_SPLIT)
n = KNeighborsRegressor(
        n_neighbors=NEIGHBORS,         # saw highest accuracy with 20
        algorithm='kd_tree',
        weights='uniform',      # saw highest accuracy with uniform
        #weights='distance',
        #metric='minkowski', p=2,
        n_jobs = 3, # number of CPU cores (-1 for all)
        )
n.fit(games_train, regress_train)
print "Accuracy training data:", n.score(games_train, regress_train)
print "Accuracy test data:", n.score(games_test, regress_test)
print
if not RUN_TOURNAMENT:
    print "Some predictions:"
    for i in range(0,10):
        print "  ", n.predict([games_test[i]]), regress_test[i]
    print

print "Classification test..."
games_train, games_test, class_train, class_test = train_test_split(
        games_matrix, class_vec, test_size=TRAIN_SPLIT)
n = KNeighborsClassifier(
        n_neighbors=NEIGHBORS,
        algorithm='kd_tree',
        weights='uniform',      # saw highest accuracy with uniform
        #weights='distance',
        #metric='minkowski', p=1,
        n_jobs = 3, # number of CPU cores (-1 for all)
        )
n.fit(games_train, class_train)
print "Accuracy training data:", n.score(games_train, class_train)
print "Accuracy test data:", n.score(games_test, class_test)
print
if not RUN_TOURNAMENT:
    print "Some predictions:"
    for i in range(0, 10):
        print "  ", n.predict([games_test[i]]), class_test[i]
    print

if not RUN_TOURNAMENT:
    sys.exit()

print "Running tournament..."
def encode_game(a, b):
    a_vec = team_feat_dense[team_index[a]]
    b_vec = team_feat_dense[team_index[b]]
    a_first = np.concatenate([a_vec, b_vec])
    b_first = np.concatenate([b_vec, a_vec])
    return [a_first, b_first]

def predict_tournament(classifier, a, b):
    """Recursively predicts matches"""
    print "a: ", a, "b: ", b
    a = a if isinstance(a, int) else predict_tournament(classifier, a[0], a[1])
    b = b if isinstance(b, int) else predict_tournament(classifier, b[0], b[1])

    a_first, b_first = encode_game(a, b)
    final = classifier.predict([a_first]) - classifier.predict([b_first])
    winner = a if final > 0 else b

    print "Game ", team_name[a], " vs ", team_name[b], ": ", team_name[winner]
    return winner

a, b = json.loads(open(TOURNAMENT_PATH).read())['games']
predict_tournament(n, a, b)
sys.exit()
