$executingDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$tenantDetail = Get-AADTenantDetail
if($tenantDetail -ne $null){
  $domainName = ($tenantDetail.verifiedDomains | Where-Object {$_.default -eq "True"}).Name
  Import-CSV $executingDirectory"\SampleAADUserData.csv" | % {
    $_.accountEnabled = [bool]::Parse($_.accountEnabled)
    $_.forceChangePasswordNextLogin = [bool]::Parse($_.forceChangePasswordNextLogin)
    $_.userPrincipalName = $_.userPrincipalName + $domainName
    #Start-Sleep 1
    
    Write-Host "Creating user" $_.userPrincipalName -Fore Green
    $newUser = $_ | New-AADUser
    $thumbnailPhotoByteArray = [Convert]::FromBase64String($_.thumbnailPhoto)

    Write-Host "Setting thumbnail photo for user" $_.userPrincipalName  -Fore Green
    Set-AADUserThumbnailPhoto -Id $newUser.ObjectId  -ThumbnailPhotoByteArray $thumbnailPhotoByteArray
  }
  
  $tenantId = $tenantDetail.objectId
  Import-CSV $executingDirectory"\SampleAADUserData.csv" | % {
    if($_.manager.Trim() -ne "" -and $_.manager -ne $null){
      $reportId = $_.mailNickname + "@" + $domainName
      $report = Get-AADUser -Id $reportId
      $managerId = $_.manager + "@" + $domainName
      $manager = Get-AADUser -Id $managerId
      
      $requestBody = "" | Select url
      $requestBody.url = [string]::Format("https://graph.windows.net/{0}/directoryObjects/{1}", $tenantId, $manager.ObjectId)

      Write-Host "Setting " $manager.userPrincipalName " as manager of " $report.userPrincipalName -Fore Green 
      Set-AADObjectProperty -Type "users" -Id $report.ObjectId -Property "manager" -Value $requestBody -IsLinked $true
    }
  }
}