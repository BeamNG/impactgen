import logging as log
import os
import os.path
import shutil
import sys
from itertools import product

import click
import numpy as np
import yaml

from . import ImpactGenerator, materialmngr

LOG = 'impactgen.log'
CFG = 'impactgen.yml'


def generate_default_config():
    cfg = {}

    cfg['imageWidth'] = 1920
    cfg['imageHeight'] = 1080

    cfg['colorFormat'] = 'image_%02d.png'
    cfg['annotFormat'] = 'annotation_%02d.png'

    cfg['cameraRadius'] = 7
    cfg['cameraHeight'] = 1.25
    cfg['fov'] = 30

    cfg['times'] = [0.075, 0.25, 0.47]
    cfg['clouds'] = [0, 1]
    cfg['fogs'] = [0, 0.02, 0.05]

    colors = list(
        product(
            [float(f) for f in np.linspace(0.01, 1.0, 4)],
            [float(f) for f in np.linspace(0.01, 1.0, 4)],
            [float(f) for f in np.linspace(0.01, 1.0, 4)],
            [float(f) for f in np.linspace(0.25, 1.0, 4)],
        )
    )
    colors = [list(l) for l in colors]
    cfg['colors'] = colors

    return cfg


def get_config(path):
    if not os.path.exists(path):
        cfg = generate_default_config()
        with open(path, 'w') as outfile:
            outfile.write(yaml.dump(cfg))
        log.info('No existing config found; wrote default cfg to: %s', path)

    with open(path, 'r') as infile:
        return yaml.load(infile, Loader=yaml.SafeLoader)


def log_exception(extype, value, trace):
    log.exception('Uncaught exception:', exc_info=(extype, value, trace))


def setup_logging(log_file=None):
    handlers = []
    if log_file:
        if os.path.exists(log_file):
            backup = '{}.1'.format(log_file)
            shutil.move(log_file, backup)
        file_handler = log.FileHandler(log_file, 'w', 'utf-8')
        handlers.append(file_handler)

    term_handler = log.StreamHandler()
    handlers.append(term_handler)
    fmt = '%(asctime)s %(levelname)-8s %(message)s'
    log.basicConfig(handlers=handlers, format=fmt, level=log.INFO)

    sys.excepthook = log_exception

    log.info('Started impactgen logging.')


@click.group()
@click.option('--log-file', type=click.Path(dir_okay=False), default=LOG)
@click.pass_context
def cli(ctx=None, log_file=None, **opts):
    setup_logging(log_file=log_file)


@cli.command()
@click.argument('bng-home', type=click.Path(file_okay=False, exists=True))
@click.argument('output', type=click.Path(file_okay=False))
@click.option('--config', type=click.Path(dir_okay=False), default=CFG)
@click.option('--poolsize', default=2)
@click.option('--similarity', default=0.7)
@click.option('--random-select', default=False, is_flag=True)
@click.option('--smallgrid', is_flag=True)
@click.option('--single', is_flag=True)
@click.pass_context
def generate(ctx, bng_home, output, config,
             poolsize, similarity, random_select, smallgrid, single):
    cfg = get_config(config)
    if not os.path.exists(output):
        os.makedirs(output)

    mtx = None
    if smallgrid:
        mtx = materialmngr.load_sim_matrix(bng_home)

    gen = ImpactGenerator(bng_home, output, cfg,
                          smallgrid=smallgrid, sim_mtx=mtx, poolsize=poolsize,
                          similarity=similarity, random_select=random_select,
                          single=single)
    gen.run()


@cli.command()
@click.argument('bng-home', type=click.Path(file_okay=False, exists=True))
@click.argument('inpath', type=click.Path(file_okay=False, exists=True))
@click.pass_context
def convert_materials(ctx, bng_home, inpath):
    materialmngr.convert_and_create(bng_home, inpath)


@cli.command()
@click.argument('bng-home', type=click.Path(file_okay=False, exists=True))
@click.option('--threshold', type=float, default=70)
@click.pass_context
def compute_similarity(ctx, bng_home, threshold):
    materialmngr.compute_sim_matrix(bng_home, threshold=threshold)


if __name__ == '__main__':
    cli(obj={})
