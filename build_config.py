#-*-python-*-
#
# build_supervisor configuration file
#-----------------------------------------------------

intel_offline_release_build_request = [
    'Linux_x86_64_intel-offline'
    ]

intel_online_release_build_request = [
    'Linux_x86_64_intel-online'
    ]

intel_packages_build_request = [
    'packages_intel'
    ]

intel_dist_build_request = [
    'Linux_i686_intel'
    ]

intel_local_release_build_request = [
    'Linux_x86_64_intel-local'
    ]

intel_local_packages_build_request = [
    'packages_intel-local'
    ]

gfortran_offline_release_build_request = [
    'Linux_x86_64_gfortran-offline' 
    ]

gfortran_online_release_build_request = [
    'Linux_x86_64_gfortran-online'
    ]

gfortran_packages_build_request = [
    'packages_gfortran'
    ]

gfortran_dist_build_request = [
    'Linux_i686_gfortran'
    ]

gfortran_local_release_build_request = [
    'Linux_x86_64_gfortran-local'
    ]

gfortran_local_packages_build_request = [
    'packages_gfortran-local'
    ]


#-----------------------------------------------------
# Collect all build requests by type into a master
# dictionary.
#-----------------------------------------------------
build_requests = {}
build_requests['release_intel'] = intel_offline_release_build_request
build_requests['online-release_intel'] = intel_online_release_build_request
build_requests['packages_intel'] = intel_packages_build_request
build_requests['dist_intel'] = intel_dist_build_request
build_requests['local-release_intel'] = intel_local_release_build_request
build_requests['local-packages_intel'] = intel_local_packages_build_request

build_requests['release_gfortran'] = gfortran_offline_release_build_request
build_requests['online-release_gfortran'] = gfortran_online_release_build_request
build_requests['packages_gfortran'] = gfortran_packages_build_request
build_requests['dist_gfortran'] = gfortran_dist_build_request
build_requests['local-release_gfortran'] = gfortran_local_release_build_request
build_requests['local-packages_gfortran'] = gfortran_local_packages_build_request

#-----------------------------------------------------
#-----------------------------------------------------
offline_base_dir = '/nfs/acc/libs'
offline_util_dir = offline_base_dir + '/util'
offline_host = 'acc101.lns.cornell.edu'

online_base_dir = '/nfs/cesr/online/lib'
online_util_dir = online_base_dir + '/util'
online_host = 'cesr109.lns.cornell.edu'

local_base_dir = '/mnt/acc/libs'
local_util_dir = local_base_dir + '/util'
local_host = 'lnx7179.lns.cornell.edu'

makefile_dir = '/home/cesrulib/bin/Gmake'


#-----------------------------------------------------
#-----------------------------------------------------

local_build_list = [
                '/trunk/util',
                '/trunk/build_system',
                '/trunk/src/include',
                '/trunk/src/c_utils',
                '/trunk/src/recipes_f-90_LEPP',
                '/trunk/src/sim_utils',
                '/trunk/src/bmad',
                '/CESR/CESR_libs/cesr_utils',
                '/CESR/CESR_libs/genplt',
                '/CESR/CESR_libs/mpmnet',
                '/CESR/CESR_libs/timing',
                '/CESR/CESR_instr/instr_utils',
                '/Comm/Comm_libs/cbi_net',
                '/CESR/CESR_progs/cbpmfio',
                '/CESR/CESR_instr/BeamInstSupport',
                '/CESR/CESR_instr/CBPM-TSHARC',
                '/Comm/Comm_libs/rfnet',
                '/CESR/CESR_libs/mpm_utils',
                '/CESR/CESR_instr/CesrBPM',                
                '/CESR/CESR_instr/nonlin_bpm',
                '/CESR/CESR_libs/rf',
                '/CESR/CESR_progs/diagnose',
                '/CESR/CESR_services/automail',
                '/CESR/CESR_services/averager',
                '/CESR/CESR_services/condx',
                '/CESR/CESR_services/displays',
                '/CESR/CESR_services/dt80_logger',
                '/CESR/CESR_services/err_mon',
                '/CESR/CESR_services/event_wat',
                '/CESR/CESR_services/fastlog',
                '/CESR/CESR_services/gpib_serv',
                '/CESR/CESR_services/htcmon',
                '/CESR/CESR_services/intloc',
                '/CESR/CESR_services/logit',
                '/CESR/CESR_services/onoff',
                '/CESR/CESR_services/per_mag',
                '/CESR/CESR_services/rfintl',
                '/CESR/CESR_services/sentry',
                '/CESR/CESR_services/show',
                '/CESR/CESR_services/synring',
                '/CESR/CESR_services/vacmon',
                '/CESR/CESR_services/xscope',
                '/CESR/CESR_progs/magstat',
                '/CESR/CESR_services/simcon',
                '/trunk/src/tao',
                '/trunk/src/bmadz',
                '/trunk/src/bsim',
                '/CESR/CESR_progs/synchv',
                '/CESR/CESR_progs/cesrv',
                '/trunk/src/regression_tests',
                '/trunk/src/bsim_cesr',
                '/CESR/CESR_progs/BPM_tbt_gain',
                '/CESR/CESR_progs/cesr_programs',
                '/trunk/src/util_programs',
                '/CESR/CESR_services/CBIC',
                '/trunk/src/examples',
                '/CESR/CESR_progs/xbus_book',
                '/CESR/CESR_progs/CBSM/xBSM/XbsmAnalysis',
                '/CESR/CESR_progs/newin',
                '/CESR/CESR_progs/DB_utils',
                '/CESR/CESR_progs/chfeed',
                '/CESR/CESR_progs/gdl',
                '/CESR/CESR_progs/hard',
                '/CESR/CESR_progs/lat_utils',
                '/CESR/CESR_progs/magnet',
                '/CESR/CESR_progs/save',
                '/CESR/CESR_progs/vac',
                '/CESR/CESR_progs/crf',
                '/CESR/CESR_progs/srf',
                '/CESR/CESR_services/console',
                '/CESR/CESR_services/winj',
                '/CESR/CESR_services/daily',
                '/CESR/CESR_services/xetec',
                '/CESR/CESR_services/webrep',
                '/CESR/CESR_services/srf232',
                '/CESR/CESR_services/bcmserv',
                '/CESR/CESR_services/moore232',
                '/CESR/CESR_services/yoko232',
                '/CESR/CESR_services/scwiggler',
                '/CESR/CESR_services/mooreenet',
                '/CESR/CESR_services/lt107_mon',
                '/CESR/CESR_services/delphi',
                '/CESR/CESR_services/runlog',
                '/CESR/CESR_services/disp_tunes',
                '/CESR/CESR_services/gen_log',
                '/CESR/CESR_progs/auto_char',
                '/CESR/CESR_progs/beam_dose',
                '/CESR/CESR_progs/beam_optimizer',
                '/CESR/CESR_progs/cbpm_mon',
                '/CESR/CESR_progs/fbph',
                '/CESR/CESR_progs/gdl_inp',
                '/CESR/CESR_progs/gifo',
                '/CESR/CESR_progs/goo',
                '/CESR/CESR_progs/grofix',
                '/CESR/CESR_progs/inj',
                '/CESR/CESR_progs/ldinit',
                '/CESR/CESR_progs/linac',
                '/CESR/CESR_progs/nmr_test',
                '/CESR/CESR_progs/node_set',
                '/CESR/CESR_progs/scopeget',
                '/CESR/CESR_progs/scwigcon',
                '/CESR/CESR_progs/timing_test',
                '/CESR/CESR_progs/tools',
                '/CESR/CESR_progs/tune',
                '/CESR/CESR_progs/univ_tune_tracker',
]

packages_build_list = [
                '/trunk/packages/activemq-cpp-3.7.0',
                '/trunk/packages/cfortran',
                '/trunk/packages/forest',
                '/trunk/packages/num_recipes/recipes_c-ansi',
                '/trunk/packages/xsif',
                '/trunk/packages/PGPLOT',
                '/trunk/packages/plplot',
                '/trunk/packages/gsl',
                '/trunk/packages/fgsl',
                '/trunk/packages/lapack',
                '/trunk/packages/fftw',
                '/trunk/packages/root',
                '/trunk/packages/xraylib',
]

#-----------------------------------------------------
#-----------------------------------------------------
repository_addresses = {
    'ACC-LEPP'        : 'https://accserv.lepp.cornell.edu/svn',
    'ACC-LEPP-local'  : '/mnt/svn',
    'UAP-Sourceforge' : 'https://accelerator-ml.svn.sourceforge.net/svnroot/accelerator-ml/uap'
    }


#-----------------------------------------------------
#-----------------------------------------------------
build_specs = {
    'Linux_x86_64_intel-offline' : {
        'type'         : 'release',
        'platform'     : 'Linux_x86_64_intel',
        'basedir'      : offline_base_dir,
        'util_dir'     : offline_util_dir,
        'domain'       : 'OFFLINE',
        'host'         : offline_host,
        'repositories' : {
            'ACC-LEPP' : local_build_list
        }
    },
    'Linux_x86_64_intel-online' : {
        'type'         : 'release',
        'platform'     : 'Linux_x86_64_intel',
        'basedir'      : online_base_dir,
        'util_dir'     : online_util_dir,
        'domain'       : 'ONLINE',
        'host'         : online_host,
        'repositories' : {
            'ACC-LEPP' : local_build_list
        }
    },
    'Linux_x86_64_intel-local' : {
        'type'         : 'release',
        'platform'     : 'Linux_x86_64_intel',
        'basedir'      : local_base_dir,
        'util_dir'     : local_util_dir,
        'domain'       : 'LOCAL',
        'host'         : local_host,
        'repositories' : {
            'ACC-LEPP' : local_build_list
        }
    },
    'Linux_x86_64_gfortran-offline' : {
        'type'         : 'release',
        'platform'     : 'Linux_x86_64_gfortran',
        'basedir'      : offline_base_dir,
        'util_dir'     : offline_util_dir,
        'domain'       : 'OFFLINE',
        'host'         : offline_host,
        'repositories' : {
            'ACC-LEPP' : local_build_list
        }
    },
    'Linux_x86_64_gfortran-online' : {
        'type'         : 'release',
        'platform'     : 'Linux_x86_64_gfortran',
        'basedir'      : online_base_dir,
        'util_dir'     : online_util_dir,
        'domain'       : 'ONLINE',
        'host'         : online_host,
        'repositories' : {
            'ACC-LEPP' : local_build_list
        }
    },
    'Linux_x86_64_gfortran-local' : {
        'type'         : 'release',
        'platform'     : 'Linux_x86_64_gfortran',
        'basedir'      : local_base_dir,
        'util_dir'     : local_util_dir,
        'domain'       : 'LOCAL',
        'host'         : local_host,
        'repositories' : {
            'ACC-LEPP' : local_build_list
        }
    },
    'packages_intel'   : {
        'type'         : 'packages',
        'platform'     : 'Linux_x86_64_intel',
        'basedir'      : offline_base_dir,
        'util_dir'     : offline_util_dir,
        'domain'       : 'OFFLINE',
        'host'         : offline_host,
        'repositories' : {
            'ACC-LEPP' : packages_build_list
        }
    },
    'packages_intel-local'   : {
        'type'         : 'packages',
        'platform'     : 'Linux_x86_64_intel',
        'basedir'      : local_base_dir,
        'util_dir'     : local_util_dir,
        'domain'       : 'LOCAL',
        'host'         : local_host,
        'repositories' : {
            'ACC-LEPP' : packages_build_list
        }
    },    
    'packages_gfortran' : {
        'type'         : 'packages',
        'platform'     : 'Linux_x86_64_gfortran',
        'basedir'      : offline_base_dir,
        'util_dir'     : offline_util_dir,
        'domain'       : 'OFFLINE',
        'host'         : offline_host,
        'repositories' : {
            'ACC-LEPP' : packages_build_list
        }
    },
    'packages_gfortran-local' : {
        'type'         : 'packages',
        'platform'     : 'Linux_x86_64_gfortran',
        'basedir'      : local_base_dir,
        'util_dir'     : local_util_dir,
        'domain'       : 'LOCAL',
        'host'         : local_host,
        'repositories' : {
            'ACC-LEPP' : packages_build_list
        }
    }    
}
