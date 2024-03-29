# Import-Module $(Join-Path $PSScriptRoot '.\Utilities.psm1') -Force
using module .\Utilities.psm1

$global:loginInfo = $null
$global:configuration = Get-Configuration

function MainMenu {
  $LoginMenu = Create-Menu -MenuTitle "Welcome to EA Admin Tools - Login" -MenuOptions "Login with User Credential","Login with current Credential","Login with Service Principal","Quit"
  switch ($LoginMenu) {
    0 { 
      Login-User
      Get-UserFunctionMenu
    }
    1 {
      Login-User -SkipLogin
      if ([CredentialType]::SPN -eq $(Get-CredentialType)) {
        Get-SPNFunctionMenu
      } else {
        Get-UserFunctionMenu
      }
    }
    2 {
      az login --service-principal -u $global:configuration.SPLoginInfo.Client_Id -p $global:configuration.SPLoginInfo.Client_Password --tenant $global:configuration.SPLoginInfo.Tenant_Id --allow-no-subscriptions
      $global:loginInfo = az account show | ConvertFrom-Json
      Write-Success "Successfully Logged in."
      cmd /c pause
      Get-SPNFunctionMenu
    }
    3 { Exit }
  }
}

function Get-UserFunctionMenu {
  $functionMenu = Create-Menu -MenuTitle "User Functions" -MenuOptions "Azure AD Operations", "EA Admin Operations", "Back", "Quit"
  switch ($functionMenu) {
    0 { Get-AzureADMenu  }
    1 { Get-EAAdminMenu }
    2 { MainMenu }
    3 { Exit }
  }
}

function Get-SPNFunctionMenu {
  $menu = Create-Menu -MenuTitle "SPN Functions" -MenuOptions "Get JWT Token", "Back", "Quit"

  switch ($menu) {
    0 { 
      $token = Get-AccessToken

      Write-Host "Bearer $token"
      cmd /c pause
      Get-SPNFunctionMenu
    }
    1 {
      MainMenu
    }
    2 {
      Exit
    }
    
  }
}

function Get-AzureADMenu {
  $aadMenu = Create-Menu -MenuTitle "Azure AD Operations" -MenuOptions "Switch Account", "Switch Tenant", "Get JWT Token", "Back", "Quit"
  switch ($aadMenu) {
    0 {
      az login --allow-no-subscriptions
      Update-LoginInfo
      Display-LoginInfo
      Write-Success "Account switched..."
      cmd /c pause
      Get-UserFunctionMenu
    }
    1 {
      Write-Host "Showing available tenants info..." -ForegroundColor Yellow
      az account tenant list
      $tenantInfo = Read-Host "Please input your tenant name or tenant id here"
      az login --tenant $tenantInfo --allow-no-subscriptions
      Update-LoginInfo
      cmd /c pause
      Get-UserFunctionMenu
    }
    2 {
      $token = Get-AccessToken

      Write-Host "Bearer $token"
      cmd /c pause
      Get-UserFunctionMenu
    }
    3 { Get-UserFunctionMenu }
    4 { Exit }
  }
}

function Get-EAAdminMenu {
  $menu = Create-Menu -MenuTitle "EA Admin Operations" -MenuOptions "Assign Roles - to user", "Assign Roles - to SPN", "Check Roles", "Export Roles", "Delete Roles", "Back", "Quit"
  switch ($menu) {
    0 {
      Write-AssignRoleWarnings
      Get-AssignUserRoleMenu
    }
    1 {
      Write-AssignRoleWarnings
      Get-AssignSPNRoleMenu
    }
    2 {
      Get-EACheckRolesMenu
    }
    3 {
      Get-EAExportRolesMenu
    }
    4 {
      Get-DeleteRoleMenu
    }
    5 {
      Get-UserFunctionMenu
    }
    6 {
      Exit
    }
  }
}

function Write-AssignRoleWarnings {
  Write-Warning "It's strongly recommended to login to Enrollment Administrator role to get the maximum role assignment priviledge."
  Write-Warning "Note: to assign Subscription Creator role, please login as the Enrollment Account Owner role."
  Write-Warning "If you are not sure which role is the signed account, use the Check Role menu for different roles that you might have."
  cmd /c pause
}


function Get-EACheckRolesMenu {
  $menu = Create-Menu -MenuTitle "Check EA Roles" -MenuOptions "Enterprise Level", "Department Level", "Enrollment Account Level", "Back", "Quit"
  $scope = ""
  switch ($menu) {
    0 {
      $scope = "Enrollment"
      $principalInput = Get-UserInput "Please input the user email or service principal (default will be the current signed in user)"
      $roleAssignmentsResponse = Get-BillingRoleAssignmentsResponse -Scope $scope
      break
    }
    1 {
      $scope = "Department"
      $principalInput = Get-UserInput "Please input the user email or service principal (default will be the current signed in user)"
      $roleAssignmentsResponse = Get-BillingRoleAssignmentsResponse -Scope "Department"
      break
    }

    2 {
      $scope = "EnrollmentAccount"
      $principalInput = Get-UserInput "Please input the user email or service principal (default will be the current signed in user)"
      $roleAssignmentsResponse = Get-BillingRoleAssignmentsResponse -Scope "EnrollmentAccount"
      break
    }

    3 {
      Get-UserFunctionMenu
      return
    }

    4 {
      Exit
    }
  }
  if ($null -ne $roleAssignmentsResponse) {
    $identityToCheck = $principalInput
    $roleAssignments = $roleAssignmentsResponse.Content | ConvertFrom-Json
    if ([string]::IsNullOrEmpty($principalInput)) {
      $identityToCheck = $global:loginInfo.user.name
    }

    if (Get-IsValidEmail $identityToCheck) {
      Write-Warning "Checking user $identityToCheck under $scope level permission."
      $assignedRole = $roleAssignments.value.properties | Where-Object { $_.userEmailAddress -eq $identityToCheck }
    } elseif (Test-IsGuid $identityToCheck){
      Write-Warning "Checking principal $identityToCheck under $scope level permission."
      $assignedRole = $roleAssignments.value.properties | Where-Object { $_.principalId -eq $identityToCheck }
    }

    if ($null -ne $assignedRole) {
      $roleDefinitionId = $assignedRole.roleDefinitionId.Split("/")[-1]
      $roleName = $global:configuration.RoleMappings.$roleDefinitionId.name
      # Write-Success "$identityToCheck role at $scope level is: $roleName"
      Write-Host "$identityToCheck " -ForegroundColor Magenta -NoNewLine; Write-Host "at " -NoNewLine; Write-Host "$scope " -ForegroundColor Magenta -NoNewLine; Write-Host "level is: " -NoNewLine; Write-Host "$roleName" -ForegroundColor DarkMagenta
    } else {
      Write-Error "$identityToCheck doesn't have any role at $scope level."
    }
  }

  cmd /c pause
  Get-EAAdminMenu
}

function Get-EAExportRolesMenu {
  $menu = Create-Menu -MenuTitle "Export Roles to CSV" -MenuOptions "Export Enrollment Roles", "Export Department Roles", "Export Enrollment Account Roles", "Back", "Quit"
  switch ($menu) {
    0 {
      $scope = "Enrollment"
      $roleAssignmentsResponse = Get-BillingRoleAssignmentsResponse -Scope $scope
      $exportFileName = "ExportRoles-$($global:configuration.RoleOperationScope.BillingAccountName)-$scope-$($(Get-Date).ToString("yyyyMMdd")).csv"
      break
    }
    1 {
      $scope = "Department"
      $roleAssignmentsResponse = Get-BillingRoleAssignmentsResponse -Scope $scope
      $exportFileName = "ExportRoles-$($global:configuration.RoleOperationScope.BillingAccountName)-$($global:configuration.RoleOperationScope.DepartmentName)-$scope-$($(Get-Date).ToString("yyyyMMdd")).csv"
      break
    }
    2 {
      $scope = "EnrollmentAccount"
      $roleAssignmentsResponse = Get-BillingRoleAssignmentsResponse -Scope $scope
      $exportFileName = "ExportRoles-$($global:configuration.RoleOperationScope.BillingAccountName)-$($global:configuration.RoleOperationScope.EnrollmentAccountName)-$scope-$($(Get-Date).ToString("yyyyMMdd")).csv"
      break
    }
    3 {
      Get-EAAdminMenu
    }
    4 {
      Exit
    }
  }

  $content = $roleAssignmentsResponse.Content | ConvertFrom-Json

  [System.Collections.ArrayList]$objList = @()
  foreach ($item in $content.value) {
    # Get Role Definition Name
    $definitionId = $item.properties.roleDefinitionId.Split('/')[-1]
    $roleDefinitionName = $global:configuration.RoleMappings.$definitionId.name
    if ($null -ne $item.properties.userEmailAddress) {
      $assignedTo = $item.properties.userEmailAddress
      $assignedType = "User"
    } else {
      $assignedTo = $item.properties.principalId
      $assignedType = "SPN"
    }
    $obj = [PSCustomObject]@{
      RoleAssignmentName = $item.name
      CreatedBy = $item.properties.createdByUserEmailAddress
      ModifiedBy = $item.properties.modifiedByUserEmailAddress
      RoleDefinitionId = $item.properties.roleDefinitionId
      RoleDefinitionName = $roleDefinitionName
      AssignedTo = $assignedTo
      AssignedType = $assignedType
    }
    [void]$objList.Add($obj)
  }
  $dt = Generate-RoleAssignmentsCsv -RoleAssignmentsObjList $objList
  $dt | Export-Csv $exportFileName -NoTypeInformation
  Write-Success "CSV file generated with name: $exportFileName"
  cmd /c pause
  Get-EAAdminMenu
}

function Get-AssignUserRoleMenu {
  $menu = Create-Menu -MenuTitle "Choose the role to be assigned" -MenuOptions "Enrollment Administrator", "Enrollment Reader", "EA Purchaser", "Department Administrator", "Department Reader", "Enrollment Account Owner", "Subscription Creator", "Back", "Quit"
  switch ($menu) {
    0 {
      $roleDefinitionId = $($global:configuration.RoleMappings.PSObject.Properties.GetEnumerator() | Where-Object {$_.Value.name -eq "Enrollment Administrator"}).name
      $userEmail = Get-UserInput "Please input user email address for role assignment"
      $billingAccountName = $global:configuration.RoleOperationScope.BillingAccountName
      Assign-Role -BillingAccountName $billingAccountName -RoleDefinitionId $roleDefinitionId -UserEmail $userEmail
      cmd /c pause
      Get-EAAdminMenu
    }
    1 {
      $roleDefinitionId = $($global:configuration.RoleMappings.PSObject.Properties.GetEnumerator() | Where-Object {$_.Value.name -eq "Enrollment Reader"}).name
      $userEmail = Get-UserInput "Please input user email address for role assignment"
      $billingAccountName = $global:configuration.RoleOperationScope.BillingAccountName
      Assign-Role -BillingAccountName $billingAccountName -RoleDefinitionId $roleDefinitionId -UserEmail $userEmail
      cmd /c pause
      Get-EAAdminMenu
    }
    2 {
      $roleDefinitionId = $($global:configuration.RoleMappings.PSObject.Properties.GetEnumerator() | Where-Object {$_.Value.name -eq "EA Purchaser"}).name
      $userEmail = Get-UserInput "Please input user email address for role assignment"
      $billingAccountName = $global:configuration.RoleOperationScope.BillingAccountName
      Assign-Role -BillingAccountName $billingAccountName -RoleDefinitionId $roleDefinitionId -UserEmail $userEmail
      cmd /c pause
      Get-EAAdminMenu
    }
    3 {
      $roleDefinitionId = $($global:configuration.RoleMappings.PSObject.Properties.GetEnumerator() | Where-Object {$_.Value.name -eq "Department Administrator"}).name
      $userEmail = Get-UserInput "Please input user email address for role assignment"
      $billingAccountName = $global:configuration.RoleOperationScope.BillingAccountName
      $departmentName = $global:configuration.RoleOperationScope.DepartmentName
      Assign-Role -BillingAccountName $billingAccountName -RoleDefinitionId $roleDefinitionId -UserEmail $userEmail -DepartmentName $departmentName
      cmd /c pause
      Get-EAAdminMenu
    }
    4 {
      $roleDefinitionId = $($global:configuration.RoleMappings.PSObject.Properties.GetEnumerator() | Where-Object {$_.Value.name -eq "Department Reader"}).name
      $userEmail = Get-UserInput "Please input user email address for role assignment"
      $billingAccountName = $global:configuration.RoleOperationScope.BillingAccountName
      $departmentName = $global:configuration.RoleOperationScope.DepartmentName
      Assign-Role -BillingAccountName $billingAccountName -RoleDefinitionId $roleDefinitionId -UserEmail $userEmail -DepartmentName $departmentName
      cmd /c pause
      Get-EAAdminMenu
    }
    5 {
      $roleDefinitionId = $($global:configuration.RoleMappings.PSObject.Properties.GetEnumerator() | Where-Object {$_.Value.name -eq "Enrollment Account Owner"}).name
      $userEmail = Get-UserInput "Please input user email address for role assignment"
      $billingAccountName = $global:configuration.RoleOperationScope.BillingAccountName
      $enrollmentAccountName = $global:configuration.RoleOperationScope.EnrollmentAccountName
      Assign-Role -BillingAccountName $billingAccountName -RoleDefinitionId $roleDefinitionId -UserEmail $userEmail -EnrollmentAccountName $enrollmentAccountName
      cmd /c pause
      Get-EAAdminMenu
    }
    6 {
      Write-Warning "Please note that only Enrollment Account Owner role can assign Subscription Creator based on the enrollment account."
      $roleDefinitionId = $($global:configuration.RoleMappings.PSObject.Properties.GetEnumerator() | Where-Object {$_.Value.name -eq "Subscription Creator"}).name
      $userEmail = Get-UserInput "Please input user email address for role assignment"
      $billingAccountName = $global:configuration.RoleOperationScope.BillingAccountName
      $enrollmentAccountName = $global:configuration.RoleOperationScope.EnrollmentAccountName
      Assign-Role -BillingAccountName $billingAccountName -RoleDefinitionId $roleDefinitionId -UserEmail $userEmail -EnrollmentAccountName $enrollmentAccountName
      cmd /c pause
      Get-EAAdminMenu
    }
    7 {
      Get-EAAdminMenu
    }
    8 {
      Exit
    }
  }
}

function Get-DeleteRoleMenu {
  $menu = Create-Menu -MenuTitle "Choose the level of the role to be deleted" -MenuOptions "Enrollment", "Department", "Enrollment Account", "Back", "Quit"
  switch ($menu) {
    0 {
      $scope = "Enrollment"
      $principalInput = Get-UserInput "Please input the user email or service principal whose role will be deleted at $scope level"
      if ($true -eq $(Test-IsGuid $principalInput)) {
        $isSPN = $true
      } else {
        $isSPN = $false
      }
      Delete-Role -Scope $scope -Principal $principalInput -IsSPN $isSPN
      cmd /c pause
      Get-EAAdminMenu
    }
    1 {
      $scope = "Department"
      $principalInput = Get-UserInput "Please input the user email or service principal whose role will be deleted at $scope level"
      if ($true -eq $(Test-IsGuid $principalInput)) {
        $isSPN = $true
      } else {
        $isSPN = $false
      }
      Delete-Role -Scope $scope -Principal $principalInput -IsSPN $isSPN
      cmd /c pause
      Get-EAAdminMenu
    }
    2 {
      $scope = "EnrollmentAccount"
      $principalInput = Get-UserInput "Please input the user email or service principal whose role will be deleted at $scope level"
      if ($true -eq $(Test-IsGuid $principalInput)) {
        $isSPN = $true
      } else {
        $isSPN = $false
      }
      Delete-Role -Scope $scope -Principal $principalInput -IsSPN $isSPN
      cmd /c pause
      Get-EAAdminMenu
    }
    3 {
      Get-EAAdminMenu
    }
    4 {
      Exit
    }
  }
}

function Get-AssignSPNRoleMenu {
  $menu = Create-Menu -MenuTitle "Choose the role to be assigned" -MenuOptions "Enrollment Reader", "EA Purchaser", "Department Reader", "Subscription Creator", "Back", "Quit"

  switch ($menu) {
    0 {
      $roleDefinitionId = $($global:configuration.RoleMappings.PSObject.Properties.GetEnumerator() | Where-Object {$_.Value.name -eq "Enrollment Reader"}).name
      $spnPrincipalId = Get-UserInput "Please input the service principal object id for role assignment"
      $billingAccountName = $global:configuration.RoleOperationScope.BillingAccountName
      Assign-Role -BillingAccountName $billingAccountName -RoleDefinitionId $roleDefinitionId -PrincipalId $spnPrincipalId
      cmd /c pause
      Get-EAAdminMenu
    }
    1 {
      $roleDefinitionId = $($global:configuration.RoleMappings.PSObject.Properties.GetEnumerator() | Where-Object {$_.Value.name -eq "EA Purchaser"}).name
      $spnPrincipalId = Get-UserInput "Please input the service principal object id for role assignment"
      $billingAccountName = $global:configuration.RoleOperationScope.BillingAccountName
      Assign-Role -BillingAccountName $billingAccountName -RoleDefinitionId $roleDefinitionId -PrincipalId $spnPrincipalId
      cmd /c pause
      Get-EAAdminMenu
    }
    2 {
      $roleDefinitionId = $($global:configuration.RoleMappings.PSObject.Properties.GetEnumerator() | Where-Object {$_.Value.name -eq "Department Reader"}).name
      $spnPrincipalId = Get-UserInput "Please input the service principal object id for role assignment"
      $billingAccountName = $global:configuration.RoleOperationScope.BillingAccountName
      $departmentName = $global:configuration.RoleOperationScope.DepartmentName
      Assign-Role -BillingAccountName $billingAccountName -DepartmentName $departmentName -RoleDefinitionId $roleDefinitionId -PrincipalId $spnPrincipalId
      cmd /c pause
      Get-EAAdminMenu
    }
    3 {
      Write-Warning "Please note that only Enrollment Account Owner role can assign Subscription Creator based on the enrollment account."
      $roleDefinitionId = $($global:configuration.RoleMappings.PSObject.Properties.GetEnumerator() | Where-Object {$_.Value.name -eq "Subscription Creator"}).name
      $spnPrincipalId = Get-UserInput "Please input the service principal object id for role assignment"
      $billingAccountName = $global:configuration.RoleOperationScope.BillingAccountName
      $enrollmentAccountName = $global:configuration.RoleOperationScope.EnrollmentAccountName
      Assign-Role -BillingAccountName $billingAccountName -RoleDefinitionId $roleDefinitionId -PrincipalId $spnPrincipalId -EnrollmentAccountName $enrollmentAccountName
      cmd /c pause
      Get-EAAdminMenu
    }
    4 {
      Get-EAAdminMenu
    }
    5 {
      Exit
    }
  }
}

function Assign-Role {
  param(
    [Parameter(Mandatory=$true)]
    [string]$BillingAccountName,
    [Parameter(Mandatory=$true)]
    [string]$RoleDefinitionId,
    [Parameter(Mandatory=$false)]
    [string]$DepartmentName,
    [Parameter(Mandatory=$false)]
    [string]$EnrollmentAccountName,
    [Parameter(Mandatory=$false)]
    [string]$PrincipalId,
    [Parameter(Mandatory=$false)]
    [string]$UserEmail
  )

  $token = $(az account get-access-token --resource=https://management.azure.com --query accessToken --output tsv)

  if (-not [string]::IsNullOrEmpty($EnrollmentAccountName)) {
    $endpoint = $global:configuration.BillingAPIUrls.AssignEnrollmentAccountLevelRoles.Replace("{billingAccountName}", $BillingAccountName).Replace("{enrollmentAccountName}", $EnrollmentAccountName).Replace("{billingRoleAssignmentName}", $(New-Guid).Guid)
    $roleDefinitionIdPayload = "/providers/Microsoft.Billing/billingAccounts/$BillingAccountName/enrollmentAccounts/$EnrollmentAccountName/billingRoleDefinitions/$RoleDefinitionId"
  } elseif (-not [string]::IsNullOrEmpty($DepartmentName)) {
    $endpoint = $global:configuration.BillingAPIUrls.AssignDepartmentLevelRoles.Replace("{billingAccountName}", $BillingAccountName).Replace("{departmentName}", $DepartmentName).Replace("{billingRoleAssignmentName}", $(New-Guid).Guid)
    $roleDefinitionIdPayload = "/providers/Microsoft.Billing/billingAccounts/$BillingAccountName/departments/$DepartmentName/billingRoleDefinitions/$RoleDefinitionId"
  } else {
    $endpoint = $global:configuration.BillingAPIUrls.AssignBillingAccountLevelRoles.Replace("{billingAccountName}", $BillingAccountName).Replace("{billingRoleAssignmentName}", $(New-Guid).Guid)
    $roleDefinitionIdPayload = "/providers/Microsoft.Billing/billingAccounts/$BillingAccountName/billingRoleDefinitions/$RoleDefinitionId"
  }

  if (-not [string]::IsNullOrEmpty($PrincipalId) -and $(Test-IsGuid $PrincipalId)) {
    # Assigning a role to SPN
    Write-Warning "Checking principal id existance in current tenant..."
    $checkResult = az ad sp show --id $PrincipalId --only-show-errors 2>NUL
    if ($null -eq $checkResult) {
      Write-Error "$PrincipalId is not found in current tenant. Try switching tenant."
    } else {
      $payload = @{
        properties=@{
          principalId=$PrincipalId
          principalTenantId=$global:loginInfo.tenantId
          roleDefinitionId=$roleDefinitionIdPayload
        }
      }
    }
  }

  if (-not [string]::IsNullOrEmpty($UserEmail) -and $(Get-IsValidEmail $UserEmail)) {
    $payload = @{
      properties=@{
        userEmailAddress=$UserEmail
        principalTenantId=$global:loginInfo.tenantId
        roleDefinitionId=$roleDefinitionIdPayload
      }
    }

    $userAuthType = Choose-UserAuthenticationType
    $payload.properties["userAuthenticationType"] = $userAuthType
  }

  $jsonPayload = $payload | ConvertTo-Json

  try {
    $response = Invoke-WebRequest -Uri $endpoint -Method "PUT" -Headers @{Authorization="Bearer $token"} -Body $jsonPayload -ContentType "application/json"
  }
  catch {
    if ($_.Exception.Response.StatusCode -eq 403) {
      Write-Warning "This token you provided does not have the priviledge to assign the role. Try logging in with another account or switch to correct tenant."
      Read-Host "Press any key to go back"
      Get-EAAdminMenu
      return
    } else {
      Write-Error "Something wrong happened, error: $($_.ErrorDetails.Message)."
      Read-Host "Press any key to go back"
      Get-EAAdminMenu
      return
    }
  }
  $result = $response | ConvertFrom-Json
  if ($result.StatusCode -lt 299) {
    if (-not [string]::IsNullOrEmpty($UserEmail)){
      Write-Success "Successfully assigned role: $($global:configuration.RoleMappings.$RoleDefinitionId.name) to User: $UserEmail"
    } else {
      Write-Success "Successfully assigned role: $($global:configuration.RoleMappings.$RoleDefinitionId.name) to SPN: $PrincipalId"
    }
  }
}

function Delete-Role {
  param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Enrollment', 'Department', 'EnrollmentAccount')]
    [string]$Scope,
    [Parameter(Mandatory=$true)]
    [string]$Principal,
    [Parameter(Mandatory=$true)]
    [bool]$IsSPN,
    [Parameter(Mandatory=$false)]
    [string]$RoleAssignmentName
  )

  $billingAccountName = $global:configuration.RoleOperationScope.BillingAccountName

  switch ($Scope) {
    "Enrollment" {
      $endpoint = $global:configuration.BillingAPIUrls.AssignBillingAccountLevelRoles.Replace("{billingAccountName}", $billingAccountName)
      break
    }
    "Department" {
      $departmentName = $global:configuration.RoleOperationScope.DepartmentName
      $endpoint = $global:configuration.BillingAPIUrls.AssignDepartmentLevelRoles.Replace("{billingAccountName}", $billingAccountName).Replace("{departmentName}", $departmentName)
      break
    }
    "EnrollmentAccount" {
      $enrollmentAccountName = $global:configuration.RoleOperationScope.EnrollmentAccountName
      $endpoint = $global:configuration.BillingAPIUrls.AssignEnrollmentAccountLevelRoles.Replace("{billingAccountName}", $billingAccountName).Replace("{enrollmentAccountName}", $enrollmentAccountName)
      break
    }
  }

  # if ([string]::IsNullOrEmpty($RoleAssignmentName)) {
    # Need to get the role assignment name
  $roleAssignmentsResponse = Get-BillingRoleAssignmentsResponse -Scope $Scope
  if ($null -ne $roleAssignmentsResponse) {
    # $RoleAssignmentName = $roleAssignmentsResponse.name
    $roleAssignments = $roleAssignmentsResponse.Content | ConvertFrom-Json

    if (-not $IsSPN) {
      Write-Warning "Checking user $Principal under $Scope level permission."
      $assignedRole = $roleAssignments.value | Where-Object { $_.properties.userEmailAddress -eq $Principal }
    } else {
      Write-Warning "Checking service principal $Principal under $Scope level permission."
      $assignedRole = $roleAssignments.value | Where-Object { $_.properties.principalId -eq $Principal }
    }

    if ($null -ne $assignedRole) {
      $RoleAssignmentName = $assignedRole.name
      $RoleName = Get-RoleNameFromRoleDefinitionId $assignedRole.properties.RoleDefinitionId
    } else {
      Write-Error "$Principal doesn't have any role at $Scope level."
      return
    }
  }
  # }

  # Starting to delete role.
  $endpoint = $endpoint.Replace("{billingRoleAssignmentName}", $RoleAssignmentName)

  $proceed = Choose-YesOrNo -Title "Delete Role" -Message "Are you sure you want to delete $RoleName for $Principal at $Scope level?"

  if ($proceed -eq "YES") {
    Write-Warning "Deleting $RoleName for $Principal under $Scope level"
    try {
      $token = $(az account get-access-token --resource=https://management.azure.com --query accessToken --output tsv)
      $response = Invoke-WebRequest -Uri $endpoint -Method "Delete" -Headers @{Authorization="Bearer $token"}
    }
    catch {
      if ($_.Exception.Response.StatusCode -eq 403) {
        Write-Warning "This token you provided does not have the priviledge to assign the role. Try logging in with another account or switch to correct tenant."
        Read-Host "Press any key to go back"
        # Get-UserFunctionMenu
        Get-EAAdminMenu
        return
      } else {
        Write-Error "Something wrong happened, error: $($_.ErrorDetails.Message)."
        Read-Host "Press any key to go back"
        # Get-UserFunctionMenu
        Get-EAAdminMenu
        return
      }
    }

    $result = $response | ConvertFrom-Json
    if ($result.StatusCode -lt 299) {
      Write-Success "Successfully deleted role: $RoleName to Principal: $Principal"
    }
  } else {
    Write-Warning "Operation cancelled."
  }
}

function Get-RoleNameFromRoleDefinitionId {
  param(
    [Parameter(Mandatory=$true, Position = 0)]
    [string]$RoleDefinitionId
  )

  $roleId = $RoleDefinitionId.Split("/")[-1]

  return $global:configuration.RoleMappings.$roleId.name
}

function Choose-UserAuthenticationType {
  $organization = New-Object System.Management.Automation.Host.ChoiceDescription "&Organization", "User Authentication Type: Organization"
  $msa = New-Object System.Management.Automation.Host.ChoiceDescription "&MSA", "User Authentication Type: MSA"

  $options = [System.Management.Automation.Host.ChoiceDescription[]]($organization, $msa)

  $title = "User Authentication Type"
  $message = "Please choose the user auth type."
  $result = $host.UI.PromptForChoice($title, $message, $options, 0)
  switch ($result) {
    0 { return "Organization" }
    1 { return "MicrosoftAccount" }
  }
}

function Generate-RoleAssignmentsCsv {
  param(
    [Parameter(Mandatory=$true)]
    [System.Collections.ArrayList]
    $RoleAssignmentsObjList
  )

  $DataTable = New-Object System.Data.DataTable
  $RoleAssignmentNameCol = New-Object System.Data.DataColumn("Role Assignment Name")
  $CreatedByCol = New-Object System.Data.DataColumn("Created By")
  $ModifiedByCol = New-Object System.Data.DataColumn("Modified By")
  $RoleDefinitionIdCol = New-Object System.Data.DataColumn("Role Definition Id")
  $RoleDefinitionNameCol = New-Object System.Data.DataColumn("Role Definition Name")
  $AssignedToCol = New-Object System.Data.DataColumn("Assigned To")
  $AssignedTypeCol = New-Object System.Data.DataColumn("Assigned Type")

  $DataTable.Columns.Add($RoleAssignmentNameCol)
  $DataTable.Columns.Add($CreatedByCol)
  $DataTable.Columns.Add($ModifiedByCol)
  $DataTable.Columns.Add($RoleDefinitionIdCol)
  $DataTable.Columns.Add($RoleDefinitionNameCol)
  $DataTable.Columns.Add($AssignedToCol)
  $DataTable.Columns.Add($AssignedTypeCol)

  foreach ($roleAssignmentObj in $RoleAssignmentsObjList) {
    $row = $DataTable.NewRow()
    $row["Role Assignment Name"] = $roleAssignmentObj.RoleAssignmentName
    $row["Created By"] = $roleAssignmentObj.CreatedBy
    $row["Modified By"] = $roleAssignmentObj.ModifiedBy
    $row["Role Definition Id"] = $roleAssignmentObj.RoleDefinitionId
    $row["Role Definition Name"] = $roleAssignmentObj.RoleDefinitionName
    $row["Assigned To"] = $roleAssignmentObj.AssignedTo
    $row["Assigned Type"] = $roleAssignmentObj.AssignedType
    $DataTable.Rows.Add($row)
  }

  return ,$DataTable
}

function Get-BillingRoleAssignmentsResponse {
  param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Enrollment', 'Department', 'EnrollmentAccount')]
    [string]
    $Scope
  )

  $AccessToken = $(az account get-access-token --resource=https://management.azure.com --query accessToken --output tsv)

  $billingAccountName = $global:configuration.RoleOperationScope.BillingAccountName

  switch ($Scope) {
    "Enrollment" {
      $endpoint = $global:configuration.BillingAPIUrls.GetBillingRoleAssignmentsByBillingAccount.Replace("{billingAccountName}", $billingAccountName)
    }
    "Department" {
      $departmentName = $global:configuration.RoleOperationScope.DepartmentName
      $endpoint = $global:configuration.BillingAPIUrls.GetBillingRoleAssignmentsByDepartment.Replace("{billingAccountName}", $billingAccountName).Replace("{departmentName}", $departmentName)
    }
    "EnrollmentAccount" {
      $enrollmentAccountName = $global:configuration.RoleOperationScope.EnrollmentAccountName
      $endpoint = $global:configuration.BillingAPIUrls.GetBillingRoleAssignmentsByEnrollmentAccount.Replace("{billingAccountName}", $billingAccountName).Replace("{enrollmentAccountName}", $enrollmentAccountName)
    }
  }

  try {
    $response = Invoke-WebRequest -Uri $endpoint -Method Get -Headers @{Authorization="Bearer $AccessToken"}
  }
  catch {
    if ($_.Exception.Response.StatusCode -eq 403) {
      Write-Warning "This token you provided does not have permission to get the role assignments on $Scope level, please do proper role assignment first."
      cmd /c pause
      # Get-UserFunctionMenu
      return
    } else {
      Write-Error "Something wrong happened, error: $($_.Exception.Response.ReasonPhrase)."
      cmd /c pause
      return
    }
  }

  return $response
}

function Update-LoginInfo {
  $global:loginInfo = az account show | ConvertFrom-Json
}

function Display-LoginInfo {
  $displayObj = @{
    Tenant_Id=$global:loginInfo.tenantId
    PrincipalName=$global:loginInfo.user.name
    Type=$global:loginInfo.user.type
  }
  New-Object -TypeName psobject -Property $displayObj | Format-Table -AutoSize
}

function Login-User {
  param (
      [Parameter(Mandatory=$false)]
      [switch]$SkipLogin = $false,
      [Parameter(Mandatory=$false)]
      [string]$Tenant_Id
  )
  if ($SkipLogin) {
      Write-Warning "User logged in with below information."
      $global:loginInfo = az account show | ConvertFrom-Json
      Display-LoginInfo
      cmd /c pause
  } else {
    if ([string]::IsNullOrEmpty($global:configuration.UserLoginInfo.Tenant_Id)) {
      Write-Warning "You did not setup tenant in Configuraiton File. Using the default az login command..."
      az login --allow-no-subscriptions
    } else {
      Write-Warning "Logging to tenant $($global:configuration.UserLoginInfo.Tenant_Id)"
      az login --tenant $global:configuration.UserLoginInfo.Tenant_Id --allow-no-subscriptions
    }
    $global:loginInfo = az account show | ConvertFrom-Json
    Write-Success "Successfully Logged in with below information."
    Display-LoginInfo
    cmd /c pause
  }
}

MainMenu