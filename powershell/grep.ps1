function grep {
    [CmdletBinding()]
    param(
        # Regex pattern to search
        [Parameter(Mandatory, Position = 0)]
        [string]$Pattern,

        # One or more files/directories to search
        [Parameter(Position = 1, ValueFromRemainingArguments)]
        [string[]]$Paths,

        # --- Options ---
        [switch]$i,   # Ignore case
        [switch]$r,   # Recursive search
        [switch]$n,   # Show line numbers
        [switch]$l,   # List filenames only
        [switch]$v,   # Invert match (show non-matching lines)

        # Input from pipeline
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    begin {
        $fromPipeline = @()
        $regexOptions = if ($i) { "IgnoreCase" } else { "None" }
    }

    process {
        if ($PSBoundParameters.ContainsKey('InputObject')) {
            # Store pipeline input for later
            $fromPipeline += $InputObject
        }
    }

    end {
        # Case 1: We got input from pipeline
        if ($fromPipeline.Count -gt 0) {
            $lineNum = 0
            foreach ($line in $fromPipeline) {
                $lineNum++
                $isMatch = $line -match $Pattern
                if ($i) { $isMatch = $line -imatch $Pattern }

                if ($v) { $isMatch = -not $isMatch }

                if ($isMatch) {
                    if ($n) {
                        "$($lineNum):$line"
                    } else {
                        "$line"
                    }
                }
            }
            return
        }

        # Case 2: Search files/dirs
        foreach ($Path in $Paths) {
            if (-not (Test-Path $Path)) {
                Write-Warning "Path not found: $Path"
                continue
            }

            $searchPath = Get-Item $Path
            $files = @()

            if ($searchPath.PSIsContainer) {
                $files = Get-ChildItem -Path $Path -Recurse:$r -File
            }
            else {
                $files = ,$searchPath
            }

            foreach ($file in $files) {
                $matches = Select-String -Path $file.FullName -Pattern $Pattern -CaseSensitive:(!$i)

                if ($v) {
                    $lines = Get-Content $file.FullName
                    $matched = $matches.LineNumber
                    $invert = foreach ($iLine in 0..($lines.Count-1)) {
                        if ($matched -notcontains ($iLine+1)) {
                            [PSCustomObject]@{
                                LineNumber = $iLine+1
                                Line       = $lines[$iLine]
                            }
                        }
                    }
                    $matches = $invert
                }

                if ($l) {
                    if ($matches) { $file.FullName }
                    continue
                }

                foreach ($m in $matches) {
                    if ($n) {
                        "$($file.FullName):$($m.LineNumber):$($m.Line.Trim())"
                    } else {
                        "$($file.FullName):$($m.Line.Trim())"
                    }
                }
            }
        }
    }
}
