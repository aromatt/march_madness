#!/usr/bin/env python

import sys
from os.path import dirname
import fileinput
import numpy as np
from scipy.sparse import csc_matrix
from sklearn.preprocessing import maxabs_scale, normalize
from sklearn.neighbors import KNeighborsClassifier, KNeighborsRegressor
from sklearn.cross_validation import train_test_split
from sparsesvd import sparsesvd
import json as json
import hashlib, binascii
import operator

TEAM_INDEX_PATH = dirname(__file__) + "/../stat/teams.index"
GAME_OUTCOMES_PATH = dirname(__file__) + "/../stat/game_outcomes.json"

TRAIN_SPLIT = 0.75

USE_HASH = True
HASH_SPACE = 1 << 21

WEIGHT_GATE = 0           # 0 seems to be best? actually 1 or 2
WEIGHT_CEIL = 1000000
WEIGHT_IGNORE = 10000000
BINARY_WEIGHT = True      # True seems best

NEIGHBORS = 20            # 20 was best

# Highest accuracy was seen with a value of ~2-5, but also maybe more features -> more SVs?
KEEP_SV = 5

def build_team_index(path):
    team_array = open(path).read().split("\n")
    return dict([(int(x), i) for (i, x) in enumerate(team_array) if len(x) > 0])

def build_games_map(path):
    h = []
    for line in open(path):
        h.append(json.loads(line))
    return h

tuple_keys = {}
def get_tuple_key(key):
    if USE_HASH:
        return hash(key) % HASH_SPACE
    else:
        if key in tuple_keys:
            return tuple_keys[key]
        else:
            tuple_keys[key] = len(tuple_keys)
            return tuple_keys[key]

team_index = build_team_index(TEAM_INDEX_PATH)
games = build_games_map(GAME_OUTCOMES_PATH)

print "Building team * features matrix..."
team_features = np.empty([len(team_index), HASH_SPACE])
for line in fileinput.input():
    obj = json.loads(line)
    team = int(obj['team'])
    vec = np.zeros(HASH_SPACE)
    for tuple_key, count in obj['tuples'].iteritems():
        val = count
        val = max(val - WEIGHT_GATE, WEIGHT_CEIL)
        val = 0 if val > WEIGHT_IGNORE else val
        if BINARY_WEIGHT:
            val = 1 if val > 0 else 0
        vec[get_tuple_key(tuple_key)] = val
    team_features[team_index[team]] = vec
print team_features.shape
print team_features

print "Normalizing matrix..." # TODO norm
csc = csc_matrix(team_features)
#normalize(csc, axis=0, copy=False)
#normalize(csc, axis=1, copy=False)
maxabs_scale(csc, axis=0, copy=False) # scale each feature
maxabs_scale(csc, axis=1, copy=False) # scale each team
print csc.shape

print "Computing SVD..."
ut, s, vt = sparsesvd(csc, KEEP_SV)
#team_feat_dense = np.dot(np.transpose(ut), np.square(np.diag(s)))
team_feat_dense = np.dot(np.transpose(ut), np.diag(s))
#team_feat_dense = np.transpose(ut)
print "Dense team feature vectors:", team_feat_dense.shape
print team_feat_dense
actual_sv = len(s)
print "%s singular values, min: %s, max: %s" % (actual_sv, min(s), max(s))

print "Building games matrix..."
# Each row in games_matrix is a concatenation of the teams' dense feature vectors.
# For each, store two entries: one with winner first and one with loser first.
games_matrix = np.empty([len(games * 2), actual_sv * 2]) # TODO concat
#games_matrix = np.empty([len(games * 2), actual_sv])
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

print "Some predictions:"
for i in range(0,10):
    print "  ", n.predict([games_test[i]]), class_test[i]
