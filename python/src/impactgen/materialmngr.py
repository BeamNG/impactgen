import json
import logging as log
import os
import os.path
import random
from pathlib import Path

import cv2
import numpy as np
import PIL
from wand.image import Image

IMG_TYPES = {'.jpg', '.jpeg', '.png', '.bmp', '.gif'}

BF = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=True)


def get_output_path(bng_home):
    output = os.path.join('levels', 'smallgrid', 'art', 'impactgen')
    output = os.path.join(bng_home, output)
    return output


def get_impactgen_materials(bng_home):
    mats = get_output_path(bng_home)
    mats = os.path.join(mats, 'main.materials.json')
    with open(mats) as infile:
        mats = json.loads(infile.read())
    return set(mats.keys())


def get_mat_name(path):
    _, base = os.path.split(path)
    base, _ = os.path.splitext(base)
    return 'impactgen_' + base


def build_feature_cache(path):
    cache = {}
    orb = cv2.ORB_create()

    for fil in os.listdir(path):
        _, ext = os.path.splitext(fil)
        if ext.lower() == '.dds':
            fil = os.path.join(path, fil)
            img = PIL.Image.open(fil).convert('RGB')
            img = np.array(img)
            img = img[:, :, ::-1].copy()
            _, desc = orb.detectAndCompute(img, None)
            name = get_mat_name(fil)
            cache[name] = desc
            log.info('Cached features for: %s', fil)

    return cache


def mat_similarity(cache, mat_a, mat_b, threshold=70):
    desc_a = cache[mat_a]
    desc_b = cache[mat_b]

    matches = BF.match(desc_a, desc_b)
    similar_regions = [i for i in matches if i.distance < threshold]

    if len(matches) == 0:
        log.debug('No matches in check between mats %s & %s', mat_a, mat_b)
        return 0

    return len(similar_regions) / len(matches)


def compute_sim_matrix(bng_home, threshold=70):
    path = get_output_path(bng_home)
    mats = sorted(list(get_impactgen_materials(bng_home)))
    count = len(mats)
    cache = build_feature_cache(path)
    mtx = np.full((count, count), -1, dtype=np.float32)
    for idx_a, mat_a in enumerate(mats):
        for idx_b, mat_b in enumerate(mats):
            if mtx[idx_a][idx_b] < 0:
                sim = mat_similarity(cache, mat_a, mat_b, threshold=threshold)
                mtx[idx_a][idx_b] = sim
                mtx[idx_b][idx_a] = sim
                log.debug('Similarity: %s & %s: %s', mat_a, mat_b, sim)

    output = os.path.join(path, 'sim.npy')
    np.save(output, mtx)


def load_sim_matrix(bng_home):
    path = Path(get_output_path(bng_home))
    inpath = path / 'sim.npy'
    if not inpath.exists():
        raise FileNotFoundError('Similarity matrix not found. Please run the `convert-materials` and `compute-similarity` commands according to the README first.')

    return np.load(inpath)


def pick_materials(mats, mtx, poolsize=2, similarity=0.5):
    log.info('Trying to find %s materials.', poolsize)
    mat_idx = {}
    for idx, mat in enumerate(mats):
        mat_idx[mat] = idx

    selected = set()
    for _ in range(16):
        left = list(mats)
        while len(selected) < poolsize:
            if len(left) == 0:
                log.info('Ran out of candidates. Restarting search.')
                selected = set()
                break

            candidate = left.pop(random.randint(0, len(left) - 1))
            candidate_idx = mat_idx[candidate]
            match = True
            for member in selected:
                member_idx = mat_idx[member]
                if mtx[member_idx][candidate_idx] > similarity:
                    match = False
                    break

            if match:
                selected.add(candidate)

    if selected:
        return selected
    return None


def closest_pow2(n):
    cur = 2
    while cur < n:
        cur *= 2
    return cur


def convert_image(path, output):
    log.info('Converting: %s -> %s', path, output)
    with Image(filename=path) as img:
        size = max(*img.size)
        size = closest_pow2(size)
        img.resize(size, size, filter='lanczossharp')
        img.save(filename=output)
    log.info('Converted: %s -> %s', path, output)


def convert_images(path, output):
    for fil in os.listdir(path):
        base, ext = os.path.splitext(fil)
        if ext.lower() in IMG_TYPES:
            fil = os.path.join(path, fil)
            out = os.path.join(output, base + '.dds')
            if not os.path.exists(out):
                convert_image(fil, out)


def get_material_dict(bng_home, path):
    name = get_mat_name(path)
    relpath = os.path.relpath(path, bng_home)
    relpath = relpath.replace('\\', '/')

    ret = {}

    ret['name'] = name
    ret['mapTo'] = name
    ret['class'] = 'Material'
    ret['Stages'] = [
        {
            'colorMap': relpath,
        }, {}, {}, {},
    ]
    ret['materialTag0'] = 'impactgen'
    ret['materialTag1'] = 'impactgen'
    ret['materialTag2'] = 'impactgen'

    return ret


def create_materials(bng_home, path):
    output = get_output_path(bng_home)

    materials = {}
    for fil in os.listdir(path):
        base, ext = os.path.splitext(fil)
        if ext.lower() == '.dds':
            fil = os.path.join(path, fil)
            mat = get_material_dict(bng_home, fil)
            name = get_mat_name(fil)
            materials[name] = mat
            log.info('Entered entry for material: %s', base)

    output = os.path.join(output, 'main.materials.json')
    with open(output, 'w') as outfile:
        outfile.write(json.dumps(materials, indent=4, sort_keys=True))

    return materials.keys()


def convert_and_create(bng_home, path):
    output = get_output_path(bng_home)
    if not os.path.exists(output):
        os.makedirs(output)

    convert_images(path, output)
    create_materials(bng_home, output)
