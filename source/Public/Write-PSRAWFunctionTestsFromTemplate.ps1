function Write-PSRAWFunctionTestsFromTemplate
{

  [CmdletBinding()]
  param (

    [Parameter(Mandatory)]
    [String]
    $TemplatePath,

    [Parameter(Mandatory)]
    [String]
    $FunctionPrefix,

    [Parameter(Mandatory)]
    [String]
    $OutputPath,

    [String]
    $NoParams = 'NoParams',
    
    [String]
    $Ids = 'Ids',

    [Parameter(Mandatory)]
    [String]
    $PInvokeRestmethod,

    [Parameter(Mandatory)]
    [String]
    $PGetFunctionString,

    [array]
    $SwitchParams,

    [Parameter(Mandatory)]
    $OtherParams,

    [Parameter(Mandatory)]
    [String]
    $BaseUrl,

    [Parameter(Mandatory)]
    [String]
    $Tier1,

    [Parameter(Mandatory)]
    [String]
    $Tier2,

    [Parameter(Mandatory)]
    [String]
    $Method

  )
  
  begin
  {
    switch ($Method)
    {
      'Get'
      {
        $Verb = 'Get'
      }
      ('Patch' -or 'Put')
      {
        $Verb = 'Update'
      }
      'Delete'
      {
        $Verb = 'Remove'
      }
    }
    # Set noun Plural to Singular
    $Noun = ((Get-Culture).TextInfo.ToTitleCase($Tier2) -replace 's$', '' -replace 'sse$', 'ss')
    $FunctionName = '{0}-{1}{2}' -f $Verb, $FunctionPrefix, $Noun
    $KnownParams = $OtherParams + $SwitchParams
  }
  
  process
  {
    $sread = [System.IO.StreamReader]::new($TemplatePath) 
    $FileContent = while ($sread.EndOfStream -eq $false)
    {
      $line = $sread.ReadLine()
      if ($line -match '##__(?<RegionParam>\w+)__##')
      {
        $RegionParam = $Matches.RegionParam
      }
      elseif ($RegionParam -eq 'switchparams')
      {
        if ($line -match '##end__switchparams__##')
        {
          $RegionParam = $null
        }
        elseif ($line -match '__switchparams__')
        {        
          $i = 1
          $SwitchParams.ForEach{
            if ($i -lt $SwitchParams.Count)
            {
              '{0},' -f ($line -replace '__switchparams__', (Get-Culture).TextInfo.ToTitleCase($_.name))
            }
            else
            {
              $line -replace '__switchparams__', (Get-Culture).TextInfo.ToTitleCase($_.name)
            }
            $i++
          }
        }
        else
        {
          $line
        }
      }
      elseif ($RegionParam -eq 'knownparams')
      {
        if ($line -match '##end__knownparams__##')
        {
          $RegionParam = $null
        }
        elseif ($line -match '__knownparams__')
        {
          $i = 1
          $KnownParams.ForEach{
            if ($i -lt $KnownParams.Count)
            {
              '{0},' -f ($line -replace '__knownparams__', (Get-Culture).TextInfo.ToTitleCase($_.name))
            }
            else
            {
              $line -replace '__knownparams__', (Get-Culture).TextInfo.ToTitleCase($_.name)
            }
            $i++
          }
        }
        else
        {
          $line
        }
      }
      elseif ($line -match '__ids__')
      {
        $line -replace '__Ids__', $Ids
      }
      elseif ($line -match '__pinvokerestmethod__')
      {
        $line -replace '__pinvokerestmethod__', $PInvokeRestmethod
      }
      elseif ($line -match '__pgetfunctionstring__')
      {
        $line -replace '__pgetfunctionstring__', $PGetFunctionString
      }
      elseif ($line -match '__noparams__')
      {
        $line -replace '__noparams__', $NoParams
      }
      else
      {
        $line
      }
    }
    $sread.close()

    # replace two or more blank with one and output file
    $blCtr = 0
    ($FileContent | Out-String -Stream).foreach{
      if (($_ -match '^$') -and ($blCtr -eq 0))
      {
        $blCtr++
        $_
      }
      elseif (($_ -match '^$') -and ($blCtr -gt 0))
      {
        $blCtr++
      }
      else
      {
        $blCtr = 0
        $_
      }
    } | Out-File -FilePath ('{0}\{1}.Tests.ps1' -f $OutputPath, $FunctionName) -Encoding UTF8
  }
  
  end
  {
  }
}