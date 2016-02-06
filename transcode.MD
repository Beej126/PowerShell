#### Motivation:

Digital cameras and phones typically save video to MOV (Motion JPEG) files. I share my photos &amp; videos via a self hosted open source photo gallery ([zenPhoto](http://www.zenphoto.org/)). MOV files must be converted to a compatible format like MP4 to stream through the readily available web video players like [Flowplayer](https://flowplayer.org/).

#### Script features:

*   Handles multiple files at once… even from different folders, e.g. when part of a file explorer search result
*   Applies rotation where recognized in the EXIF metadata.
*   Touches new file datestamp to be same as original.

#### Leverages 3rd party tools:

*   [FileMenu Tools](http://www.lopesoft.com/en/products) - handy for creating a FileExplorer right mouse context menu for executing transcode on selected files
*   [HandBrake](https://handbrake.fr/downloads.php) - read something that suggested HandBrake is faster than ffmpeg and that appears true on my quick comparison
*   [MediaInfo](http://mediaarea.net/en/MediaInfo/Download/Windows) - pulls the [EXIF](https://en.wikipedia.org/wiki/Exchangeable_image_file_format) metadata to determine if any rotation is necessary

#### Install:

1.  save [transcode.ps1](https://raw.githubusercontent.com/Beej126/PowerShell/master/transcode.ps1) to a known location
1.  install FileMenu Tools and disable all the commands you don’t want.
1. Configure a “transcode” command as shown in screenshot below... **edit for your path**
  * ```updated Arguments structure: -Command "{path}\transcode.ps1" -list %TEMPFILEPATHS% -rotate auto```
1.  install HandBrake and put HandBrakeCli in your path
1.  minimally, put MediaInfo.exe and MediaInfo.dll in your path

# Windows File Explorer UI example

![enter image description here](http://www.BeejBlog.com/wp-content/uploads/2015/11/Snap6.png)

# FileMenu Tools Config

![enter image description here](http://www.BeejBlog.com/wp-content/uploads/2015/11/Snap1.png)
