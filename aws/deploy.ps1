# Stop windows defender to install faster
Set-MpPreference -DisableRealtimeMonitoring $true

Read-S3Object -BucketName top3-deploy -Key lazarus/lazarus-1.6.2-fpc-3.0.0-win32.exe -File c:\lazarus-1.6.2-fpc-3.0.0-win32.exe
Start-Process c:\lazarus-1.6.2-fpc-3.0.0-win32.exe /silent -NoNewWindow -Wait

Read-S3Object -BucketName top3-deploy -Key lazarus/lazarus-1.6.2-fpc-3.0.0-cross-x86_64-win64-win32.exe -File c:\lazarus-1.6.2-fpc-3.0.0-cross-x86_64-win64-win32.exe
Start-Process c:\lazarus-1.6.2-fpc-3.0.0-cross-x86_64-win64-win32.exe /silent -NoNewWindow -Wait

Read-S3Object -BucketName top3-deploy -Key lazarus/Git-2.11.0-64-bit.exe -File c:\Git-2.11.0-64-bit.exe
Start-Process c:\Git-2.11.0-64-bit.exe /silent -NoNewWindow -Wait

Read-S3Object -BucketName top3-deploy -Key lazarus/setup.tar -File C:\Users\Administrator\setup.tar
Start-Process -FilePath "C:\Program Files\Git\usr\bin\tar" -ArgumentList ("-xvf", "setup.tar") -WorkingDirectory "C:\Users\Administrator" -NoNewWindow -Wait

& "C:\Program Files\Git\git-bash.exe" --cd-to-home setup/go.sh

Read-S3Object -BucketName top3-deploy -Key lazarus/nsis-3.01-setup.exe c:\nsis-3.01-setup.exe
Start-Process -FilePath c:\nsis-3.01-setup.exe -ArgumentList ("/S") -NoNewWindow -Wait

mkdir C:\tools
Read-S3Object -BucketName top3-deploy -Key lazarus/ent.exe -File C:\tools\ent.exe

mkdir C:\buildkite
Read-S3Object -BucketName top3-deploy -Key lazarus/buildkite-agent.cfg -File C:\buildkite\buildkite-agent.cfg
Read-S3Object -BucketName top3-deploy -Key lazarus/buildkite-agent.exe -File C:\buildkite\buildkite-agent.exe
#Start-Process -FilePath C:\buildkite\buildkite-agent.exe -ArgumentList ("start") -WorkingDirectory C:\buildkite

Start-Process -FilePath "C:\Program Files\Git\get-bash.exe" -ArgumentList ("--cd-to-home", "setup/go.sh") 

# re-enable windows defender - I don't know why.
Set-MpPreference -DisableRealtimeMonitoring $false
