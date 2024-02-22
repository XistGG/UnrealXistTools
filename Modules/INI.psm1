#
# INI.psm1
#

function INI_ReadSection
{
    param(
        [string]$Filename,
        [string]$Section
    )

    if (!(Test-Path $Filename))
    {
        Write-Warning "No such INI file: $Filename"
        return $null
    }

    $result = [System.Collections.ArrayList]@()

    $fileLines = Get-Content -Path $Filename

    $sectionName = $null
    $inSection = $false

    foreach ($line in $fileLines)
    {
        if ($line -match "^\s*\[([^\]]+)\]\s*$")
        {
            $sectionName = $matches[1].Trim()
            $inSection = $sectionName -ieq $Section
        }
        elseif ($inSection)
        {
            if ($line -match "^\s*$")
            {
                # Skip empty line
                continue
            }
            elseif ($line -match "^\s*;")
            {
                # Skip comment line
                continue
            }

            # Non-empty, non-comment line.
            # We expect this to be a key=value line

            if ($line -match "^([^=]+)=(.*)")
            {
                $result += [PSCustomObject]@{
                    Name = $matches[1].Trim()
                    Value = $matches[2].Trim()
                }
            }
        }
    }

    return $result
}

function INI_WriteSection
{
    param(
        [string]$Filename,
        [string]$Section,
        [PSCustomObject]$Pairs
    )

    if (!$Pairs)
    {
        Write-Warning "Pairs shouldn't be null"
    }

    # prepare an array of the lines we'll write for this section
    $sectionLines = [System.Collections.ArrayList]@()
    $sectionLines += "[$Section]"
    foreach ($Pair in $Pairs)
    {
        $sectionLines += "$($Pair.Name)=$($Pair.Value)"
    }
    $sectionLines += ""  # blank line at the end of the section

    # prepare an array that will contain ALL of the lines of the INI,
    # including the section we are rewriting.
    $result = [System.Collections.ArrayList]@()
    $isSectionComplete = $false

    if (Test-Path $Filename)
    {
        # This file already exists.  Read it in and modify the section of interest.
        $fileLines = Get-Content -Path $Filename

        $sectionName = $null
        $inSection = $false

        foreach ($line in $fileLines)
        {
            if ($line -match "^\s*\[([^\]]+)\]\s*$")
            {
                # We've found the beginning of another section
                $sectionName = $matches[1].Trim()
                $inSection = $sectionName -ieq $Section

                if ($inSection -and -not $isSectionComplete)
                {
                    # This is the FIRST time we've seen this section.
                    # Write all of its data here.
                    $result += $sectionLines

                    # This section is now complete, we won't write it again
                    $isSectionComplete = $true
                }
            }

            # process all lines, even [section] lines, as long as we're not $inSection
            if (-not $inSection)
            {
                # We're in some part of the INI that is NOT the section we're writing.
                # Preserve this line, whatever it is.
                $result += $line
            }
        }
    }

    if (-not $isSectionComplete)
    {
        # The INI file does not yet exist or the section does not exist.
        # Append the section to the end of the $result
        $result += $sectionLines
    }

    # Try to write the new content to the file
    try
    {
        Set-Content -Path $Filename -Value $result -ErrorAction Stop
    }
    catch
    {
        Write-Error "Failed to write INI `"$Filename`": $_"
        return $false
    }

    return $true
}

Export-ModuleMember -Function INI_ReadSection, INI_WriteSection
