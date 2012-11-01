#-*-python-*-
# Accepts full build logfile name as only argument.
# i.e.
# 'builder /nfs/acc/libs/Linux_i686_ifort/log/cesr_2011_0907_d_1.log'
#--------------------------------------------------------------
import sys
import os
from os.path import normpath, basename
import subprocess as sub
import socket

logfile = sys.argv[1]

file = open(logfile, 'r+')
inlines = file.readlines()
checkout_manifest = {}

print 'BUILDER SCRIPT RUNNING on host: ' + socket.gethostname()

#--------------------------------------------------------------
# Extract header values from log file to use as control inputs.
# Any header field found becomes a variable in the class
# 'invars' and can be accessed afterwards via the syntax
# 'invars.<var>'.
#--------------------------------------------------------------
class invars():
    pass

for line in inlines:
    boolean_map = {'True':True, 'False':False}
    if '[builder]' in line:
        break
    if 'repository' in line:
        repo = line.split()[1]
        checkout_manifest[repo] = line.split()[2:]
    else:
        var = line.split()[0]
        val = line.split()[1].strip()
        if val in boolean_map:
            val = boolean_map[val]
        setattr(invars, var, val)



# Close file and reopen in append mode.
file.close()
file = open(logfile, 'a', 1) # unbuffered, needed?

sys.stdout = file


hostname = socket.gethostname()
#p = sub.Popen('kinit -k -t ~/etc/cesrulib-keytab cesrulib/' + hostname,
#              bufsize=1,
#              shell=True,
#              stdout=sub.PIPE )
p = sub.Popen('kinit -k -t ~/etc/cesrulib-keytab cesrulib',
              bufsize=1,
              shell=True,
              stdout=sub.PIPE )
while True:
    nextline = p.stdout.readline()
    if nextline == '' and p.poll() != None:
        break
    sys.stdout.write(nextline)
    sys.stdout.flush()

#print 'Shell Environment Dump:'
#for envvar in os.environ:
#    print envvar + ' = ' + os.environ[envvar]


def manifest_to_build_list( manifest ):
    """Turn list of repository check-out paths into a
       simple list of buildable directories."""
    build_list = []
    for repo in manifest:
        for dir in checkout_manifest[repo]:
            full_dir = normpath(invars.full_release_dir) + '/' + basename(normpath(dir))
	    if os.path.exists(full_dir + '/CMakeLists.txt'):
		build_list.append(full_dir)
    return build_list


def link_to_packages( packages_name ):
    """Create a symbolic link in the release directory
       called 'packages' to the packages area named in
       the build setup."""
    full_packages_dir = invars.libs_basedir+'/'+invars.platform+'/'+packages_name
    if os.path.islink( full_packages_dir ):
        true_packages_name = '../'+os.readlink(full_packages_dir)
        sys.stdout.write( '\nREADLINK on packages_dir = ' + full_packages_dir +'\n')
    else:
        true_packages_name = '../'+packages_name
    sys.stdout.write('Setting link to packages: ' + true_packages_name+'\n')
    sys.stdout.flush()
    os.symlink( true_packages_name, invars.full_release_dir+'/packages' )


#def determine_build_order( ):
#"""Examine all source code to build and come up with
#   optimum order of directories to visit."""


def build_directory( dir, statlist, target ):
    print '\n\n\n-------- Building: ' + dir
    os.chdir( dir )
    use_32bit = ' '
    if 'lnx209' in hostname:
        use_32bit = ' ACC_FORCE_32_BIT=Y; '



    # Legacy build system
    #---------------------
    #build_command = 'ACCLIB='+invars.build_name+use_32bit + \
    #                'UTIL_DIR_REQUEST='+invars.util_dir + \
    #                '; source ' + invars.util_dir + \
    #                '/acc_vars.sh; ifort -v; printenv | grep ACC; echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"; gmake ' + \
    #                target + ' PRECISION="_DBL" DO_EXTRA_MAKES=Y USE_PGPLOT=Y'




    # New build system
    #---------------------
    make_command = 'mk'
    if target == 'debug':
        make_command = 'mkd'
    build_command = 'ACCLIB='+invars.build_name + \
                    ' UTIL_DIR_REQUEST='+invars.util_dir + \
                    '; source ' + invars.util_dir + '/acc_vars.sh;' + \
                    ' export ACC_BUILD_EXES=Y; export ACC_ENABLE_SHARED=Y; ' + make_command
    print build_command



    
    p = sub.Popen(build_command,
                  bufsize=1,
                  shell=True,
                  stdout=sub.PIPE,
                  stderr=sub.STDOUT )
    while True:
        nextline = p.stdout.readline()
        if nextline == '' and p.poll() != None:
            print 'RETURN CODE ===> [' + str(p.returncode) + ']'
            statlist.append( [dir, p.returncode] )
            break
        sys.stdout.write(nextline)
        sys.stdout.flush()


def build_pkg_directory( dir, statlist, target ) :
    print 'Build pkg directory here...'

#---------------------------


        
link_to_packages( invars.packages_name )

blist = manifest_to_build_list( checkout_manifest )

targets = ['production', 'debug']

buildpass_summaries = {}

for buildpass, target in enumerate(targets):
    print '\n\n-----------------------------------'
    print target + ' pass  ('+ str(buildpass+1) +' of ' + str(len(targets)) + ')'
    print '-----------------------------------'
    summary = []
    for dir in blist:
        build_directory( dir, summary, target )
    buildpass_summaries[target] = summary

    print '\n'
    print target + ' build pass status summary:'
    for entry in summary:
        print str(entry[0]) + '  :  ' + str(entry[1])

    sys.stdout.flush()


# Create a condensed pass summary giving success/failure
# info for each build pass that took place.
print 'Condensed pass summary:'
all_OK = {}
for buildpass, target in enumerate(targets):
    all_OK[target] = True
    for entry in buildpass_summaries[target]:
        if entry[1] != 0:
            all_OK[target] = False
    if all_OK[target]:
        print target + ' : OK'
        set_nightly_link = True
    else:
        print target + ' : ERROR'
        mail_command = 'echo  "ERROR IN RELEASE" | /bin/mail -s "Nightly build error" cesrulib@cornell.edu' 
        p = sub.call(mail_command,
                      bufsize=1,
                      shell=True)




# If all passes succeeded, AND a nighly build was requested
# from the build_supervisor, then rotate the nightly link.
if invars.nightly:
    rotate_nightly = True
    for entry in all_OK:
        if not all_OK[entry]:
            rotate_nightly = False
            break

    if rotate_nightly:
        print 'Rotating nightly link...'
        print invars.libs_basedir+'/'+invars.platform+'/nightly'
        if os.path.lexists(invars.libs_basedir+'/'+invars.platform+'/nightly'):
            print 'Nightly link exists.'
            os.remove(invars.libs_basedir+'/'+invars.platform+'/nightly')
        os.symlink( invars.build_name, invars.libs_basedir+'/'+invars.platform+'/nightly' )
