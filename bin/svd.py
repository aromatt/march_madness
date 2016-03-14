#!/usr/bin/env python

import sys
import fileinput
import numpy as np
from scipy.sparse import csc_matrix
from sparsesvd import sparsesvd
import json as json
import hashlib, binascii
import operator

team_vecs = {}
HASH_SPACE = 1 << 20
KEEP_SV = 100

def hash_tuple_key(key):
    return hash(key) % HASH_SPACE

# TODO could save memory by first creating a team_id->row index, then
# just inserting the vectors into the matrix as they are created
print "Building team feature vectors..."
for line in fileinput.input():
    obj = json.loads(line)
    team = obj['team']
    vec = np.zeros(HASH_SPACE)
    for tuple_key, count in obj['tuples'].iteritems():
        vec[hash_tuple_key(tuple_key)] = count
    team_vecs[team] = vec

print "Sorting by team ID..."
sorted_team_vecs = sorted(team_vecs.items(), key=operator.itemgetter(0))

print "Building sparse matrix..."
a = np.matrix([x[1] for x in sorted_team_vecs])
csc = csc_matrix(a)

print "Computing SVD..."
ut, s, vt = sparsesvd(csc, 100)
