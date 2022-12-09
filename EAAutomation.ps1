Import-Module $(Join-Path $PSScriptRoot '.\Utilities.psm1') -Force

$global:loginInfo = $null
$global:configuration = Get-Configuration

function MainMenu {
  $LoginMenu = Create-Menu -MenuTitle "Welcome to EA Admin Tools - Login" -MenuOptions "Login with User Credential","Login with Service Principal","Quit"
  switch ($LoginMenu) {
    0 { 
      Login-User -SkipLogin
      Get-UserFunctionMenu
    }
    1 {
      az login --service-principal -u $global:configuration.SPLoginInfo.Client_Id -p $global:configuration.SPLoginInfo.Client_Password --tenant $global:configuration.SPLoginInfo.Tenant_Id --allow-no-subscriptions
      $global:loginInfo = az account show | ConvertFrom-Json
      Write-Success "Successfully Logged in."
      cmd /c pause
      Get-SPFunctionMenu
    }
    2 { Exit-PSSession }
  }
}

function Get-UserFunctionMenu {
  $functionMenu = Create-Menu -MenuTitle "Main Menu" -MenuOptions "Azure AD Operations", "EA Admin Operations", "EA Role Check", "Quit"
  switch ($functionMenu) {
    0 { Get-AzureADMenu  }
    1 {  }
    2 {
      Get-EACheckRolesMenu
    }
    3 { Exit-PSSession }
  }
}

function Get-SPNFunctionMenu {
  $menu = Create-Menu -MenuTitle "Main Menu" -MenuOptions "Check EA Roles", "Back", "Quit"
}

function Get-AzureADMenu {
  $aadMenu = Create-Menu -MenuOptions "Switch Account", "Switch Tenant", "Back"
  switch ($aadMenu) {
    0 {
      az login
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
      cmd /c pause
      Get-UserFunctionMenu
    }
    2 { Get-UserFunctionMenu }
  }
}


function Get-EACheckRolesMenu {
  $menu = Create-Menu -MenuTitle "Check EA Roles" -MenuOptions "Enterprise Level", "Department Level", "Enrollment Account Level", "Back", "Quit"

  switch ($menu) {
    0 {
      $token = $(az account get-access-token --resource=https://management.azure.com --query accessToken --output tsv)
      $principalInput = Read-Host "Please input the user email or service principal (default will be the current signed in user)"
      Get-BillingRoleAssignmentsOnEnterpriseScopeForSingleSP -AccessToken $token -Principal $principalInput
      
      Get-EACheckRolesMenu
    }
    1 {
      $token = $(az account get-access-token --resource=https://management.azure.com --query accessToken --output tsv)
      $principalInput = Read-Host "Please input the user email or service principal (default will be the current signed in user)"
      Get-BillingRoleAssignmentsOnDepartmentForSingleSP -AccessToken $token -Principal $principalInput
      
      Get-EACheckRolesMenu
    }

    2 {
      $token = $(az account get-access-token --resource=https://management.azure.com --query accessToken --output tsv)
      $principalInput = Read-Host "Please input the user email or service principal (default will be the current signed in user)"
      Get-BillingRoleAssignmentsOnEnrollmentAccountForSingleSP -AccessToken $token -Principal $principalInput
      
      Get-EACheckRolesMenu
    }

    3 {
      Get-UserFunctionMenu
    }

    4 {
      Exit-PSSession
    }
  }
}


# Original function, rewriting it at all.

# function Get-EACheckRolesMenu {
#   $menu = Create-Menu -MenuTitle "Check EA Roles" -MenuOptions "Enterprise Level", "Department Level", "Enrollment Account Level", "Back", "Quit"

#   switch ($menu) {
#     0 {
#       $token = $(az account get-access-token --resource=https://management.azure.com --query accessToken --output tsv)
#       $enterpriseAccountName = $global:configuration.CheckRoles.Enterprise.BillingAccountName
#       try {
#         $response = Invoke-WebRequest -Uri $global:configuration.BillingAPIUrls.GetBillingRoleAssignmentsByBillingAccount.Replace("{billingAccountName}", $enterpriseAccountName).Replace("{billingRoleAssignmentName}", "") -Method Get -Headers @{Authorization="Bearer $token"}
#       }
#       catch {
#         if ($_.Exception.Response.StatusCode -eq 403) {
#           Write-Warning "This service principal does not have Enrollment Administrator role, try other level like Department, Enrollment Account."
#           Read-Host "Press any key to go back"
#           Get-UserFunctionMenu
#           return
#         } else {
#           Write-Error "Something wrong happened, error: $($_.Exception.Response.ReasonPhase)."
#           Read-Host "Press any key to go back"
#           Get-UserFunctionMenu
#           return
#         }
#       }
#       $result = ($response.Content | ConvertFrom-Json)
#       # New logic! Getting the data means this user is either Enterprise Admin or Enterprise Admin Reader.
#       # Now find out which one it is.
#       $userObj = az ad signed-in-user show | ConvertFrom-Json
#       $roleAssginment = $result.value.properties | Where-Object {$_.userEmailAddress -eq "allliu@microsoft.com"}

#       Write-Info "$($roleAssginment.roleDefinitionId)"


#       # if ($result.value.length -eq 0) {
#       #   Write-Host "This user does not have any role in the Enterprise Level" -ForegroundColor Yellow
#       # } else {
#       #   $result.value.properties | Where-Object {$_.userEmailAddress -eq "allliu@microsoft.com"}
#       # }
#       # $result.value.properties | Where-Object {$_.userEmailAddress -eq "allliu@microsoft.com"}

#       Write-Success "Operation Completed!"
#       cmd /c pause
#       # Write-Host "Operation completed! Press Y to go back to previous menu." -ForegroundColor Green
#       # Do {
#       #   $Key = [Console]::ReadKey($True)
#       #   Write-Host "Wrong Input" -ForegroundColor Red
#       # } While ( $Key.Key -NE [ConsoleKey]::Y )
#       Get-EACheckRolesMenu
#     }
#     1 {
#       $token = $(az account get-access-token --resource=https://management.azure.com --query accessToken --output tsv)
#       $enterpriseAccountName = $global:configuration.CheckRoles.Department.BillingAccountName
#       $departmentName = $global:configuration.CheckRoles.Department.DepartmentName
#       $response = Invoke-WebRequest -Uri $global:configuration.BillingAPIUrls.GetBillingRoleAssignmentsByDepartment.Replace("{billingAccountName}", $enterpriseAccountName).Replace("{departmentName}", $departmentName).Replace("{billingRoleAssignmentName}", "") -Method Get -Headers @{Authorization="Bearer $token"}
#       $result = ($response.Content | ConvertFrom-Json)
#       if ($result.value.length -eq 0) {
#         Write-Host "This user does not have any role in the Department Level" -ForegroundColor Yellow
#       } else {
#         $result.value.properties | Where-Object {$_.userEmailAddress -eq "allliu@microsoft.com"}
#       }

#       Write-Host "Operation completed! Press Y to go back to previous menu." -ForegroundColor Green
#       Do {
#         $Key = [Console]::ReadKey($True)
#         Write-Host "Wrong Input" -ForegroundColor Red
#       } While ( $Key.Key -NE [ConsoleKey]::Y )
#       Get-EACheckRolesMenu
#     }

#     2 {
#       $token = Get-AccessToken
#       $enterpriseAccountName = $global:configuration.CheckRoles.Account.BillingAccountName
#       $enrollmentAccountName = $global:configuration.CheckRoles.Account.AccountName
#       $response = Invoke-WebRequest -Uri $global:configuration.BillingAPIUrls.GetBillingRoleAssignmentsByEnrollmentAccount.Replace("{billingAccountName}", $enterpriseAccountName).Replace("{enrollmentAccountName}", $enrollmentAccountName) -Method Get -Headers @{Authorization="Bearer $token"}
#       $result = ($response.Content | ConvertFrom-Json)
#       if ($result.value.length -eq 0) {
#         Write-Host "This user does not have any role in the Enrollment Account Level" -ForegroundColor Yellow
#       } else {
#         $result.value.properties | Where-Object {$_.userEmailAddress -eq "allliu@microsoft.com"}
#       }

#       Write-Host "Operation completed! Press Y to go back to previous menu." -ForegroundColor Green
#       Do {
#         $Key = [Console]::ReadKey($True)
#         Write-Host "Wrong Input" -ForegroundColor Red
#       } While ( $Key.Key -NE [ConsoleKey]::Y )
#       Get-EACheckRolesMenu
#     }

#     3 {
#       Get-FunctionMenu
#     }

#     4 {
#       Exit-PSSession
#     }
#   }
# }

#MainMenu
# function Main {
#   $loginMenu = Create-Menu -MenuTitle "Welcome to EA Admin Tools - Login" -MenuOptions "Login with User Credential","Login with Service Principal","Quit"
#   switch ($loginMenu) {
#       0 {
#         az login --output none
#         $functionMenu = Create-Menu -MenuOptions "Azure AD Operations", "EA Admin Operations", "EA Role Check", "Quit"
#         Do {
#           switch ($functionMenu) {
#             0 {
#               $azureADMenu = Create-Menu -MenuOptions "Switch Account", "Switch Tenant", "Back"
#               Do {
#                 switch ($azureADMenu) {
#                   0{
#                     Write-Host "Test Back"
#                   }
#                 }
#               } Until ($azureADMenu -eq '2')
#             }
#           }
#         } Until ($functionMenu -eq '3')
#       }
#       1 {
#         Write-Host "Please input your information"
#       }
#       2 {
#         Exit-PSSession
#       }
#   }
# }

# API related functions
# function Get-BillingRoleAssignmentsOnEnterpriseScopeForSingleSP {
#   param (
#     [Parameter(Mandatory=$true)]
#     [string]
#     $AccessToken,
#     [Parameter(Mandatory=$false)]
#     [string]
#     $Principal
#   )
#   $enterpriseAccountName = $global:configuration.CheckRoles.Enterprise.BillingAccountName
#   if ([string]::IsNullOrEmpty($Principal)) {
#     Write-Warning "Checking current signed user $($global:loginInfo.user.name) on the Enrollment Account level for billing account: $enterpriseAccountName)..."
#     try {
#       $response = Invoke-WebRequest -Uri $global:configuration.BillingAPIUrls.GetBillingRoleAssignmentsByBillingAccount.Replace("{billingAccountName}", $enterpriseAccountName) -Method Get -Headers @{Authorization="Bearer $AccessToken"}
#     }
#     catch {
#       if ($_.Exception.Response.StatusCode -eq 403) {
#         Write-Warning "This service principal does not have Enrollment Administrator role, try other level like Department, Enrollment Account."
#         Read-Host "Press any key to go back"
#         Get-UserFunctionMenu
#         return
#       } else {
#         Write-Error "Something wrong happened, error: $($_.Exception.Response.ReasonPhase)."
#         Read-Host "Press any key to go back"
#         Get-UserFunctionMenu
#         return
#       }
#     }
#     $result = ($response.Content | ConvertFrom-Json)
#     # New logic! Getting the data means this user is either Enterprise Admin or Enterprise Admin Reader.
#     # Now find out which one it is.

#     # $userObj = az ad signed-in-user show | ConvertFrom-Json

#     # Still use email address to check to avoid tenant related issue.
#     $roleAssginment = $result.value.properties | Where-Object {$_.userEmailAddress -eq $global:loginInfo.user.name}
#     $roleDefinitionId = $roleAssginment.roleDefinitionId.Split('/')[-1]
#     $roleName = $global:configuration.RoleMappings.$roleDefinitionId.name
#     Write-Success "The current role for user $($global:loginInfo.user.name) in the Enrollment level of billing account $($enterpriseAccountName) is: $roleName";
#     # Write-Info "$($roleAssginment.roleDefinitionId.Split('/')[-1])"

#     Write-Success "Operation Completed!"
#     cmd /c pause
#   } else {
#     # First check it's email or principal Id
#     if (Get-IsValidEmail -Email $Principal) {
#       Write-Success "Good email"
#     } else {
#       Write-Error "Wrong email!"
#     }
#   }
# }

function Get-BillingRoleAssignmentsOnEnterpriseScopeForSingleSP {
  param (
    [Parameter(Mandatory=$true)]
    [string]
    $AccessToken,
    [Parameter(Mandatory=$false)]
    [string]
    $Principal
  )
  $enterpriseAccountName = $global:configuration.CheckRoles.Enterprise.BillingAccountName
  # Get the response for all the billing account level role assignments first.
  try {
    $response = Invoke-WebRequest -Uri $global:configuration.BillingAPIUrls.GetBillingRoleAssignmentsByBillingAccount.Replace("{billingAccountName}", $enterpriseAccountName) -Method Get -Headers @{Authorization="Bearer $AccessToken"}
  }
  catch {
    if ($_.Exception.Response.StatusCode -eq 403) {
      Write-Warning "This token you provided does not have Enrollment Administrator role, try other level like Department, Enrollment Account."
      Read-Host "Press any key to go back"
      Get-UserFunctionMenu
      return
    } else {
      Write-Error "Something wrong happened, error: $($_.Exception.Response.ReasonPhase)."
      Read-Host "Press any key to go back"
      Get-UserFunctionMenu
      return
    }
  }
  $result = ($response.Content | ConvertFrom-Json)
  # Now according to the Principal that user choose, we filter out the result.
  if ([string]::IsNullOrEmpty($Principal)) {
    Write-Warning "Checking current signed user $($global:loginInfo.user.name) on the Enrollment Account level for billing account: $enterpriseAccountName)..."
    # New logic! Getting the data means this user is either Enterprise Admin or Enterprise Admin Reader.
    # Now find out which one it is.
    # $userObj = az ad signed-in-user show | ConvertFrom-Json

    # Still use email address to check to avoid tenant related issue.
    # TODO: Need to check whether one user will have multiple roles, this can return an array or something. Double test after implementing the assigning roles feature.
    $roleAssginment = $result.value.properties | Where-Object {$_.userEmailAddress -eq $global:loginInfo.user.name}
    $roleDefinitionId = $roleAssginment.roleDefinitionId.Split('/')[-1]
    $roleName = $global:configuration.RoleMappings.$roleDefinitionId.name
    Write-Success "The current role for user $($global:loginInfo.user.name) in the Enrollment level of billing account $($enterpriseAccountName) is: $roleName";
    # Write-Info "$($roleAssginment.roleDefinitionId.Split('/')[-1])"
    
  } else {
    # First check it's email or principal Id
    if (Get-IsValidEmail -Email $Principal) {
      Write-Warning "Checking user $Principal on the Enrollment Account level for billing account: $enterpriseAccountName)..."
      $roleAssginment = $result.value.properties | Where-Object {$_.userEmailAddress -eq $Principal}
      if ($null -ne $roleAssginment) {
        $roleDefinitionId = $roleAssginment.roleDefinitionId.Split('/')[-1]
        $roleName = $global:configuration.RoleMappings.$roleDefinitionId.name
        Write-Success "The current role for user $Principal in the Enrollment level of billing account $($enterpriseAccountName) is: $roleName";
      } else {
        Write-Warning "User $Principal does not have any role assignment in the Billing Account level."
      }
    } else {
      # Handle principal id
      Write-Warning "Checking service principal with id $Principal on the Enrollment Account Level for billing account: $enterpriseAccountName..."
      $roleAssginment = $result.value.properties | Where-Object {$_.principalId -eq $Principal}
      if ($null -ne $roleAssginment) {
        $roleDefinitionId = $roleAssginment.roleDefinitionId.Split('/')[-1]
        $roleName = $global:configuration.RoleMappings.$roleDefinitionId.name
        Write-Success "The current role for service principal $Principal in the Enrollment level of billing account $($enterpriseAccountName) is: $roleName";
      } else {
        Write-Warning "Service Principal $Principal does not have any role assignment in the Billing Account level."
      }
    }
  }

  Write-Success "Operation Completed!"
  cmd /c pause
}

function Get-BillingRoleAssignmentsOnDepartmentForSingleSP {
  param (
    [Parameter(Mandatory=$true)]
    [string]
    $AccessToken,
    [Parameter(Mandatory=$false)]
    [string]
    $Principal
  )
  $enterpriseAccountName = $global:configuration.CheckRoles.Department.BillingAccountName
  $departmentName = $global:configuration.CheckRoles.Department.DepartmentName
  # Get the response for all the billing account level role assignments first.
  try {
    $response = Invoke-WebRequest -Uri $global:configuration.BillingAPIUrls.GetBillingRoleAssignmentsByDepartment.Replace("{billingAccountName}", $enterpriseAccountName).Replace("{departmentName}", $departmentName) -Method Get -Headers @{Authorization="Bearer $AccessToken"}
  }
  catch {
    if ($_.Exception.Response.StatusCode -eq 403) {
      Write-Warning "This token you provided does not have Enterprise Administrator nor Department Admin role, try other level like Enrollment Account."
      Read-Host "Press any key to go back"
      Get-UserFunctionMenu
      return
    } else {
      Write-Error "Something wrong happened, error: $($_.Exception.Response.ReasonPhase)."
      Read-Host "Press any key to go back"
      Get-UserFunctionMenu
      return
    }
  }
  $result = ($response.Content | ConvertFrom-Json)
  # Now according to the Principal that user choose, we filter out the result.
  if ([string]::IsNullOrEmpty($Principal)) {
    Write-Warning "Checking current signed user $($global:loginInfo.user.name) on the Department level for department: $departmentName in billing account: $enterpriseAccountName..."
    # New logic! Getting the data means this user is either Enterprise Admin or Enterprise Admin Reader.
    # Now find out which one it is.
    # $userObj = az ad signed-in-user show | ConvertFrom-Json

    # Still use email address to check to avoid tenant related issue.
    # TODO: Need to check whether one user will have multiple roles, this can return an array or something. Double test after implementing the assigning roles feature.
    $roleAssginment = $result.value.properties | Where-Object {$_.userEmailAddress -eq $global:loginInfo.user.name}
    $roleDefinitionId = $roleAssginment.roleDefinitionId.Split('/')[-1]
    $roleName = $global:configuration.RoleMappings.$roleDefinitionId.name
    Write-Success "The current role for user $($global:loginInfo.user.name) in the Department level of department $departmentName is: $roleName";
    # Write-Info "$($roleAssginment.roleDefinitionId.Split('/')[-1])"
    
  } else {
    # First check it's email or principal Id
    if (Get-IsValidEmail -Email $Principal) {
      Write-Warning "Checking user $Principal on the Department level for department: $departmentName in billing account: $enterpriseAccountName..."
      $roleAssginment = $result.value.properties | Where-Object {$_.userEmailAddress -eq $Principal}
      if ($null -ne $roleAssginment) {
        $roleDefinitionId = $roleAssginment.roleDefinitionId.Split('/')[-1]
        $roleName = $global:configuration.RoleMappings.$roleDefinitionId.name
        Write-Success "The current role for user $Principal in the Department level of department $departmentName is: $roleName";
      } else {
        Write-Warning "User $Principal does not have any role assignment in the Department level."
      }
    } else {
      # Handle principal id
      Write-Warning "Checking service principal with id $Principal on the Department level for department: $departmentName in billing account: $enterpriseAccountName..."
      $roleAssginment = $result.value.properties | Where-Object {$_.principalId -eq $Principal}
      if ($null -ne $roleAssginment) {
        $roleDefinitionId = $roleAssginment.roleDefinitionId.Split('/')[-1]
        $roleName = $global:configuration.RoleMappings.$roleDefinitionId.name
        Write-Success "The current role for service principal $Principal in the Department level of department $departmentName is: $roleName";
      } else {
        Write-Warning "Service Principal $Principal does not have any role assignment in the Department level."
      }
    }
  }

  Write-Success "Operation Completed!"
  cmd /c pause
}

function Get-BillingRoleAssignmentsOnEnrollmentAccountForSingleSP {
  param (
    [Parameter(Mandatory=$true)]
    [string]
    $AccessToken,
    [Parameter(Mandatory=$false)]
    [string]
    $Principal
  )
  $enterpriseAccountName = $global:configuration.CheckRoles.Account.BillingAccountName
  $accountName = $global:configuration.CheckRoles.Account.AccountName
  # Get the response for all the billing account level role assignments first.
  try {
    $response = Invoke-WebRequest -Uri $global:configuration.BillingAPIUrls.GetBillingRoleAssignmentsByEnrollmentAccount.Replace("{billingAccountName}", $enterpriseAccountName).Replace("{enrollmentAccountName}", $accountName) -Method Get -Headers @{Authorization="Bearer $AccessToken"}
  }
  catch {
    if ($_.Exception.Response.StatusCode -eq 403) {
      Write-Warning "This token you provided does not have permission to get the role assignments on Enrollment Account level, please do proper role assignment first."
      Read-Host "Press any key to go back"
      Get-UserFunctionMenu
      return
    } else {
      Write-Error "Something wrong happened, error: $($_.Exception.Response.ReasonPhase)."
      Read-Host "Press any key to go back"
      Get-UserFunctionMenu
      return
    }
  }
  $result = ($response.Content | ConvertFrom-Json)
  # Now according to the Principal that user choose, we filter out the result.
  if ([string]::IsNullOrEmpty($Principal)) {
    Write-Warning "Checking current signed user $($global:loginInfo.user.name) on the Account $accountName in billing account: $enterpriseAccountName..."
    # New logic! Getting the data means this user is either Enterprise Admin or Enterprise Admin Reader.
    # Now find out which one it is.
    # $userObj = az ad signed-in-user show | ConvertFrom-Json

    # Still use email address to check to avoid tenant related issue.
    # TODO: Need to check whether one user will have multiple roles, this can return an array or something. Double test after implementing the assigning roles feature.
    $roleAssginment = $result.value.properties | Where-Object {$_.userEmailAddress -eq $global:loginInfo.user.name}
    $roleDefinitionId = $roleAssginment.roleDefinitionId.Split('/')[-1]
    $roleName = $global:configuration.RoleMappings.$roleDefinitionId.name
    Write-Success "The current role for user $($global:loginInfo.user.name) in the Account level of account $accountName is: $roleName";
    # Write-Info "$($roleAssginment.roleDefinitionId.Split('/')[-1])"
    
  } else {
    # First check it's email or principal Id
    if (Get-IsValidEmail -Email $Principal) {
      Write-Warning "Checking user $Principal on the Department level for account: $accountName in billing account: $enterpriseAccountName..."
      $roleAssginment = $result.value.properties | Where-Object {$_.userEmailAddress -eq $Principal}
      if ($null -ne $roleAssginment) {
        $roleDefinitionId = $roleAssginment.roleDefinitionId.Split('/')[-1]
        $roleName = $global:configuration.RoleMappings.$roleDefinitionId.name
        Write-Success "The current role for user $Principal in the Account level of account $accountName is: $roleName";
      } else {
        Write-Warning "User $Principal does not have any role assignment in the Account level."
      }
    } else {
      # Handle principal id
      Write-Warning "Checking service principal with id $Principal on the Account level for account $accountName in billing account: $enterpriseAccountName..."
      $roleAssginment = $result.value.properties | Where-Object {$_.principalId -eq $Principal}
      if ($null -ne $roleAssginment) {
        $roleDefinitionId = $roleAssginment.roleDefinitionId.Split('/')[-1]
        $roleName = $global:configuration.RoleMappings.$roleDefinitionId.name
        Write-Success "The current role for service principal $Principal in the Account level of account $accountName is: $roleName";
      } else {
        Write-Warning "Service Principal $Principal does not have any role assignment in the Account level."
      }
    }
  }

  Write-Success "Operation Completed!"
  cmd /c pause
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