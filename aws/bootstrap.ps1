<powershell>
Read-S3Object -BucketName top3-deploy -Key lazarus/deploy.ps1 -File c:\deploy.ps1
& c:\deploy.ps1
</powershell>
