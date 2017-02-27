#!/bin/bash

exec > ~/setup.log 2>&1
pwd
echo "bash based setup"

eval $(ssh-agent)
ssh-add setup/deploy

cd 
mkdir -p ~/.ssh
cat > ~/.ssh/known_hosts << END
github.com,192.30.253.112 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
END

git config --global user.email "jnewbigin@chrysocome.net"
git config --global user.name "John Newbigin"

# Check out a copy for development work
mkdir working
cd working
git clone git@github.com:jnewbigin/rawwrite.git
cd rawwrite

# And start the build agent for triggered builds
cd /c/buildkite
./buildkite-agent start

