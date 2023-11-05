import os


def configure(self):
    opts = self.options

    print('Running Conda Configuration')
    mpi_variant = False
    if os.getenv('ENABLE_MPI', "0") == "1":
        mpi_variant = True
        opts.parallel = 1
    conda_prefix = os.getenv('PREFIX')
    recipe_dir = os.getenv('RECIPE_DIR')

    self.env.WAFBUILD_ENV = [recipe_dir + '/config/dummy.env', conda_prefix]

    self.env.append_value('LIBPATH', [
        conda_prefix + '/lib',
    ])

    self.env.append_value('INCLUDES', [
        conda_prefix + "/include",
    ])

    if mpi_variant is False:
        self.env.append_value('INCLUDES', [
            conda_prefix + '/include_seq',
        ])
    else:
        opts.parallel = 1
        opts.enable_petsc = True
        self.env.append_value('LIBPATH', [
            conda_prefix + '/lib/petsc4py/lib',
        ])
        self.env.append_value('INCLUDES', [
            conda_prefix + '/lib/petsc4py/include',
        ])

    # to fail if not found
    opts.enable_hdf5 = True
    opts.enable_med = True
    opts.enable_metis = True
    opts.enable_mumps = True
    opts.enable_scotch = True
    opts.enable_mfront = True
    opts.enable_homard = True
    opts.with_py_medcoupling = True
    print('Conda Configuration Complete')
