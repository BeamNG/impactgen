# SPDX-License-Identifier: MIT

import setuptools
import os
import os.path


def read(fil):
    fil = os.path.join(os.path.dirname(__file__), fil)
    with open(fil, encoding='utf-8') as f:
        return f.read()


setuptools.setup(version=read('src/impactgen/version.txt'))
