Add-Type -AssemblyName System.Windows.Forms
[System.WIndows.Forms.Application]::EnableVisualStyles()

function addMenuItem {
  param( [string]$text, [scriptblock]$onClick )

  $menuItem = New-Object System.Windows.Forms.MenuItem
  $menuItem.Text = $text
  $menuItem.add_Click( $onClick )

  $contextMenu.MenuItems.Add($menuItem) | Out-Null
}

$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = New-Object System.Drawing.Icon "$(Split-Path -parent $PSCommandPath)\clock-o.ico"
$notifyIcon.Visible = $true

$contextMenu = New-Object System.Windows.Forms.ContextMenu
$notifyIcon.ContextMenu = $contextMenu

$enabled = $true

addMenuItem "E&xit" { $notifyIcon.Visible = $false; [System.Windows.Forms.Application]::Exit() }
addMenuItem "Disable" { param($sender, $eventArgs) $script:enabled = !$script:enabled; $sender.Text = ("Enable", "Disable")[$script:enabled] } #nugget: to modify a 'global' script variable inside event handler scope, must reference variable via $script qualifier
addMenuItem "S&tart now" { $notifyIcon.ShowBalloonTip(500, "slideshow", "start the show!!!", [System.Windows.Forms.ToolTipIcon]::Info) }

#nugget: provides a message pump for the notifyIcon events, otherwise "no runspace available" error message when the events fire
[System.Windows.Forms.Application]::Run()
if ($Error -ne $null) { pause }