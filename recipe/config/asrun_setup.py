# -*- coding: utf-8 -*-

"""Setup script for astk+asrun

In most of cases, just type:
    python setup.py install --prefix=/opt/aster [--root=/destination_dir]


You should be able to uninstall any astk version using:
    python setup.py uninstall --prefix=/opt/aster

'--root=alternative_root' option allows you to configure the files
using 'prefix' but to copy them elsewhere (for instance to prepare packages).

Use '--help' flag for global options.
"""
# export DISTUTILS_DBG=1 to log debug information
# export DEPRECATION=yes to add ASTK deprecation warnings.


import sys
if sys.hexversion < 0x020400F0:
    print("This script requires Python 2.4 or higher, sorry !")
    sys.exit(4)

import os
import os.path as osp
import re
import glob
import pprint
from distutils.debug import DEBUG
from distutils.core  import setup
from distutils       import log
from distutils.command.install import install as _install
from distutils.command.install_data import install_data as _install_data

import __pkginfo__
import configuration
from configuration.util import prefix2etc, tick


def build_data_files(dest, src):
    """To add all files of 'src' into 'dest'."""
    data_files = []
    for base, dirs, files in os.walk(src):
        l_files = [os.path.join(base, f) for f in files]
        data_files.append( (base.replace(src, dest), l_files) )
    return data_files


class install(_install):
    user_options = _install.user_options + [
                    ('with-shortcuts', None,
                            "install 'show', 'get'... shortcuts in the 'bin' directory"),
                    ('without-shortcuts', None,
                            "do not install 'show', 'get'... shortcuts in the 'bin' directory"),
                   ]
    boolean_options = _install.boolean_options + [
                       'with-shortcuts',
                       'without-shortcuts'
                      ]

    def initialize_options(self):
        _install.initialize_options(self)
        self.with_shortcuts = 0
        self.without_shortcuts = 0

    def finalize_options(self):
        _install.finalize_options(self)
        configuration.set_options("asrun_shortcuts", "yes")
        if self.without_shortcuts:
                configuration.set_options("asrun_shortcuts", "no")

class install_data(_install_data):
    """Just to force '--force' option."""
    def finalize_options(self):
        _install_data.finalize_options(self)
        self.force = 1


def start_setup(prefix):
    tick()
    confdir = osp.join(prefix2etc(prefix), 'codeaster')
    data_files = []
    data_files.extend(build_data_files(confdir, 'ASTK_SERV/etc'))
    data_files.extend(build_data_files(osp.join(confdir, "astkrc"), 'ASTK_CLIENT/etc/astkrc'))
    data_files.extend(build_data_files('lib/astk', 'ASTK_CLIENT/lib'))
    data_files.extend(build_data_files('share', 'ASTK_SERV/share'))
    data_files.extend(build_data_files('share/codeaster/asrun/unittest', 'ASTK_SERV/unittest'))
    if sys.hexversion >= 0x020500F0:
        data_files.extend(build_data_files('share/locale', 'ASTK_SERV/i18n/locale'))

    tick()
    scripts = glob.glob('ASTK_CLIENT/bin/*') + glob.glob('ASTK_SERV/bin/*')

    # DeprecationWarning for backward compatibility < 1.8.0 (programs/links are in post_install)
    data_files.extend(build_data_files('.as_run_configuration/astk_serv_lib', 'configuration/ASTK/ASTK_SERV/lib'))
    data_files.append(('.as_run_configuration',
        ['configuration/deprecated_outils.sh', 'configuration/deprecated_client.sh', 'configuration/deprecated_server.sh']))

    tick()
    dist = setup(
        name       = "astk",
        version      = __pkginfo__.version,
        description  = __pkginfo__.short_desc,
        author       = __pkginfo__.author,
        author_email = __pkginfo__.author_email,
        license      = __pkginfo__.license,
        url          = __pkginfo__.url,

        packages = [
            'asrun',
            'asrun.client',
            'asrun.common',
            'asrun.contrib',
            'asrun.core',
            'asrun.ctl',
            'asrun.dev',
            'asrun.plugins'
        ],
        package_dir = { '' : 'ASTK_SERV' },

        scripts = scripts,
        data_files = data_files,
        cmdclass = {
            'install' : install,
            'install_data' : install_data,
        },
        long_description = __pkginfo__.long_desc,

        #classifiers = []
    )
    tick()
    return dist


def command_in_args(cmd):
    args = [s for s in sys.argv[1:] if not s.startswith('-')]
    return cmd in args


def parse_options(opt):
    """Search for 'opt' option."""
    opt = re.sub('=$', '', opt).strip()
    args = [(i,s) for i,s in enumerate(sys.argv) if s == opt]
    #print 'search for short option', opt, '>>>', args
    if len(args) > 0:
        i, val = args.pop(0)
        if i+1 < len(sys.argv):
            return sys.argv[i + 1]
    if opt.startswith('--'):
        opt = opt + '='
        args = [(i,s) for i,s in enumerate(sys.argv) if s.startswith(opt)]
        #print 'search for long option', opt, '>>>', args
        if len(args) > 0:
            i, val = args.pop(0)
            value = re.sub(re.escape(opt), '', val)
            if not value.startswith('-'):
                return value
    return ''


def main():
    verbose = 1
    if DEBUG:
        verbose = 2
    log.set_verbosity(verbose)
    sdist     = command_in_args('sdist')
    if sdist:
        assert not os.path.exists('ASTK_SERV/unittest/Makefile.inc'), \
                "please run 'cd ASTK_SERV/unittest ; make distclean'"
    install   = command_in_args('install')
    uninstall = command_in_args('uninstall')
    previous_version = None
    backup_dir = None
    install_parameters = {}

    if uninstall:
        if not configuration.should_continue("Uninstallation will remove all files from the current astk installation"):
            log.info("aborted!")
            return

    # pre-install phase (also for build)
    prefix = ""
    if install or uninstall:
        prefix = parse_options('--prefix=')
        rootdir = parse_options('--root=')
        if not prefix:
            prefix = '/usr'
        configuration.set_dirs(rootdir, prefix)
        configuration.set_dry_run(sys.argv)
        configuration.set_options("deprecation", os.environ.get("DEPRECATION"))
        # check if a previous version is installed and get its number
        prev_exists = configuration.is_already_installed()
        if prev_exists:
            tick()
            log.info("---previous exists---")
            previous_version = configuration.get_installed_version()
            # remove (and backup) the previous version
            tick()
            backup_dir = configuration.remove_previous()
            tick()

    if install:
        tick()
        log.info("---install---")
        configuration.get_install_parameters()

    # uninstallation
    if uninstall:
        if backup_dir is None:
            log.info("uninstallation of astk cancelled!")
        else:
            tick()
            log.info("---uninstall---")
            configuration.remove_tree(backup_dir, empty_dirs=True)
            log.info("uninstallation of astk %s completed!", previous_version)
        return  # stop here!

    tick()
    log.info("---")
    dist = start_setup(prefix)
    # overwritten by setup
    log.set_verbosity(verbose)

    # post-install
    if install:
        tick()
        log.info("---")
        configuration.configure()
    tick()


if __name__ == '__main__':
    main()
