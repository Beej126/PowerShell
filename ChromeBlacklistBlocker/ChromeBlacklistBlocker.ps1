# http://powershell.com/cs/blogs/tips/archive/2009/07/08/wait-for-key-press.aspx
function Wait-KeyPress($prompt='press key to end') {
	Write-Host $prompt 
	
	do {
		Start-Sleep -milliseconds 100
	} until ($Host.UI.RawUI.KeyAvailable)

	$Host.UI.RawUI.FlushInputBuffer()
}

## Win32 P/Invoke 
function Invoke-Win32([string] $dllName, [Type] $returnType,  
   [string] $methodName, [Type[]] $parameterTypes, [Object[]] $parameters) 
{ 
   ## Begin to build the dynamic assembly 
   $domain = [AppDomain]::CurrentDomain 
   $name = New-Object Reflection.AssemblyName ‘PInvokeAssembly’ 
   $assembly = $domain.DefineDynamicAssembly($name, ‘Run’) 
   $module = $assembly.DefineDynamicModule(‘PInvokeModule’) 
   $type = $module.DefineType(‘PInvokeType’, “Public,BeforeFieldInit”) 

   ## Go through all of the parameters passed to us.  As we do this, 
   ## we clone the user’s inputs into another array that we will use for 
   ## the P/Invoke call.   
   $inputParameters = @() 
   $refParameters = @() 
   
   for($counter = 1; $counter -le $parameterTypes.Length; $counter++) 
   { 
      ## If an item is a PSReference, then the user  
      ## wants an [out] parameter. 
      if($parameterTypes[$counter – 1] -eq [Ref]) 
      { 
         ## Remember which parameters are used for [Out] parameters 
         $refParameters += $counter 

         ## On the cloned array, we replace the PSReference type with the  
         ## .Net reference type that represents the value of the PSReference,  
         ## and the value with the value held by the PSReference. 
         $parameterTypes[$counter – 1] =  
            $parameters[$counter – 1].Value.GetType().MakeByRefType() 
         $inputParameters += $parameters[$counter – 1].Value 
      } 
      else 
      { 
         ## Otherwise, just add their actual parameter to the 
         ## input array. 
         $inputParameters += $parameters[$counter – 1] 
      } 
   } 

   ## Define the actual P/Invoke method, adding the [Out] 
   ## attribute for any parameters that were originally [Ref]  
   ## parameters. 
   $method = $type.DefineMethod($methodName, ‘Public,HideBySig,Static,PinvokeImpl’,  
      $returnType, $parameterTypes) 
   foreach($refParameter in $refParameters) 
   { 
      $method.DefineParameter($refParameter, “Out”, $null) 
   } 

   ## Apply the P/Invoke constructor 
   $ctor = [Runtime.InteropServices.DllImportAttribute].GetConstructor([string]) 
   $attr = New-Object Reflection.Emit.CustomAttributeBuilder $ctor, $dllName 
   $method.SetCustomAttribute($attr) 

   ## Create the temporary type, and invoke the method. 
   $realType = $type.CreateType() 
   $realType.InvokeMember($methodName, ‘Public,Static,InvokeMethod’, $null, $null,  
      $inputParameters) 

   ## Finally, go through all of the reference parameters, and update the 
   ## values of the PSReference objects that the user passed in. 
   foreach($refParameter in $refParameters) 
   { 
      $parameters[$refParameter – 1].Value = $inputParameters[$refParameter – 1] 
   } 
} 

function ShowWindowAsync([IntPtr] $hWnd, [Int32] $nCmdShow) 
{ 
  $parameterTypes = [IntPtr], [Int32]  
  $parameters = $hWnd, $nCmdShow 
  Invoke-Win32 "user32.dll" ([Boolean]) "ShowWindowAsync" $parameterTypes $parameters 

    # Values for $nCmdShow 
    # SW_HIDE = 0; 
    # SW_SHOWNORMAL = 1; 
    # SW_NORMAL = 1; 
    # SW_SHOWMINIMIZED = 2; 
    # SW_SHOWMAXIMIZED = 3; 
    # SW_MAXIMIZE = 3; 
    # SW_SHOWNOACTIVATE = 4; 
    # SW_SHOW = 5; 
    # SW_MINIMIZE = 6; 
    # SW_SHOWMINNOACTIVE = 7; 
    # SW_SHOWNA = 8; 
    # SW_RESTORE = 9; 
    # SW_SHOWDEFAULT = 10; 
    # SW_MAX = 10 
}

#from: http://www.codeproject.com/Articles/4502/RegistryMonitor-a-NET-wrapper-class-for-RegNotifyC
$regmonClass = @"
using System;
using System.ComponentModel;
using System.IO;
using System.Threading;
using System.Runtime.InteropServices;
using Microsoft.Win32;

namespace RegistryUtils
{
	/// <summary>
	/// <b>RegistryMonitor</b> allows you to monitor specific registry key.
	/// </summary>
	/// <remarks>
	/// If a monitored registry key changes, an event is fired. You can subscribe to these
	/// events by adding a delegate to <see cref="RegChanged"/>.
	/// <para>The Windows API provides a function
	/// <a href="http://msdn.microsoft.com/library/en-us/sysinfo/base/regnotifychangekeyvalue.asp">
	/// RegNotifyChangeKeyValue</a>, which is not covered by the
	/// <see cref="Microsoft.Win32.RegistryKey"/> class. <see cref="RegistryMonitor"/> imports
	/// that function and encapsulates it in a convenient manner.
	/// </para>
	/// </remarks>
	/// <example>
	/// This sample shows how to monitor <c>HKEY_CURRENT_USER\Environment</c> for changes:
	/// <code>
	/// public class MonitorSample
	/// {
	///     static void Main() 
	///     {
	///         RegistryMonitor monitor = new RegistryMonitor(RegistryHive.CurrentUser, "Environment");
	///         monitor.RegChanged += new EventHandler(OnRegChanged);
	///         monitor.Start();
	///
	///         while(true);
	/// 
	///			monitor.Stop();
	///     }
	///
	///     private void OnRegChanged(object sender, EventArgs e)
	///     {
	///         Console.WriteLine("registry key has changed");
	///     }
	/// }
	/// </code>
	/// </example>
	public class RegistryMonitor : IDisposable
	{
		#region P/Invoke

		[DllImport("advapi32.dll", SetLastError = true)]
		private static extern int RegOpenKeyEx(IntPtr hKey, string subKey, uint options, int samDesired,
		                                       out IntPtr phkResult);

		[DllImport("advapi32.dll", SetLastError = true)]
		private static extern int RegNotifyChangeKeyValue(IntPtr hKey, bool bWatchSubtree,
		                                                  RegChangeNotifyFilter dwNotifyFilter, IntPtr hEvent,
		                                                  bool fAsynchronous);

		[DllImport("advapi32.dll", SetLastError = true)]
		private static extern int RegCloseKey(IntPtr hKey);

		private const int KEY_QUERY_VALUE = 0x0001;
		private const int KEY_NOTIFY = 0x0010;
		private const int STANDARD_RIGHTS_READ = 0x00020000;

		private static readonly IntPtr HKEY_CLASSES_ROOT = new IntPtr(unchecked((int) 0x80000000));
		private static readonly IntPtr HKEY_CURRENT_USER = new IntPtr(unchecked((int) 0x80000001));
		private static readonly IntPtr HKEY_LOCAL_MACHINE = new IntPtr(unchecked((int) 0x80000002));
		private static readonly IntPtr HKEY_USERS = new IntPtr(unchecked((int) 0x80000003));
		private static readonly IntPtr HKEY_PERFORMANCE_DATA = new IntPtr(unchecked((int) 0x80000004));
		private static readonly IntPtr HKEY_CURRENT_CONFIG = new IntPtr(unchecked((int) 0x80000005));
		private static readonly IntPtr HKEY_DYN_DATA = new IntPtr(unchecked((int) 0x80000006));

		#endregion

		#region Event handling

		/// <summary>
		/// Occurs when the specified registry key has changed.
		/// </summary>
		public event EventHandler RegChanged;
		
		/// <summary>
		/// Raises the <see cref="RegChanged"/> event.
		/// </summary>
		/// <remarks>
		/// <p>
		/// <b>OnRegChanged</b> is called when the specified registry key has changed.
		/// </p>
		/// <note type="inheritinfo">
		/// When overriding <see cref="OnRegChanged"/> in a derived class, be sure to call
		/// the base class's <see cref="OnRegChanged"/> method.
		/// </note>
		/// </remarks>
		protected virtual void OnRegChanged()
		{
			EventHandler handler = RegChanged;
			if (handler != null)
				handler(this, null);
		}

		/// <summary>
		/// Occurs when the access to the registry fails.
		/// </summary>
		public event ErrorEventHandler Error;
		
		/// <summary>
		/// Raises the <see cref="Error"/> event.
		/// </summary>
		/// <param name="e">The <see cref="Exception"/> which occured while watching the registry.</param>
		/// <remarks>
		/// <p>
		/// <b>OnError</b> is called when an exception occurs while watching the registry.
		/// </p>
		/// <note type="inheritinfo">
		/// When overriding <see cref="OnError"/> in a derived class, be sure to call
		/// the base class's <see cref="OnError"/> method.
		/// </note>
		/// </remarks>
		protected virtual void OnError(Exception e)
		{
			ErrorEventHandler handler = Error;
			if (handler != null)
				handler(this, new ErrorEventArgs(e));
		}

		#endregion

		#region Private member variables

		private IntPtr _registryHive;
		private string _registrySubName;
		private object _threadLock = new object();
		private Thread _thread;
		private bool _disposed = false;
		private ManualResetEvent _eventTerminate = new ManualResetEvent(false);

		private RegChangeNotifyFilter _regFilter = RegChangeNotifyFilter.Key | RegChangeNotifyFilter.Attribute |
		                                           RegChangeNotifyFilter.Value | RegChangeNotifyFilter.Security;

		#endregion

		/// <summary>
		/// Initializes a new instance of the <see cref="RegistryMonitor"/> class.
		/// </summary>
		/// <param name="registryKey">The registry key to monitor.</param>
		public RegistryMonitor(RegistryKey registryKey)
		{
			InitRegistryKey(registryKey.Name);
		}

		/// <summary>
		/// Initializes a new instance of the <see cref="RegistryMonitor"/> class.
		/// </summary>
		/// <param name="name">The name.</param>
		public RegistryMonitor(string name)
		{
			if (name == null || name.Length == 0)
				throw new ArgumentNullException("name");

			InitRegistryKey(name);
		}
		
		/// <summary>
		/// Initializes a new instance of the <see cref="RegistryMonitor"/> class.
		/// </summary>
		/// <param name="registryHive">The registry hive.</param>
		/// <param name="subKey">The sub key.</param>
		public RegistryMonitor(RegistryHive registryHive, string subKey)
		{
			InitRegistryKey(registryHive, subKey);
		}

		/// <summary>
		/// Disposes this object.
		/// </summary>
		public void Dispose()
		{
			Stop();
			_disposed = true;
			GC.SuppressFinalize(this);
		}

		/// <summary>
		/// Gets or sets the <see cref="RegChangeNotifyFilter">RegChangeNotifyFilter</see>.
		/// </summary>
		public RegChangeNotifyFilter RegChangeNotifyFilter
		{
			get { return _regFilter; }
			set
			{
				lock (_threadLock)
				{
					if (IsMonitoring)
						throw new InvalidOperationException("Monitoring thread is already running");

					_regFilter = value;
				}
			}
		}
		
		#region Initialization

		private void InitRegistryKey(RegistryHive hive, string name)
		{
			switch (hive)
			{
				case RegistryHive.ClassesRoot:
					_registryHive = HKEY_CLASSES_ROOT;
					break;

				case RegistryHive.CurrentConfig:
					_registryHive = HKEY_CURRENT_CONFIG;
					break;

				case RegistryHive.CurrentUser:
					_registryHive = HKEY_CURRENT_USER;
					break;

				case RegistryHive.DynData:
					_registryHive = HKEY_DYN_DATA;
					break;

				case RegistryHive.LocalMachine:
					_registryHive = HKEY_LOCAL_MACHINE;
					break;

				case RegistryHive.PerformanceData:
					_registryHive = HKEY_PERFORMANCE_DATA;
					break;

				case RegistryHive.Users:
					_registryHive = HKEY_USERS;
					break;

				default:
					throw new InvalidEnumArgumentException("hive", (int)hive, typeof (RegistryHive));
			}
			_registrySubName = name;
		}

		private void InitRegistryKey(string name)
		{
			string[] nameParts = name.Split('\\');

			switch (nameParts[0])
			{
				case "HKEY_CLASSES_ROOT":
				case "HKCR":
					_registryHive = HKEY_CLASSES_ROOT;
					break;

				case "HKEY_CURRENT_USER":
				case "HKCU":
					_registryHive = HKEY_CURRENT_USER;
					break;

				case "HKEY_LOCAL_MACHINE":
				case "HKLM":
					_registryHive = HKEY_LOCAL_MACHINE;
					break;

				case "HKEY_USERS":
					_registryHive = HKEY_USERS;
					break;

				case "HKEY_CURRENT_CONFIG":
					_registryHive = HKEY_CURRENT_CONFIG;
					break;

				default:
					_registryHive = IntPtr.Zero;
					throw new ArgumentException("The registry hive '" + nameParts[0] + "' is not supported", "value");
			}

			_registrySubName = String.Join("\\", nameParts, 1, nameParts.Length - 1);
		}
		
		#endregion

		/// <summary>
		/// <b>true</b> if this <see cref="RegistryMonitor"/> object is currently monitoring;
		/// otherwise, <b>false</b>.
		/// </summary>
		public bool IsMonitoring
		{
			get { return _thread != null; }
		}

		/// <summary>
		/// Start monitoring.
		/// </summary>
		public void Start()
		{
			if (_disposed)
				throw new ObjectDisposedException(null, "This instance is already disposed");
			
			lock (_threadLock)
			{
				if (!IsMonitoring)
				{
					_eventTerminate.Reset();
					_thread = new Thread(new ThreadStart(MonitorThread));
					_thread.IsBackground = true;
					_thread.Start();
				}
			}
		}

		/// <summary>
		/// Stops the monitoring thread.
		/// </summary>
		public void Stop()
		{
			if (_disposed)
				throw new ObjectDisposedException(null, "This instance is already disposed");
			
			lock (_threadLock)
			{
				Thread thread = _thread;
				if (thread != null)
				{
					_eventTerminate.Set();
					thread.Join();
				}
			}
		}

		private void MonitorThread()
		{
			try
			{
				ThreadLoop();
			}
			catch (Exception e)
			{
				OnError(e);
			}
			_thread = null;
		}

		private void ThreadLoop()
		{
			IntPtr registryKey;
			int result = RegOpenKeyEx(_registryHive, _registrySubName, 0, STANDARD_RIGHTS_READ | KEY_QUERY_VALUE | KEY_NOTIFY,
			                          out registryKey);
			if (result != 0)
				throw new Win32Exception(result);

			try
			{
				AutoResetEvent _eventNotify = new AutoResetEvent(false);
				WaitHandle[] waitHandles = new WaitHandle[] {_eventNotify, _eventTerminate};
				while (!_eventTerminate.WaitOne(0, true))
				{
					result = RegNotifyChangeKeyValue(registryKey, true, _regFilter, _eventNotify.Handle, true);
					if (result != 0)
						throw new Win32Exception(result);

					if (WaitHandle.WaitAny(waitHandles) == 0)
					{
						OnRegChanged();
					}
				}
			}
			finally
			{
				if (registryKey != IntPtr.Zero)
				{
					RegCloseKey(registryKey);
				}
			}
		}
	}
	
	/// <summary>
	/// Filter for notifications reported by <see cref="RegistryMonitor"/>.
	/// </summary>
	[Flags]
	public enum RegChangeNotifyFilter
	{
		/// <summary>Notify the caller if a subkey is added or deleted.</summary>
		Key = 1,
		/// <summary>Notify the caller of changes to the attributes of the key,
		/// such as the security descriptor information.</summary>
		Attribute = 2,
		/// <summary>Notify the caller of changes to a value of the key. This can
		/// include adding or deleting a value, or changing an existing value.</summary>
		Value = 4,
		/// <summary>Notify the caller of changes to the security descriptor
		/// of the key.</summary>
		Security = 8,
	}
}
"@

<##############################################################################################################################################
###############################################################################################################################################
###############################################################################################################################################>


$null = ShowWindowAsync (Get-Process -Id $pid).MainWindowHandle 0

#taskkill /im chrome.exe /f
rp -Path HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallBlacklist -Name 1
#& 'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'

add-type -typedefinition  $regmonClass -IgnoreWarnings

$regmon = New-Object RegistryUtils.RegistryMonitor("HKEY_LOCAL_MACHINE\SOFTWARE\Policies")
#$regmon.RegChangeNotifyFilter = 4
$regmon.Start()

Register-ObjectEvent -InputObject $regmon -EventName RegChanged -Action {
    #$Global:lastevt = $Event
    #$Event | Out-Host
    start-sleep -milliseconds 3000 #little delay to make sure update has quiesced
    rp -Path HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallBlacklist -Name 1
}

Wait-KeyPress

Get-EventSubscriber | Unregister-Event 
Get-Job | % {Remove-Job $_}