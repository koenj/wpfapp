$ErrorMessage = "POWERSHELL ERROR"
try {

	# Parse the BuildNumber from the AssemblyInfo.Shared.cs file
	$assemblyInfoPath = '.\src\AssemblyInfo.Shared.cs'
	if (-Not(Test-Path($assemblyInfoPath))) {
	  Write-Host "##teamcity[buildProblem description='Version cannot be found: AssemblyInfo.Shared.cs file not found']"
	}
	$assemblyInfo = [IO.File]::ReadAllText($assemblyInfoPath)
	$assemblyInfo -match 'AssemblyVersion\("(?<major>[0-9]+).(?<minor>[0-9]+).(?<patch>[0-9]+).*"\)'

	$major = $matches['major']
	$minor = $matches['minor']
	$patch = $matches['patch']
	$buildNumber = "$major.$minor.$patch.$args[0]"  # TeamCity's %build.counter% is passed as an arg

	
	# Emit the BuildNumber to label the TeamCity build
	$teamCityBuildNumber = $buildNumber
	$assemblyInfo -match 'assembly:[ ]*Description\("(?<preReleaseInfo>[a-zA-Z0-9.]+)"\)'
	$preReleaseInfo = $matches['preReleaseInfo']
	If ($preReleaseInfo) {
		# If beta.1 is supplied, semver the tc version as 2.2.0-beta1+45654 (http://semver.org/)
		$teamCityBuildNumber = "$major.$minor.$patch-$preReleaseInfo+%build.counter%"
	}
	Write-Host "##teamcity[buildNumber '$teamCityBuildNumber']"


	# Update the assembly version in AssemblyInfo.Shared.cs
	# Note that we don't use TeamCity's "AssemblyInfo patcher" feature:
	# it runs right after GIT clone and we don't know the version at that point.
	$assemblyVersionPattern = 'AssemblyVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'        
	$assemblyVersion = 'AssemblyVersion("' + $buildNumber + '")';        
	$assemblyFileVersionPattern = 'AssemblyFileVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'  
	$assemblyFileVersion = 'AssemblyFileVersion("' + $buildNumber + '")'
	(Get-Content $assemblyInfoPath) | Foreach-Object {
		$_ -replace $assemblyVersionPattern, $assemblyVersion `
		   -replace $assemblyFileVersionPattern, $assemblyFileVersion ` 
		} | Set-Content $assemblyInfoPath -encoding UTF8 -force
	Write-Host "Updated AssemblyVersion/AssemblyFileVersion in '$assemblyInfoPath' to '$buildNumber'"
	
} Catch {

	# For TeamCity to handle the error, must exit with a non-0 exit code.
	$ErrorMessage = $_.Exception.Message
	Write-Host $ErrorMessage
	exit(1)
}