This is a collection of config and scripts which is used
to create an on-demand build server for rawwrite.

This build server was set up use donaited credits from AWS
and a free account with BuildKite. A special thank you to
these guys for helping out with an open source tool.

The cloudformation stack creates a windows instance and bootstraps it
by downloading and running a powershell script from an S3 bucket.

That script downloads & installs the required parts from the same bucket.

The required files can be sourced from the internet (use google)
* lazarus-1.6.2-fpc-3.0.0-win32.exe (sourceforge)
* lazarus-1.6.2-fpc-3.0.0-cross-x86_64-win64-win32.exe (sourceforge)
* Git-2.11.0-64-bit.exe (https://git-scm.com/download/win)
* nsis-3.01-setup.exe (sourceforge)
* ent.exe (http://www.fourmilab.ch/random/random.zip)

setup/go.sh sets up and runs the build agent from BuildKite.
I have a deploy key but there are many ways to set that up.

If you want to run your own build server you will need to create
your own bucket and update all the references to top3-deploy to
match your bucket name.

