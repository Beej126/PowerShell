param(
  [string]$rotate = "auto",
  [string]$list #= "C:\Users\beej1\AppData\Local\Temp\fmt2191.tmp"
)

#debug: "args: $args, rotate: $rotate, listFile: $list"; pause

#if we've passed a rotate directive, and it's not "none"...
if (!!$rotate -and $rotate -ne "none") {

  #otherwise, check if we want to input specific rotation this time...
  if ($rotate -eq "prompt") {
    Add-Type -AssemblyName Microsoft.VisualBasic
    $rotation = [Microsoft.VisualBasic.Interaction]::InputBox("1 : x flip`n
2 : y flip`n
3 : 180 degrees rotate`n
4 : 90 degrees rotate (clockwise)`n
5 : 90 degrees rotate + y flip`n
6 : 270 degrees rotate + y flip`n
7 : 270 degrees rotate`n`n",
    "Rotation", "3")

    if (!$rotation) { exit } #user hit cancel on inputbox
  }

  #either CLI or prompted into a specific rotation value ...
  if ($rotation -as [int]) { $rotation = "--rotate=$rotation" }

  #otherwise everything else translates to auto
  else { $rotate = "auto" }
}

#debug: "rotation: $rotate"; pause

gc $list | % {

  #skip blank lines in the input files list
  if (!$_) { return } #nugget: use return vs continue in a foreach-object loop: http://stackoverflow.com/questions/7760013/why-does-continue-behave-like-break-in-a-foreach-object

  #otherwise "auto" rotation means using mediainfo CLI to determine appropriate rotation...
  #i would find that sometimes "3" would work and sometimes it wouldn't... then "2" would be a good compromise... it just seemed to depend on the source
  #unfortunately this means vids must be checked after the fact and redone
  if ($rotate -eq "auto") {

    $rotation = (mediainfo "$_" | Select-String -Pattern "Rotation +: ([0-9]+)")
    if ($rotation) {
      if ($rotation.Matches[0].Groups[1].Value -eq "90") { $rotation = "--rotate=4" } #90 degree rotate
      else { $rotation = "--rotate=3" } #for some reason the default 180 degree rotate doesn't always do it... in those cases i've found that manually applying two separate passes of 2 works out but it doesn't make any sense why yet
    }
  }

  $fileName = [System.IO.Path]::GetFileNameWithoutExtension($_)
  #make sure we don't overwrite if we're converting from mp4 to mp4
  if ([System.IO.Path]::GetExtension($_).ToLower() -eq ".mp4") { $fileName += "_tr" }
  $newFile = [System.IO.Path]::ChangeExtension($fileName, "mp4")
  
  Write-Host -ForegroundColor Yellow "`nhandbrakecli -e x264 -q 26 $rotation -i `"$_`" -o `"$newFile`"`n"
  handbrakecli -e x264 -q 26 $rotation -i "$_" -o "$newFile"
  if ($LASTEXITCODE -ne 0 -or !(test-path $newFile)) { $handBrakeError = $true; return }

  #in my usage, dates get stepped on from moving things around, pulling oldest date to help compensate
  #then set new converted file create and modified time
  $oldestDatestamp = [datetime][math]::Min((gi $_).CreationTime.ticks, (gi $_).LastWriteTime.Ticks)
  (gi $newFile).CreationTime = $oldestDatestamp
  (gi $newFile).LastWriteTime = $oldestDatestamp
}

#write-host "press any key to finish and close"
#$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

if ($Error -or $handBrakeError) { Write-Host -ForegroundColor Red "`nthere were errors`nlist file: $list`n"; pause }

erase $list
