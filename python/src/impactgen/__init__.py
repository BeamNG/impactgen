# SPDX-License-Identifier: MIT

import os

from . import materialmngr
from .impactgen import ImpactGenerator


def read(fil):
    fil = os.path.join(os.path.dirname(__file__), fil)
    with open(fil, encoding='utf-8') as f:
        return f.read()


__version__ = read('version.txt')
