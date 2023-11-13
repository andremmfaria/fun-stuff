Set-Location -Path $env:USERPROFILE

function prompt {
    	$loc = $PWD.Path.Replace("\","/")
    	$upr = $env:USERPROFILE.Replace("\","/")
	$pr = $env:USERNAME + "@" + $env:COMPUTERNAME + ":[" + "<rep>" + "]$"
	if($loc -match $upr) { 
		$pr = $pr.Replace("<rep>",($loc.Replace($upr,"~").Replace("/","\")))
	}
    	else {
		$pr = $pr.Replace("<rep>",$loc.Replace("\","/"))
	}
	"$pr "
}

function ll() { 
	param ([string[]]$Path)
	Get-Childitem -Force $path 
}
