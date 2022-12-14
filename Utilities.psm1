function Create-Menu {
  Param(
      [Parameter(Mandatory=$false)][string]  $MenuTitle = $null,
      [Parameter(Mandatory=$true)] [string[]]$MenuOptions
  )

  # test if we're not running in the ISE
  if ($Host.Name -match 'ISE') {
      Throw "This menu must be run in PowerShell Console"
  }

  $MaxValue = $MenuOptions.Count-1
  $Selection = 0
  $EnterPressed = $False
  [console]::CursorVisible = $false  # prevents cursor flickering
  Clear-Host

  while(!$EnterPressed) {
      # draw the menu without Clear-Host to prevent flicker
      [console]::SetCursorPosition(0,0)
        #   # Allen modified to add user information.
        # Not working, maybe try these later when have time.
        #   if ($null -ne $global:loginInfo){
        #     $accountDisplay = "Signed Account: $($global:loginInfo.user.name)"
        #     $tenantDisplay = "Tenant: $($global:loginInfo.tenantId)"
        #     [int]$Width = [math]::Max($MenuTitle.Length, ($MenuOptions | Measure-Object -Property Length -Maximum).Maximum)
        #     [int]$displayMaxWidth = [math]::Max($accountDisplay.Length, $tenantDisplay.Length)
        #     $leftSpace  = ' ' * [Math]::Floor(($maxwidth - $displayMaxWidth.Length)/2)
        #     $rightSpace = ' ' * [Math]::Ceiling(($maxwidth - $displayMaxWidth.Length)/2)
        #     Write-Host ("║" + $leftSpace + $accountDisplay + $rightSpace + "║")
        #     Write-Host ("║" + $leftSpace + $tenantDisplay + $rightSpace + "║")
        #     Write-Host ("╟" + "─" * $maxwidth + "╢")
        #   } else {
            
        #   }
      for ($i = 0; $i -le $MaxValue; $i++){
          [int]$Width = [math]::Max($MenuTitle.Length, ($MenuOptions | Measure-Object -Property Length -Maximum).Maximum)
          [int]$Buffer = if (($Width * 1.5) -gt 78) { (78 - $width) / 2 } else { $width / 4 }
          $Buffer = [math]::Min(6, $Buffer)
          $MaxWidth = $Buffer * 2 + $Width + $MenuOptions.Count.ToString().Length
          Write-Host ("╔" + "═" * $maxwidth + "╗")
          # write the title if present
          if (!([string]::IsNullOrWhiteSpace($MenuTitle))) {
              $leftSpace  = ' ' * [Math]::Floor(($maxwidth - $MenuTitle.Length)/2)
              $rightSpace = ' ' * [Math]::Ceiling(($maxwidth - $MenuTitle.Length)/2)
              Write-Host ("║" + $leftSpace + $MenuTitle + $rightSpace + "║")
              Write-Host ("╟" + "─" * $maxwidth + "╢")
          }

          # write the menu option lines
          for($i = 0; $i -lt $MenuOptions.Count; $i++){
              $Item = "$($i + 1). "
              $Option = $MenuOptions[$i]
              $leftSpace  = ' ' * $Buffer
              $rightSpace = ' ' * ($MaxWidth - $Buffer - $Item.Length - $Option.Length)
              $line = "║" + $leftSpace + $Item + $Option + $rightSpace + "║"
              if ($Selection -eq $i) {
                  Write-Host $line -ForegroundColor Green
              }
              else {
                  Write-Host $line
              }
          }
          Write-Host ("╚" + "═" * $maxwidth + "╝")
      }
      # Allen - Test to write the sign in information here.
      if ($null -ne $global:loginInfo) {
        Write-Info "Signed-in Account: $($global:loginInfo.user.name)"
        Write-Info "TenantId: $($global:loginInfo.tenantId)"
      }
      # wait for an accepted key press
      do {
          $KeyInput = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').VirtualKeyCode
      } while (13, 38, 40 -notcontains $KeyInput)


      Switch($KeyInput){
          13{
              $EnterPressed = $True
              [console]::CursorVisible = $true  # reset the cursors visibility
              return $Selection
          }
          38 {
              $Selection--
              if ($Selection -lt 0){ $Selection = $MaxValue }
              break
          }
          40 { 
              $Selection++
              if ($Selection -gt $MaxValue) { $Selection = 0 }
              # or:    $Selection = ($Selection + 1) % ($MaxValue + 1)
              break
          }
      }
  }
}

function Get-Configuration {
    param (
        [Parameter(Mandatory=$false)]
        [String]
        $FilePath
    )

    if ([string]::IsNullOrEmpty($FilePath)) {
        $FilePath = Join-Path $PSScriptRoot ".\Configuration.json"
    }

    return $(Get-Content -Raw -Path $FilePath | ConvertFrom-Json)
}

function Get-AccessToken {
    return $(az account get-access-token --resource=https://management.azure.com --query accessToken --output tsv)
}


function Write-Warning {
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string]
        $Text
    )

    Write-Host $Text -ForegroundColor Yellow
}

function Write-Success {
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string]
        $Text
    )

    Write-Host $Text -ForegroundColor Green
}

function Write-Info {
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string]
        $Text
    )

    Write-Host $Text
}

function Write-Error {
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string]
        $Text
    )

    Write-Host $Text -ForegroundColor Red
}


function Get-IsValidEmail {
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]
        $Email
    )

    Try
    {
        $obj = New-Object System.Net.Mail.MailAddress($Email)
        return $($null -ne $obj)
    }
    Catch
    {
        return $false
    }
}

function Test-IsGuid
{
    [OutputType([bool])]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$StringGuid
    )
 
   $ObjectGuid = [System.Guid]::empty
   return [System.Guid]::TryParse($StringGuid,[System.Management.Automation.PSReference]$ObjectGuid) # Returns True if successfully parsed
}

function Get-UserInput {
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Prompt
    )

    return Read-Host $Prompt
}


# function New-DataTable {
#     param(
#         [Parameter(Mandatory=$true)]
#         [string[]]
#         $Headers,
#         [Parameter(Mandatory=$true)]
#         [PSObject]
#         $DataObject
#     )

#     $DataTable = New-Object System.Data.DataTable

#     $Headers | ForEach-Object {
#         $DataTable.Columns.Add($_)
#     }

#     foreach ($currentItemName in $DataObject) {
#         <# $currentItemName is the current item #>
#     }
# }