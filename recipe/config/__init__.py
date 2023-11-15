# coding=utf-8
# --------------------------------------------------------------------
# Copyright (C) 1991 - 2023 - EDF R&D - www.code-aster.org
# This file is part of code_aster.
#
# code_aster is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# code_aster is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with code_aster.  If not, see <http://www.gnu.org/licenses/>.
# --------------------------------------------------------------------

# person_in_charge: mathieu.courtois at edf.fr

"""
This is the main entry point for the users.

The :py:func:`~code_aster.Commands.debut.init` function initializes the
memory manager. It must be called before any :py:mod:`code_aster.Objects`
creation. It can be simply called from this toplevel module with:

.. code-block:: python

    >>> import code_aster
    >>> code_aster.init()

The same job is done by :py:class:`~code_aster.Commands.debut.DEBUT`.

For convenience the objects are direcly available here:

.. code-block:: python

    >>> import code_aster
    >>> mymesh = code_aster.Mesh()


Here is the diagram of the package organization:

.. image:: ../../img/diagr_code_aster.png
   :align: center

"""

# image generated with:
#   diagr_import --pkg --grp -g doc/img/diagr_code_aster.png \
#       code_aster/**/*.py

# discourage import *
__all__ = []

try:
    # import libaster to call initAsterModules
    import aster
    import aster_core
    import aster_fonctions
    import med_aster

    # libaster must be imported after embedded submodules
    import libaster

    from .Algorithms import ConstitutiveLaw, IntegrationAlgorithm, StrainType, TangentMatrixType
    from .Commands.debut import init
    from .Commands.fin import FIN as close
    from .Objects import *
    from .ObjectsExt import DataStructure
    from .Supervis import (
        AsterError,
        ContactError,
        ConvergenceError,
        IntegrationError,
        SolverError,
        TimeLimitError,
        saveObjects,
    )
    from .Utilities import TestCase, MPI


except ImportError as e:
    print(f'Module import failed due to {e}')
    pass
