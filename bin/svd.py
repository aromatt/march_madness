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

USE_HASH = False
HASH_SPACE = 1 << 16
WEIGHT_GATE = 0

# highest accuracy was seen with a value of 2
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
        val = count # TODO weight
        val = max(val - WEIGHT_GATE, 0) # TODO weight
        val = 1 if val > 0 else 0 # TODO weight
        vec[get_tuple_key(tuple_key)] = val
    team_features[team_index[team]] = vec
print team_features.shape
print team_features

print "Normalizing matrix..."
# TODO norm
#for i in range(0, len(team_features)):
#    row = team_features[i]
#    s = max(sum(row)**2, 0.0001)
#    team_features[i] = row / s
# TODO norm
#for i in range(0, len(team_features.T)):
#    column = team_features.T[i]
#    s = max(sum(column)**2, 0.0001)
#    team_features[:,i] = column / s

csc = csc_matrix(team_features)
#normalize(csc, axis=0, copy=False) # TODO norm
#normalize(csc, axis=1, copy=False) # TODO norm
maxabs_scale(csc, axis=0, copy=False) # scale each feature TODO norm
maxabs_scale(csc, axis=1, copy=False) # scale each team TODO norm
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
outcomes_vec = np.empty(len(games * 2))
for (i, game) in enumerate(games):
    w_index, l_index = [i, i + len(games)]
    w_vec = team_feat_dense[team_index[game['winner']]]
    l_vec = team_feat_dense[team_index[game['loser']]]

    games_matrix[w_index] = np.concatenate([w_vec, l_vec]) # TODO concat
    #games_matrix[w_index] = w_vec

    games_matrix[l_index] = np.concatenate([l_vec, w_vec]) # TODO concat
    #games_matrix[l_index] = l_vec

    outcomes_vec[w_index] = game['score_diff']**1
    outcomes_vec[l_index] = -1 * (game['score_diff']**1)
print games_matrix.shape

# distance metrics: http://scikit-learn.org/stable/modules/generated/sklearn.neighbors.DistanceMetric.html#sklearn.neighbors.DistanceMetric
# KNN http://scikit-learn.org/stable/modules/generated/sklearn.neighbors.KNeighborsClassifier.html#sklearn.neighbors.KNeighborsClassifier
# http://scikit-learn.org/stable/modules/generated/sklearn.neighbors.KNeighborsRegressor.html
print "Classifying...\n"
games_train, games_test, outcomes_train, outcomes_test = train_test_split(
        games_matrix, outcomes_vec, test_size=0.95)

n = KNeighborsRegressor(
        n_neighbors=20,         # saw highest accuracy with 20
        algorithm='kd_tree',
        #weights='uniform',
        weights='distance',
        metric='minkowski', p=2,
        n_jobs = 3, # number of CPU cores (-1 for all)
        )

n.fit(games_train, outcomes_train)
print "Accuracy training data:", n.score(games_train, outcomes_train)
print "Accuracy test data:", n.score(games_test, outcomes_test)
print

print "Some predictions:"
for i in range(0,10):
    print "  ", n.predict([games_test[i]]), outcomes_test[i]
