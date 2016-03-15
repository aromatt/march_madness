#!/usr/bin/env python

import sys
from os.path import dirname
import fileinput
import numpy as np
from scipy.sparse import csc_matrix
from sklearn.preprocessing import maxabs_scale
from sparsesvd import sparsesvd
import json as json
import hashlib, binascii
import operator

TEAM_INDEX_PATH = dirname(__file__) + "/../teams.index"

HASH_SPACE = 1 << 21
KEEP_SV = 10

def build_team_index(path):
    team_array = open(path).read().split("\n")
    return dict([(int(x), i) for (i, x) in enumerate(team_array) if len(x) > 0])

def hash_tuple_key(key):
    return hash(key) % HASH_SPACE

team_index = build_team_index(TEAM_INDEX_PATH)

team_features = np.empty([len(team_index), HASH_SPACE])

print "Building team * features matrix..."
for line in fileinput.input():
    obj = json.loads(line)
    team = int(obj['team'])
    vec = np.zeros(HASH_SPACE)
    for tuple_key, count in obj['tuples'].iteritems():
        vec[hash_tuple_key(tuple_key)] = count
    team_features[team_index[team]] = vec

print "Normalizing matrix..."
csc = csc_matrix(team_features)
maxabs_scale(csc, axis=0, copy=False) # scale each feature

print "Computing SVD..."
ut, s, vt = sparsesvd(csc, 200)

print "Singular value min/max:", min(s), max(s)

print "Building game vectors matrix..."
games = np.matrix([])
