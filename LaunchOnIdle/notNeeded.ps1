<################## not needed

$frmMain = New-Object System.Windows.Forms.Form
$frmMain.Size = New-Object System.Drawing.Size(650,120)
$frmMain.StartPosition = 'CenterScreen'

[System.Windows.Forms.Application]::Run($frmMain)
#$frmMain.Show()

$syncHash = [Hashtable]::Synchronized(@{});

$rs =[runspacefactory]::CreateRunspace()
$rs.ApartmentState = "STA"
$rs.ThreadOptions = "ReuseThread"
$rs.Open()
$rs.SessionStateProxy.SetVariable("syncHash", $syncHash)

#[System.Management.Automation.Runspaces.Runspace]::DefaultRunspace = $rs
$ps = [PowerShell]::Create().AddScript({
})
$ps.Runspace = $rs

#$handle = $ps.BeginInvoke()
$ps.Invoke()
$ps.Runspace.Dispose()
$ps.Dispose()
#>

function addMenuItem {
  param( [string]$text, [scriptblock]$onClick )

  $menuItem = New-Object System.Windows.Forms.MenuItem
  $menuItem.Text = $text
  $menuItem.add_Click( $onClick )

  $contextMenu.MenuItems.Add($menuItem) | Out-Null

  return $menuItem
}

<#
$contextMenu = New-Object System.Windows.Forms.ContextMenu
$notifyIcon.ContextMenu = $contextMenu
addMenuItem "Path: $photoPath" $null | Out-Null
addMenuItem "E&xit" { $notifyIcon.Visible = $false; [System.Windows.Forms.Application]::Exit() } | Out-Null
$enableMenuItem = addMenuItem "Enable" { ToggleActive }
#>

