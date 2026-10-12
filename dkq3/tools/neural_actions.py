#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Authored action performances for the anatomical biped enemies.

The episode humanoids' idle, locomotion and death clips come from the procedural rig author
(neural_rig.pose). It has no vocabulary for the actions that make each class read in play:
aiming and firing, pain, reloading, cowering, work loops, seated poses and heavy strikes.
This module authors those from scratch as a few key poses of semantic controls per sequence.
Frames ease between keys and the shared fixed-length IK (neural_assets.connected_motion)
solves the limbs, as the procedural clips do. The original game supplies only each
sequence's meaning, length and event frames; no source vertices are fitted.

Authoring space is the rig author's normalized body: +X forward, +Y left, Z up, 56 units tall,
floor at Z=-24 and the pelvis over the origin. Hand targets are given in that upright body
and travel with the bent chest; feet are planted in the world.
"""
import argparse, hashlib, json, zipfile
from pathlib import Path
import numpy as np
import skeletal_iqm as sk
from neural_assets import connected_motion, align_vectors, joint_violations

FLOOR = -24.

# Controls of one key pose. Angles are radians: pitch leans forward, roll leans left, yaw
# turns left. Hands are body-space points (None keeps the stance grip); elbows are body-space
# pole hints relative to their hand. Feet are offsets from the planted bind ankle; a
# nonzero `toe_*` pitches the foot (toes down) for kneeling. `aim` is the body-space direction
# of a held item rigidly bound to one hand joint (the action's `barrel`: joint and bind axis).
CONTROLS = dict(root=(0., 0, 0), hips=(0., 0, 0), spine=(0., 0, 0), head=(0., 0),
                hand_l=None, hand_r=None, elbow_l=None, elbow_r=None,
                foot_l=(0., 0, 0), foot_r=(0., 0, 0), toe_l=0., toe_r=0., curl=None, aim=None)

# Stance grips of the rig author (neural_rig.pose), body space.
GRIPS = dict(
    pistol=dict(hand_r=(11.5, -4, 15), hand_l=(11.5, 7, 9)),
    rifle=dict(hand_r=(12, -4, 14.5), hand_l=(13, 3, 14.5)),
    glove=dict(hand_r=(8.5, -6.2, 14.5), hand_l=(8.5, 6.2, 14.5)),
)


def euler(angles):
    pitch, roll, yaw = (tuple(angles)+(0., 0.))[:3]
    def axis(i, a):
        c, s = np.cos(a), np.sin(a); m = np.eye(3)
        j, k = [(1, 2), (2, 0), (0, 1)][i]
        m[j, j] = c; m[j, k] = -s; m[k, j] = s; m[k, k] = c
        return m
    # Yaw about Z, then pitch about Y, then roll about X.
    return axis(2, yaw) @ axis(1, pitch) @ axis(0, -roll)


def ease(t):
    return t*t*(3-2*t)


def sample(keys, frame, count, loop):
    """Controls at `frame`: eased interpolation between the surrounding keys."""
    keys = sorted(keys, key=lambda k: k[0])
    def value(k, name):
        return k[1].get(name, CONTROLS[name])
    times = [k[0] for k in keys]
    if loop:
        span = count
        before = max([k for k in keys if k[0] <= frame], default=keys[-1], key=lambda k: k[0])
        after = min([k for k in keys if k[0] > frame], default=None, key=lambda k: k[0])
        if after is None: after = (keys[0][0]+span, keys[0][1])
        if before[0] > frame: before = (before[0]-span, before[1])
    else:
        if frame <= times[0]: before = after = keys[0]
        elif frame >= times[-1]: before = after = keys[-1]
        else:
            i = max(i for i, t in enumerate(times) if t <= frame)
            before, after = keys[i], keys[i+1]
    t = 0. if after[0] == before[0] else ease((frame-before[0])/(after[0]-before[0]))
    out = {}
    for name, default in CONTROLS.items():
        a, b = value(before, name), value(after, name)
        if a is None or b is None:
            out[name] = None if a is None and b is None else np.asarray(b if a is None else a, float)
            continue
        out[name] = (1-t)*np.asarray(a, float)+t*np.asarray(b, float)
    return out


class Body:
    """A packaged humanoid IQM and its normalized authoring frame."""
    def __init__(self, model):
        self.model = model
        self.index = {n: i for i, n in enumerate(model.names)}
        points = model.arrays[0]
        low = points[:, 2].min()
        self.scale = (points[:, 2].max()-low)/56
        world = sk.matrices(model.bind, model.parents)
        pelvis = world[self.index['pelvis'], :3, 3]
        self.offset = np.array([pelvis[0], pelvis[1], low+24*self.scale])
        bind = model.bind.copy()
        bind[:, :3] /= self.scale
        bind[0, :3] = (model.bind[0, :3]-self.offset)/self.scale
        self.bind = bind
        self.absolute = sk.matrices(bind, model.parents)
        self.normalized = sk.Model(model.arrays, model.meshes, model.triangles, model.names, model.parents, bind, bind[None])

    def world(self, channels):
        out = channels.copy()
        out[..., :3] *= self.scale
        out[..., 0, :3] += self.offset
        return out


def solve(body, c, grip, original=None, world_hands=False, barrel=None, keep_hands=False):
    """Channels for one key-sampled pose (normalized units)."""
    model, index, absolute = body.normalized, body.index, body.absolute
    torso = ('pelvis', 'spine', 'chest', 'neck', 'head')
    def chain(root):
        local = np.array(body.bind)
        local[index['pelvis'], :3] += root
        rotations = dict(pelvis=euler(c['hips']))
        # The chest takes most of a torso bend; the lumbar joint is the stiffer one.
        bend = np.asarray(c['spine'])
        rotations['spine'] = euler(bend*.35); rotations['chest'] = euler(bend*.65)
        head = tuple(c['head'])
        rotations['neck'] = euler((head[0]*.4, 0, head[1]*.4)); rotations['head'] = euler((head[0]*.6, 0, head[1]*.6))
        for name, r in rotations.items():
            m = np.eye(4); m[:3, :3] = r
            local[index[name], 3:7] = sk.channels(m[None, None], [-1])[0, 0, 3:7]
        return local, sk.matrices(local, model.parents)
    root = np.asarray(c['root'], float)
    _, world = chain(root)
    feet = {}
    for side, sign in (('l', 1), ('r', -1)):
        ankle = absolute[index['foot_'+side], :3, 3].copy()
        ankle[1] *= .85
        feet[side] = ankle+np.asarray(c['foot_'+side], float)
    # Lower the pelvis just enough for both legs to reach their feet (neural_rig.pose).
    drop = 0.
    for side in ('l', 'r'):
        hip = world[index['thigh_'+side], :3, 3]
        reach = np.linalg.norm(body.bind[index['shin_'+side], :3])+np.linalg.norm(body.bind[index['foot_'+side], :3])-.25
        height = np.sqrt(max(0., reach*reach-np.sum((hip[:2]-feet[side][:2])**2)))
        drop = max(drop, hip[2]-feet[side][2]-height)
    root = root-[0, 0, drop]
    local, world = chain(root)
    fitted = absolute.copy()
    for name in torso:
        fitted[index[name]] = world[index[name]]
    for side in 'lr':
        # Shoulders ride the chest; IK then places the arm from them.
        fitted[index['clavicle_'+side], :3, :3] = world[index['chest'], :3, :3]
    chest = world[index['chest']] @ np.linalg.inv(absolute[index['chest']])
    stance = GRIPS.get(grip, {})
    for side, sign in (('l', 1), ('r', -1)):
        foot = index['foot_'+side]
        fitted[foot, :3, 3] = feet[side]
        fitted[foot, :3, :3] = euler((float(c['toe_'+side]), 0, 0)) if c['toe_'+side] else np.eye(3)
        fitted[index['shin_'+side], :3, 3] = feet[side]+[10, -sign*1.5, 12]
        hand = c['hand_'+side]
        if hand is None:
            if 'hand_'+side in stance: hand = stance['hand_'+side]
            else: hand = absolute[index['upperarm_'+side], :3, 3]+[3, sign*2, -18]
        hand = np.asarray(hand, float)
        elbow = np.asarray(c['elbow_'+side], float) if c['elbow_'+side] is not None else np.array([-8, sign*6, -5])
        # Hands on the floor or a fixture stay put in the world; others travel with the chest.
        frame = np.eye(4) if world_hands else chest
        target = frame[:3, :3] @ hand+frame[:3, 3]
        pole = frame[:3, :3] @ (hand+elbow)+frame[:3, 3]
        fitted[index['hand_'+side], :3, 3] = target
        fitted[index['forearm_'+side], :3, 3] = pole
        rest = absolute[index['hand_'+side], :3, 3]-absolute[index['forearm_'+side], :3, 3]
        fitted[index['hand_'+side], :3, :3] = align_vectors(rest[None], (target-pole)[None])[0]
    result = connected_motion(model, fitted[None])[0]
    world = sk.matrices(result, model.parents)
    if 'tag_weapon' in index:
        tag = index['tag_weapon']
        transform = np.eye(4)
        transform[:3, :3] = world[index['hand_r'], :3, :3].T
        transform[:3, 3] = model.bind[tag, :3]
        result[tag] = sk.channels(transform[None, None], [-1])[0, 0]
    curl = c['curl'] if c['curl'] is not None else (-.15 if grip == 'relaxed' else -.6)
    for side in ('l', 'r'):
        if 'fingers_'+side in index:
            result[index['fingers_'+side], 3:7] = [0, np.sin(float(curl)), 0, np.cos(float(curl))]
        if 'thumb_'+side in index:
            result[index['thumb_'+side], 3:7] = [np.sin(.35 if side == 'l' else -.35), 0, 0, np.cos(.35)]
    if barrel is not None and c['aim'] is not None:
        joint, axis = barrel
        j = index[joint]
        world = sk.matrices(result, model.parents)
        desired = chest[:3, :3] @ np.asarray(c['aim'], float)
        turn = align_vectors(np.asarray(axis, float)[None], desired[None])[0]
        local = np.eye(4); local[:3, :3] = world[model.parents[j], :3, :3].T @ turn
        result[j, 3:7] = sk.channels(local[None, None], [-1])[0, 0, 3:7]
    if original is not None:
        # Attachment and prop joints the author does not drive keep their packaged channels.
        # Rigs authored before the shared wrist solver changed keep their packaged hand roll,
        # so weapons built into a hand point as they do in that model's other clips.
        if keep_hands:
            for j, name in enumerate(model.names):
                if name.startswith(('hand_', 'fingers_', 'thumb_')) or name == 'tag_weapon': result[j] = original[j]
        driven = set(torso) | {f'{s}_{x}' for s in ('clavicle', 'upperarm', 'forearm', 'hand', 'fingers', 'thumb', 'thigh', 'shin', 'foot', 'toe') for x in 'lr'} | {'tag_weapon'}
        for j, name in enumerate(model.names):
            if name not in driven: result[j] = original[j]
    return result


def perform(body, action, count, grip, original=None):
    """Normalized channels for every frame of one authored sequence."""
    keys = action['keys']; loop = action.get('loop', False)
    frames = []
    for f in range(count):
        c = sample(keys, f, count, loop)
        frames.append(solve(body, c, action.get('grip', grip), None if original is None else original[f],
                            action.get('world_hands', False), action.get('barrel'), action.get('keep_hands', False)))
    return np.array(frames)


def K(*bases, **over):
    """A key pose: later bases and keywords override earlier controls."""
    return {k: v for d in bases+(over,) for k, v in d.items()}


# Shared poses (body space, normalized units).
HEAD_COVER = dict(hand_l=(2, 3.5, 31), hand_r=(2, -3.5, 31), elbow_l=(8, 7, -4), elbow_r=(8, -7, -4))
KNEELING = dict(root=(-6, 0, -22), foot_l=(-9, 0, -1.6), foot_r=(-9, 0, -1.6), toe_l=1.4, toe_r=1.4)
SEATED = dict(root=(-1, 0, -13), foot_l=(12, 0, 0), foot_r=(12, 0, 0))
STOOL = dict(root=(-3, 0, -5), foot_l=(5, 0, 0), foot_r=(5, 0, 0), spine=(.25, 0, 0))
LAP = dict(hand_l=(10, 5, 9), hand_r=(10, -5, 9), elbow_l=(-6, 7, -2), elbow_r=(-6, -7, -2))

COWER_KNEEL = dict(loop=True, keys=[(0, K(KNEELING, HEAD_COVER, spine=(1.0, 0, 0), head=(.5, 0))),
                                     (10, K(KNEELING, HEAD_COVER, spine=(1.1, .04, 0), head=(.55, 0)))])
_RAISED = K(HEAD_COVER, hand_l=(5, 3, 33), hand_r=(5, -3, 33))
COWER_STAND = dict(loop=True, keys=[(f, K(_RAISED, spine=(.25+.02*(f % 4 == 2), -.04*(f % 4 == 2)+.04*(f == 4), 0),
                                           head=(.35+.03*(f % 4 == 2), 0), root=(0, .4 if f % 4 == 0 else -.4, -1.5-.2*(f % 4 == 2))))
                                     for f in (0, 2, 4, 6)])
_BOARD = dict(spine=(.1, 0, 0), head=(.5, 0), hand_l=(9, 3, 12), elbow_l=(-6, 6, -3), elbow_r=(-6, -6, -3))
CLIPBOARD = dict(loop=True, keys=[(0, K(_BOARD, hand_r=(10, -1, 13.5))), (7, K(_BOARD, hand_r=(10.5, 1, 13))),
                                   (14, K(_BOARD, hand_r=(9.5, -1.5, 12.5), spine=(.12, 0, 0), head=(.55, 0))), (21, K(_BOARD, hand_r=(10.5, 0, 14)))])
_POCKET = dict(hand_l=(2.5, 6.5, 3), hand_r=(2.5, -6.5, 3), elbow_l=(-6, 4, 6), elbow_r=(-6, -4, 6))
POCKETS = dict(loop=True, keys=[(0, K(_POCKET, root=(0, .8, 0), hips=(0, -.04, 0), head=(0, .1))),
                                 (9.5, K(_POCKET, root=(0, -.8, 0), hips=(0, .04, 0), head=(.05, -.1)))])
_DESK = dict(spine=(.25, 0, 0), head=(.3, 0))
CONSOLE = dict(loop=True, keys=[(0, K(_DESK, hand_l=(13, 4, 10), hand_r=(13, -4, 8.5))), (5, K(_DESK, hand_l=(13, 4, 8.5), hand_r=(13, -4, 10))),
                                 (10, K(_DESK, hand_l=(14, 5, 10), hand_r=(12.5, -3.5, 8.5), spine=(.27, 0, .05), head=(.32, .05))),
                                 (15, K(_DESK, hand_l=(13, 4, 8.5), hand_r=(13, -4, 10)))])
# On all fours: knees under the hips, hands planted under the shoulders.
_FLOOR = dict(root=(1, 0, -17.5), hips=(.85, 0, 0), spine=(1.0, 0, 0), head=(-.6, 0), foot_l=(-12, 0, -1.6), foot_r=(-12, 0, -1.6),
              toe_l=1.4, toe_r=1.4, hand_l=(17, 5, -22.5), elbow_l=(-2, 5, 4), elbow_r=(-2, -5, 4))
FLOOR_WORK = dict(loop=True, world_hands=True, keys=[(0, K(_FLOOR, hand_r=(16, -5, -22.5))), (8.5, K(_FLOOR, hand_r=(20, -4, -22), spine=(1.05, 0, 0)))])
def _typing(seat, reach, height, bend):
    key = lambda l, r, **o: K(seat, dict(spine=(bend, 0, 0), head=(.25, 0)), hand_l=(reach, 4.5, height+l), hand_r=(reach, -4.5, height+r), **o)
    return dict(loop=True, keys=[(0, key(1, 0)), (5, key(0, 1)), (10, key(1, 0, spine=(bend+.02, 0, .04), head=(.27, .05))), (15, key(0, 1))])

# Guard: one-handed pistol. Between shots the last attack frame holds, so attacks end aimed.
_AIM = dict(hand_r=(19.5, -4.5, 21.5), elbow_r=(-9, -3, -4), hand_l=(1, 9, 4))
_KICK = K(_AIM, hand_r=(17, -4.5, 24.5), spine=(-.06, 0, 0), head=(-.05, 0))
_KNEEL_AIM = dict(root=(-2, 0, -14), foot_l=(9, 0, 0), foot_r=(-13, 0, -1.5), toe_r=1.3)
_TWIST = dict(spine=(0, 0, -.35), hand_r=(18.5, 1.5, 21.5), elbow_r=(-9, -4, -4), hand_l=(-6, 12, 6))
_PISTOL = dict(hand_r=(11.5, -4, 15), hand_l=(11.5, 7, 9))
_CLUTCH = dict(hand_l=(9, 2, 8), hand_r=(9, -3, 9), elbow_r=(-6, -7, 0), elbow_l=(-6, 7, 0))
_LOADING = dict(hand_r=(9, -1, 15), elbow_r=(-7, -7, -3))

# Cryotech: the sprayer is bound to the right fingers joint; it is carried level at the hip
# and swept with the chest.
_SPRAYER = ('fingers_r', (0.691, -0.363, -0.625))
_CARRY = dict(hand_r=(8, -7, 9), elbow_r=(-9, -2, 1), hand_l=(16, -6, 8.5), elbow_l=(-7, 7, -3), aim=(1, 0, -.12))
def _sweep(yaw): return K(_CARRY, spine=(.05, 0, yaw), head=(0, yaw*.5))

# Inmater: rigid forearm weapons; its packaged hand roll is kept (see solve).
_GLOVE = dict(hand_r=(8.5, -6.2, 14.4), hand_l=(8.5, 6.2, 14.4))
_CANNON = K(_GLOVE, hand_r=(10.5, -6.2, 15), elbow_r=(-4.5, -3.8, -3.9))
_RECOIL = K(_GLOVE, hand_r=(6.5, -6.5, 15.5), elbow_r=(-4.5, -3.8, -3.9), spine=(-.07, 0, 0), root=(-1, 0, 0))
def _aimed(yaw, base=_CANNON): return K(base, spine=(base.get('spine', (0, 0, 0))[0], 0, yaw), head=(0, yaw*.5))
def _six_shot_sweep():
    yaw = lambda f: .35-.7*(f-8)/28
    keys = [(0, _GLOVE), (8, _aimed(.35))]
    for f in (10, 14, 18, 22, 26, 36):   # the sweep's shot frames
        keys += [(f, _aimed(yaw(f), _RECOIL)), (f+2, _aimed(yaw(f+2)))]
    return keys+[(44, _GLOVE)]
# Armoured creatures: neutral hands and elbows at their packaged idle.
_RAGE = dict(hand_l=(1.3, 23.4, 3), hand_r=(1.4, -23.3, 3), elbow_l=(-.2, -5.4, 10), elbow_r=(-.5, 5.3, 10))
_SLUDGE = dict(hand_l=(4.5, 23.5, -6), hand_r=(3.8, -23.6, -6), elbow_l=(-3.7, -5.1, 17), elbow_r=(-3.6, 5.5, 17))

# Per model: stance grip and the sequences authored here (all others keep the procedural clips).
ENEMIES = {
    'mishimaguard': dict(grip='pistol', actions=dict(
        ataka=dict(keys=[(0, _AIM), (1.2, _KICK), (3.5, _AIM)]),
        atakb=dict(keys=[(0, K(_AIM, _KNEEL_AIM)), (1.2, K(_KICK, _KNEEL_AIM)), (3.5, K(_AIM, _KNEEL_AIM))]),
        atakc=dict(keys=[(0, _TWIST), (1.2, K(_TWIST, hand_r=(16, 1.5, 24.5), spine=(-.06, 0, -.35))), (4, _TWIST)]),
        hita=dict(keys=[(0, _PISTOL), (3, K(_CLUTCH, spine=(.6, 0, .1), head=(.35, 0), root=(-2, 0, -2))),
                        (7, K(_CLUTCH, hand_l=(9, 2, 7), hand_r=(9, -3, 8), spine=(.75, .05, .1), head=(.45, 0), root=(-3, 0, -3))),
                        (10, dict(spine=(.3, 0, 0), head=(.15, 0), root=(-1, 0, -1), hand_l=(10, 5, 9), hand_r=(10, -4, 12))), (13, _PISTOL)]),
        reload=dict(keys=[(0, _AIM), (4, K(_LOADING, hand_l=(8, 3, 13), head=(.35, 0))), (8, K(_LOADING, hand_l=(2, 6, 4), head=(.3, 0))),
                          (12, K(_LOADING, hand_l=(8, 2, 12), head=(.4, 0))), (14, K(_LOADING, hand_r=(9, -1, 15.5), hand_l=(9, 1, 16), head=(.35, 0))),
                          (17, dict(hand_r=(10, -2, 16), hand_l=(10, 4, 12), head=(.15, 0))), (23, _AIM)]))),
    'cryotech': dict(grip='rifle', actions=dict(
        bambb=dict(barrel=_SPRAYER, keys=[(0, _CARRY), (6, _sweep(-.4)), (8, _sweep(-.4)), (22, _sweep(.4)), (28, _sweep(0))]),
        bambc=dict(barrel=_SPRAYER, keys=[(0, _CARRY), (3, _sweep(-.12)), (8, _sweep(.12)), (9, _sweep(.1))]),
        bamba=dict(barrel=_SPRAYER, loop=True, keys=[(0, _sweep(-.15)), (14.5, _sweep(.15))]),
        hita=dict(barrel=_SPRAYER, keys=[(0, _CARRY), (4, K(_CARRY, spine=(.45, .15, .5), head=(.3, .2), root=(-2.5, 0, -2.5))),
                                         (8, K(_CARRY, spine=(.5, .1, .6), head=(.35, .25), root=(-3, 0, -3))),
                                         (11, K(_CARRY, spine=(.2, 0, .2), root=(-1, 0, -1))), (14, _CARRY)]))),
    'skinnyworker': dict(grip='relaxed', actions=dict(gamba=COWER_KNEEL, gambc=COWER_STAND, eambd=CLIPBOARD, famba=POCKETS,
                                                       bamba=CONSOLE, camba=FLOOR_WORK, samba=_typing(SEATED, 15, 13, .15))),
    'surgeon': dict(grip='relaxed', actions=dict(gamba=COWER_KNEEL, gambc=COWER_STAND, eambd=CLIPBOARD)),
    'fatworker': dict(grip='relaxed', actions=dict(
        scared=dict(loop=True, keys=[(0, K(HEAD_COVER, root=(-4, 0, -3), hips=(.4, 0, 0), spine=(.85, 0, 0), head=(.3, 0))),
                                     (9.5, K(HEAD_COVER, root=(-4, 0, -3.5), hips=(.42, 0, 0), spine=(.92, .05, 0), head=(.35, 0)))]),
        samba=dict(loop=True, keys=[(0, K(STOOL, LAP))]+[
            (f, K(STOOL, LAP, hand_r=(2 - (f == 15), -5 + (f == 15), 31 + (f == 15)), elbow_r=(4, -9, -6), head=(.15, -.15)))
            for f in (8, 15, 22)]),
        tamba=_typing(STOOL, 17, 13, .45),
        camba=dict(keys=[(0, K(STOOL, LAP)), (12, K(STOOL, LAP, hand_r=(10, -12, 22), elbow_r=(-4, -6, -6), head=(0, -.2))), (24, K(STOOL, LAP)),
                         (40, K(STOOL, hand_l=(13, 9, 16), hand_r=(13, -9, 16))),
                         (52, K(STOOL, hand_l=(12, 7, 13), hand_r=(14, -9, 18), spine=(.27, 0, .1))),
                         (66, K(STOOL, hand_l=(4, 16, 29), hand_r=(4, -16, 29), elbow_l=(-4, 6, -8), elbow_r=(-4, -6, -8), spine=(.05, 0, 0), head=(-.15, 0))),
                         (78, K(STOOL, hand_l=(4, 16, 29), hand_r=(4, -16, 29), elbow_l=(-4, 6, -8), elbow_r=(-4, -6, -8), spine=(.05, 0, 0), head=(-.15, 0))),
                         (88, K(STOOL, LAP, hand_r=(10, -10, 20))), (96, K(STOOL, LAP))]),
        howmany=dict(keys=[(0, {}), (10, dict(hand_r=(14, -7, 12), elbow_r=(-7, -5, -2))),
                           (20, dict(hand_l=(14, 7, 12), hand_r=(14, -7, 12), elbow_l=(-7, 5, -2), elbow_r=(-7, -5, -2), head=(.1, 0))),
                           (30, dict(hand_l=(8, 14, 13), hand_r=(8, -14, 13), elbow_l=(-6, 3, -4), elbow_r=(-6, -3, -4), spine=(-.05, 0, 0), head=(-.1, 0))),
                           (39, {})]))),
    'inmater': dict(grip='glove', actions=dict(
        ataka=dict(keep_hands=True, keys=[(0, _GLOVE), (2.5, _CANNON), (4, _RECOIL), (6, _CANNON), (8, _CANNON)]),
        atakb=dict(keep_hands=True, keys=[(0, _GLOVE), (7, K(_GLOVE, hand_r=(0, -16, 14), spine=(0, 0, .35))),
                                          (11, K(_GLOVE, hand_r=(24, -5, 17), elbow_r=(-9, -4, -2), spine=(.15, 0, -.35), root=(3, 0, -1))),
                                          (15, K(_GLOVE, hand_r=(23, -5, 16), elbow_r=(-9, -4, -2), spine=(.12, 0, -.3), root=(3, 0, -1))), (23, _GLOVE)]),
        atakc=dict(keep_hands=True, keys=_six_shot_sweep()),
        hita=dict(keep_hands=True, keys=[(0, _GLOVE), (3, K(_GLOVE, spine=(-.25, .1, .2), head=(-.3, .2), hand_r=(6, -16, 28), hand_l=(4, 14, 24), root=(-2, 0, -1))),
                                         (7, K(_GLOVE, spine=(-.3, .12, .25), head=(-.35, .2), hand_r=(4, -17, 29), hand_l=(3, 15, 23), root=(-3, 0, -1.5))),
                                         (11, K(_GLOVE, spine=(-.08, 0, .05), hand_r=(10, -10, 18))), (14, _GLOVE)]))),
    'ragemaster': dict(grip='relaxed', actions=dict(   # punches land on clip frames 14 and 22
        atake=dict(keep_hands=True, keys=[(0, _RAGE), (9, K(_RAGE, hand_r=(-6, -20, 12), elbow_r=(-2, 2, 8), spine=(0, 0, .35))),
                                          (14, K(_RAGE, hand_r=(24, -9, 15), elbow_r=(-9, -3, -2), spine=(.15, 0, -.4), root=(2, 0, -1))),
                                          (17, K(_RAGE, hand_r=(8, -20, 8), hand_l=(-6, 20, 12), elbow_l=(-2, -2, 8), spine=(0, 0, -.3))),
                                          (22, K(_RAGE, hand_l=(24, 9, 15), elbow_l=(-9, 3, -2), hand_r=(4, -21, 6), spine=(.15, 0, .4), root=(2, 0, -1))),
                                          (29, _RAGE)]),
        hita=dict(keep_hands=True, keys=[(0, _RAGE), (5, K(_RAGE, hand_l=(12, 12, 26), hand_r=(12, -12, 26), elbow_l=(-4, 8, -8), elbow_r=(-4, -8, -8), spine=(-.2, 0, .1), root=(-2, 0, 0))),
                                         (10, K(_RAGE, hand_l=(11, 13, 25), hand_r=(12, -11, 27), elbow_l=(-4, 8, -8), elbow_r=(-4, -8, -8), spine=(-.25, .05, -.1), root=(-3, 0, -1))),
                                         (14, K(_RAGE, spine=(-.08, 0, 0))), (19, _RAGE)]))),
    'sludgeminion': dict(grip='relaxed', actions=dict(   # left glob, then right
        ataka=dict(keep_hands=True, keys=[(0, _SLUDGE), (5, K(_SLUDGE, hand_l=(9, 23, -2), spine=(0, 0, -.1))), (8, K(_SLUDGE, hand_l=(2, 23.5, -3), spine=(-.06, -.04, -.1))),
                                          (13, _SLUDGE), (16, K(_SLUDGE, hand_r=(9, -23, -2), spine=(0, 0, .1))), (19, K(_SLUDGE, hand_r=(2, -23.5, -3), spine=(-.06, .04, .1))), (25, _SLUDGE)]),
        atakb=dict(keep_hands=True, keys=[(0, _SLUDGE), (3, K(_SLUDGE, hand_l=(9, 23, -2), hand_r=(9, -23, -2))),
                                          (5, K(_SLUDGE, hand_l=(2, 23.5, -3), hand_r=(2, -23.5, -3), spine=(-.08, 0, 0))), (12, _SLUDGE)]),
        hita=dict(keep_hands=True, keys=[(0, _SLUDGE), (4, K(_SLUDGE, hand_l=(20, 20, 29), hand_r=(20, -20, 29), elbow_l=(-12, -1, -6), elbow_r=(-12, 1, -6), spine=(-.25, 0, .1), head=(-.3, 0), root=(-2, 0, 0))),
                                         (9, K(_SLUDGE, hand_l=(19, 21, 28), hand_r=(21, -19, 30), elbow_l=(-12, -1, -6), elbow_r=(-12, 1, -6), spine=(-.28, .05, -.1), head=(-.3, 0), root=(-3, 0, -1))),
                                         (14, K(_SLUDGE, spine=(-.06, 0, 0))), (18, _SLUDGE)]))),
}


def author(model, metadata, slug):
    """Replace `slug`'s authored sequences in `model` in place; returns their names.

    Raises when a solved frame leaves an anatomical joint range. A rig whose packaged hands
    predate the shared wrist solver keeps them (`keep_hands`); only those joints are exempt."""
    spec = ENEMIES[slug]
    body = Body(model)
    sequences = {s['animation_name']: s for s in metadata['sequences']['frame_data']}
    for name, action in spec['actions'].items():
        s = sequences[name]
        span = slice(s['first'], s['last']+1)
        original = model.frames[span].copy()
        normalized = original.copy()
        normalized[..., :3] /= body.scale
        normalized[:, 0, :3] = (original[:, 0, :3]-body.offset)/body.scale
        model.frames[span] = body.world(perform(body, action, s['last']-s['first']+1, spec['grip'], normalized))
        bad = joint_violations(model, model.frames[span])
        if action.get('keep_hands'):
            bad = {k: v for k, v in bad.items() if not k.startswith('hand_')}
        if bad: raise ValueError(f'{slug} {name}: joints outside their ranges {bad}')
    return list(spec['actions'])


def sha(data): return hashlib.sha256(data).hexdigest()


def refresh(root, package, output):
    """Author the enemy actions into an admitted episode package."""
    from neural_package import classic_archive, validate_package
    ledger = json.loads((root/'pipeline.json').read_text())
    base = Path(ledger['assets'])/'packages/dk3-models.pk3'
    report = validate_package(package, base)
    with zipfile.ZipFile(package) as archive:
        files = {n: archive.read(n) for n in archive.namelist() if n != 'dk3/neural-assets.json'}
    files, proof = apply(root, ledger['episode'], files)
    report['enemy_actions'] = dict(proof, base_package_sha256=sha(package.read_bytes()))
    report['files'] = {n: sha(data) for n, data in files.items()}
    files['dk3/neural-assets.json'] = (json.dumps(report, sort_keys=True, indent=2)+'\n').encode()
    temporary = output.with_suffix('.partial')
    with classic_archive(temporary) as archive:
        for name, data in sorted(files.items()):
            entry = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0)); entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, data)
    validate_package(temporary, base)
    temporary.replace(output)
    output.with_suffix('.json').write_text(json.dumps(report, sort_keys=True, indent=2)+'\n')
    return report


def apply(root, episode, files):
    """Author every enemy's actions into package `files`; unmap authored sequences from shared clips."""
    proof, unmapped = {}, set()
    for slug in ENEMIES:
        target = f'models/neural/e{episode}_{slug}.iqm'
        if target not in files: continue
        source = json.loads((root/slug/'source.json').read_text())
        metadata, origin = source['metadata'], source['actor']['source']
        model = sk.read(files[target])
        before = sha(files[target])
        names = author(model, metadata, slug)
        files[target] = sk.write(model)
        sequences = {s['animation_name']: s for s in metadata['sequences']['frame_data']}
        unmapped |= {(origin, sequences[n]['first']) for n in names}
        proof[slug] = dict(input_sha256=before, output_sha256=sha(files[target]), sequences=names)
        print(f'{slug}: authored {", ".join(names)}', flush=True)
    # Authored sequences play their own frames instead of a shared procedural clip.
    lines = files.get('dk3/neural-animations.cfg', b'').decode().splitlines(keepends=True)
    files['dk3/neural-animations.cfg'] = ''.join(
        l for l in lines if not (len(l.split()) > 1 and (l.split()[0], int(l.split()[1])) in unmapped)).encode()
    return files, dict(tool_sha256=sha(Path(__file__).read_bytes()), models=proof)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path('zig-out/neural-monsters/episode1'))
    parser.add_argument('--package', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    refresh(args.root, args.package, args.output)
